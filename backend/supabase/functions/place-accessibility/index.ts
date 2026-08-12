// supabase/functions/place-accessibility/index.ts
//
// Owner 1 — Search & Discover. The money gate: the ONLY place that calls the
// Google Places API (Pro-tier accessibilityOptions field). See docs/specs.md
// §4.1/§6 and Flow A in docs/architecture-plan-v2.excalidraw.
//
// Pivoted from the original Apify/TikTok design (see git history) — base
// accessibility data now comes from Google Places + OpenStreetMap, not video
// scraping. The caching shape carries over unchanged: place_cache still gates
// every paid call, it just gates a different upstream now.
//
// Request body:
//   { query: string }                          -- descriptive search
//   { placeId: string }                        -- exact-location lookup
//
// Response: merged base data + the live confidence-weighted grade from
// accessibility_grade() (see the migration for how that's computed).

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_MAPS_API_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY");

// service_role bypasses RLS — this function is the only writer of
// place_cache / google+osm accessibility_signals rows, by design.
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const PLACE_CACHE_TTL_DAYS = 90; // accessibility features change slowly
const GOOGLE_FIELD_MASK = "id,displayName,location,accessibilityOptions";

interface RequestBody {
  query?: string;
  placeId?: string;
}

interface GooglePlace {
  id: string;
  displayName?: { text?: string };
  location?: { latitude: number; longitude: number };
  accessibilityOptions?: Record<string, boolean>;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { query, placeId }: RequestBody = await req.json();

  if (query && !placeId) {
    return await handleDescriptiveSearch(query);
  }
  if (placeId) {
    return await handlePlaceLookup(placeId);
  }
  return json({ error: "query or placeId is required" }, 400);
});

async function handleDescriptiveSearch(query: string): Promise<Response> {
  const queryHash = await sha256(query.trim().toLowerCase());

  const { data: cached } = await supabase
    .from("search_query_cache")
    .select("*")
    .eq("query_hash", queryHash)
    .maybeSingle();

  if (cached && !isExpired(cached.expires_at)) {
    return json({ status: "cached", placeIds: cached.place_ids });
  }

  // Cache miss — the only branch that spends a Pro-tier Text Search call.
  if (!GOOGLE_MAPS_API_KEY) {
    return json({ error: "GOOGLE_MAPS_API_KEY not configured — see backend/.env.example" }, 500);
  }

  const places = await googleTextSearch(query);

  await Promise.all(places.map((p) => upsertPlaceFromGoogle(p)));

  const placeIds = places.map((p) => p.id);
  await supabase.from("search_query_cache").upsert({
    query_hash: queryHash,
    place_ids: placeIds,
    fetched_at: new Date().toISOString(),
    expires_at: addDays(new Date(), 30).toISOString(), // search results churn faster than place data
  });

  return json({ status: "fresh", placeIds });
}

async function handlePlaceLookup(placeId: string): Promise<Response> {
  const { data: cached } = await supabase
    .from("place_cache")
    .select("*")
    .eq("place_id", placeId)
    .maybeSingle();

  if (!cached || isExpired(cached.fetched_at, PLACE_CACHE_TTL_DAYS) || !cached.google_accessibility) {
    if (!GOOGLE_MAPS_API_KEY) {
      return json({ error: "GOOGLE_MAPS_API_KEY not configured — see backend/.env.example" }, 500);
    }
    const place = await googlePlaceDetails(placeId);
    await upsertPlaceFromGoogle(place);
    await tryEnrichFromOSM(place);
  }

  const { data: grade } = await supabase.rpc("accessibility_grade", { target_place_id: placeId });
  const { data: place } = await supabase.from("place_cache").select("*").eq("place_id", placeId).maybeSingle();

  return json({ status: "ok", place, grade });
}

// --- Google Places (New) -------------------------------------------------

async function googlePlaceDetails(placeId: string): Promise<GooglePlace> {
  const res = await fetch(`https://places.googleapis.com/v1/places/${placeId}`, {
    headers: {
      "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY!,
      "X-Goog-FieldMask": GOOGLE_FIELD_MASK,
    },
  });
  if (!res.ok) throw new Error(`Google Place Details failed: ${res.status} ${await res.text()}`);
  return await res.json();
}

async function googleTextSearch(query: string): Promise<GooglePlace[]> {
  // Text Search (New) returns accessibilityOptions in the same call when the
  // field mask asks for it — one Pro-tier call covers search + accessibility
  // for every candidate, instead of a search call plus a details call each.
  const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY!,
      "X-Goog-FieldMask": `places.${GOOGLE_FIELD_MASK.split(",").join(",places.")}`,
    },
    body: JSON.stringify({ textQuery: query }),
  });
  if (!res.ok) throw new Error(`Google Text Search failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.places ?? [];
}

async function upsertPlaceFromGoogle(place: GooglePlace): Promise<void> {
  await supabase.from("place_cache").upsert(
    {
      place_id: place.id,
      name: place.displayName?.text ?? null,
      lat: place.location?.latitude ?? null,
      lng: place.location?.longitude ?? null,
      google_accessibility: place.accessibilityOptions ?? {},
      fetched_at: new Date().toISOString(),
    },
    { onConflict: "place_id" },
  );

  if (place.accessibilityOptions) {
    const featureMap: Record<string, "entrance" | "parking" | "restroom" | "seating"> = {
      wheelchairAccessibleEntrance: "entrance",
      wheelchairAccessibleParking: "parking",
      wheelchairAccessibleRestroom: "restroom",
      wheelchairAccessibleSeating: "seating",
    };
    for (const [key, feature] of Object.entries(featureMap)) {
      if (key in place.accessibilityOptions) {
        await supabase.from("accessibility_signals").upsert(
          {
            place_id: place.id,
            feature,
            value: place.accessibilityOptions[key] ? "yes" : "no",
            source: "google",
            user_id: null,
            confidence_weight: 0.6,
          },
          { onConflict: "place_id,feature,source,user_id" },
        );
      }
    }
  }
}

// --- OpenStreetMap (Overpass) — best-effort, never blocks the response ---

async function tryEnrichFromOSM(place: GooglePlace): Promise<void> {
  if (!place.location) return;
  try {
    const osmTags = await overpassWheelchairTag(place.location.latitude, place.location.longitude);
    if (!osmTags) return;

    await supabase
      .from("place_cache")
      .update({ osm_accessibility: osmTags })
      .eq("place_id", place.id);

    if (osmTags.wheelchair) {
      const value = osmTags.wheelchair === "yes" ? "yes" : osmTags.wheelchair === "limited" ? "limited" : "no";
      await supabase.from("accessibility_signals").upsert(
        {
          place_id: place.id,
          feature: "entrance",
          value,
          source: "osm",
          user_id: null,
          confidence_weight: 0.5,
        },
        { onConflict: "place_id,feature,source,user_id" },
      );
    }
  } catch (err) {
    // OSM/Overpass is a free best-effort source with no SLA — a failure here
    // should never fail the whole request, Google data is still returned.
    console.error("OSM enrichment failed (non-fatal):", err);
  }
}

async function overpassWheelchairTag(lat: number, lng: number): Promise<Record<string, string> | null> {
  const radiusMeters = 25;
  const ql = `[out:json][timeout:10];(node(around:${radiusMeters},${lat},${lng})["wheelchair"];way(around:${radiusMeters},${lat},${lng})["wheelchair"];);out tags 1;`;
  const res = await fetch("https://overpass-api.de/api/interpreter", {
    method: "POST",
    body: `data=${encodeURIComponent(ql)}`,
  });
  if (!res.ok) return null;
  const data = await res.json();
  return data.elements?.[0]?.tags ?? null;
}

// --- helpers ---------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function isExpired(dateStr: string | null, days?: number): boolean {
  if (!dateStr) return true;
  if (days === undefined) return new Date(dateStr).getTime() < Date.now();
  return Date.now() - new Date(dateStr).getTime() > days * 86_400_000;
}

function addDays(date: Date, days: number): Date {
  return new Date(date.getTime() + days * 86_400_000);
}

async function sha256(text: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest)).map((b) => b.toString(16).padStart(2, "0")).join("");
}
