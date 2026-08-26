// supabase/functions/place-reviews/index.ts
//
// Community reviews for one place, WITH reviewer identity (Figma "Reviewed"
// review cards: avatar, name, role). The iOS client used to query `reviews`
// directly, but reviewer info lives in `profiles` and RLS only lets a user
// read their OWN profile row — so names could never come from the client.
// The service role joins them here.
//
// Request:  { placeId: string }  — the id enrich() resolved; same id
//           submit-accessibility-review filed the rows under.
// Response: { status: "ok", reviews: [...] } — flattened snake_case rows in
//           the exact shape the client's DBPlaceReviewRow already decodes,
//           plus reviewer_name / reviewer_role / reviewer_avatar_url.
//
// Public (verify_jwt = false in config.toml): review reads are public in the
// product, and only display-safe profile fields ever leave this function.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: { placeId?: unknown };
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }
  const placeId = typeof body.placeId === "string" ? body.placeId : "";
  if (placeId.length === 0 || placeId.length > 200) {
    return json({ error: "placeId is required" }, 400);
  }

  const { data: reviews, error: reviewsError } = await supabase
    .from("reviews")
    .select(`
      id, user_id, created_at, notes,
      elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
      elevator_review_text, elevator_photo_urls, elevator_photo_captions,
      has_disabled_toilet, toilet_review_text, toilet_photo_urls, toilet_photo_captions
    `)
    .eq("place_id", placeId)
    .order("created_at", { ascending: false });

  if (reviewsError) {
    console.error("reviews query failed:", reviewsError);
    return json({ error: "failed to load reviews", detail: reviewsError.message }, 500);
  }

  const rows = reviews ?? [];
  const reviewIds = rows.map((r) => r.id as string);

  // Entrance children, grouped per review.
  const entrancesByReview = new Map<string, unknown[]>();
  if (reviewIds.length > 0) {
    const { data: entrances, error: entrancesError } = await supabase
      .from("review_entrances")
      .select("review_id, location, has_dropoff_ramp, has_rails, door_type, is_wide_enough, review_text, photo_urls, photo_captions")
      .in("review_id", reviewIds)
      .order("sort_order", { ascending: true });

    if (entrancesError) {
      console.error("review_entrances query failed:", entrancesError);
      return json({ error: "failed to load entrance details", detail: entrancesError.message }, 500);
    }
    for (const row of entrances ?? []) {
      const id = row.review_id as string;
      const { review_id: _dropped, ...rest } = row;
      const list = entrancesByReview.get(id) ?? [];
      list.push(rest);
      entrancesByReview.set(id, list);
    }
  }

  // Reviewer identity — display-safe fields only.
  const userIds = [...new Set(rows.map((r) => r.user_id as string | null).filter(Boolean))] as string[];
  const profiles = new Map<string, { name: string | null; role: string | null; avatar: string | null }>();
  if (userIds.length > 0) {
    const { data: profileRows, error: profilesError } = await supabase
      .from("profiles")
      .select("id, display_name, avatar_url, mobility_aids")
      .in("id", userIds);

    if (profilesError) {
      // Names are an enhancement; the reviews themselves still matter.
      console.error("profiles query failed (continuing anonymous):", profilesError);
    }
    for (const p of profileRows ?? []) {
      profiles.set(p.id as string, {
        name: (p.display_name as string | null)?.trim() || null,
        role: deriveUserRole((p.mobility_aids as string[] | null) ?? []),
        avatar: (p.avatar_url as string | null) ?? null,
      });
    }
  }

  const items = rows.map((r) => {
    const profile = r.user_id ? profiles.get(r.user_id as string) : undefined;
    const { user_id: _dropped, ...rest } = r;
    return {
      ...rest,
      review_entrances: entrancesByReview.get(r.id as string) ?? [],
      reviewer_name: profile?.name ?? null,
      reviewer_role: profile?.role ?? null,
      reviewer_avatar_url: profile?.avatar ?? null,
    };
  });

  return json({ status: "ok", reviews: items });
});

/// Same rule as my-reviews — keep the two in agreement.
function deriveUserRole(mobilityAids: string[]): string | null {
  if (mobilityAids.length === 0) return null;
  if (mobilityAids.includes("Wheelchair")) return "Wheelchair User";
  return "Community Contributor";
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
