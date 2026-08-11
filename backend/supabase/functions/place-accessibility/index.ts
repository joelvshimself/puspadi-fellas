// supabase/functions/place-accessibility/index.ts
//
// Owner 1 — Search & Discover. This is the money gate: the ONLY place Apify
// gets called from. See docs/specs.md §4.1 and §6, and Flow A in
// docs/architecture-plan-v2.excalidraw.
//
// Request body: { placeId?: string, queryHash?: string, query?: string }
// Exactly one of placeId / queryHash identifies the cache row to check.
//
// Steps (mirrors the spec exactly):
//   1. synthesized_label fresh?      -> return it, skip Apify AND on-device ML
//   2. raw_scrape present but no
//      fresh synthesized_label?      -> return raw_scrape for on-device synthesis
//   3. nothing cached / stale?       -> call Apify, cache raw_scrape, return it
//   4. (client-side, not here) the client runs Foundation Models synthesis
//      on-device and PATCHes synthesized_label back so every future viewer
//      of this place skips both Apify and on-device ML.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const APIFY_TOKEN = Deno.env.get("APIFY_TOKEN");

// service_role bypasses RLS — this function is the only writer of
// place_cache.raw_scrape / synthesized_label, by design (see migration).
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface RequestBody {
  placeId?: string;
  queryHash?: string;
  query?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { placeId, queryHash, query }: RequestBody = await req.json();
  if (!placeId && !queryHash) {
    return new Response(
      JSON.stringify({ error: "placeId or queryHash is required" }),
      { status: 400, headers: { "Content-Type": "application/json" } },
    );
  }

  const cacheKeyColumn = placeId ? "place_id" : "query_hash";
  const cacheKeyValue = placeId ?? queryHash;

  const { data: cached, error: readError } = await supabase
    .from("place_cache")
    .select("*")
    .eq(cacheKeyColumn, cacheKeyValue)
    .maybeSingle();

  if (readError) {
    return new Response(JSON.stringify({ error: readError.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // Step 1: fresh synthesized result — skip Apify AND on-device ML entirely.
  if (cached && cached.synthesized_label && !cached.is_stale) {
    return json({ status: "synthesized", data: cached.synthesized_label });
  }

  // Step 2: raw scrape already cached but not (freshly) synthesized —
  // hand it back so the client can run on-device Foundation Models synthesis
  // without us paying for another Apify run.
  if (cached && cached.raw_scrape && !cached.is_stale) {
    return json({ status: "raw_only", data: cached.raw_scrape });
  }

  // Step 3: nothing usable cached — this is the only branch that spends money.
  // TODO(owner-1): replace with a real Apify actor run using APIFY_TOKEN.
  if (!APIFY_TOKEN) {
    return json(
      { error: "APIFY_TOKEN not configured — see backend/supabase/.env.example" },
      500,
    );
  }

  const rawScrape = await runApifyScrape(query ?? placeId ?? queryHash!);

  const { error: writeError } = await supabase.from("place_cache").upsert(
    {
      place_id: placeId ?? null,
      query_hash: queryHash ?? null,
      raw_scrape: rawScrape,
      is_stale: false,
    },
    { onConflict: cacheKeyColumn },
  );

  if (writeError) {
    return json({ error: writeError.message }, 500);
  }

  return json({ status: "raw_only", data: rawScrape });
});

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

// TODO(owner-1): real Apify actor call. Kept isolated so it's the one thing
// that costs money — never call this from anywhere else.
async function runApifyScrape(searchTerm: string): Promise<unknown> {
  throw new Error(`Apify integration not implemented yet (query: ${searchTerm})`);
}
