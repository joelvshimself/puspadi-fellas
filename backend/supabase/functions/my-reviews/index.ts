// supabase/functions/my-reviews/index.ts
//
// Returns the signed-in user's reviews for the Profile screen (Reviews + Photos tabs).
// Includes profile header fields and flattened review text, features, and photo URLs.
//
// Auth: caller must send a Supabase user JWT. user_id is taken from that session.
//
// Request:  POST (empty body)
// Response: { status, userName, userRole, profileImageUrl, reviews: [...] }

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface ReviewEntranceRow {
  review_id: string;
  location: string;
  has_dropoff_ramp: boolean | null;
  has_rails: boolean | null;
  door_type: string | null;
  is_wide_enough: boolean | null;
  review_text: string | null;
  photo_urls: string[] | null;
  sort_order: number;
}

interface ReviewRow {
  id: string;
  place_id: string;
  created_at: string;
  notes: string | null;
  elevator_exists: boolean | null;
  elevator_wheelchair_accessible: boolean | null;
  elevator_blockers: string[] | null;
  elevator_review_text: string | null;
  elevator_photo_urls: string[] | null;
  has_disabled_toilet: boolean | null;
  toilet_review_text: string | null;
  toilet_photo_urls: string[] | null;
}

interface ProfileRow {
  display_name: string | null;
  avatar_url: string | null;
  mobility_aids: string[] | null;
}

interface MyReviewItem {
  id: string;
  placeId: string;
  placeName: string;
  createdAt: string;
  reviewText: string;
  providedFeatures: string[];
  photoUrls: string[];
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const userId = await requireUserId(req);
  if (!userId) {
    return json({ error: "sign in required" }, 401);
  }

  const { data: profile, error: profileError } = await supabase
    .from("profiles")
    .select("display_name, avatar_url, mobility_aids")
    .eq("id", userId)
    .maybeSingle();

  if (profileError) {
    console.error("profile query failed:", profileError);
    return json({ error: "failed to load profile", detail: profileError.message }, 500);
  }

  const { data: reviews, error: reviewsError } = await supabase
    .from("reviews")
    .select(`
      id, place_id, created_at, notes,
      elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
      elevator_review_text, elevator_photo_urls,
      has_disabled_toilet, toilet_review_text, toilet_photo_urls
    `)
    .eq("user_id", userId)
    .order("created_at", { ascending: false });

  if (reviewsError) {
    console.error("reviews query failed:", reviewsError);
    return json({ error: "failed to load reviews", detail: reviewsError.message }, 500);
  }

  const reviewRows = (reviews ?? []) as ReviewRow[];
  const reviewIds = reviewRows.map((r) => r.id);

  let entrancesByReview = new Map<string, ReviewEntranceRow[]>();
  if (reviewIds.length > 0) {
    const { data: entrances, error: entrancesError } = await supabase
      .from("review_entrances")
      .select(`
        review_id, location, has_dropoff_ramp, has_rails, door_type,
        is_wide_enough, review_text, photo_urls, sort_order
      `)
      .in("review_id", reviewIds)
      .order("sort_order", { ascending: true });

    if (entrancesError) {
      console.error("review_entrances query failed:", entrancesError);
      return json({
        error: "failed to load entrance details",
        detail: entrancesError.message,
      }, 500);
    }

    for (const row of (entrances ?? []) as ReviewEntranceRow[]) {
      const list = entrancesByReview.get(row.review_id) ?? [];
      list.push(row);
      entrancesByReview.set(row.review_id, list);
    }
  }

  const placeIds = [...new Set(reviewRows.map((r) => r.place_id))];
  const placeNames = new Map<string, string>();
  if (placeIds.length > 0) {
    const { data: places, error: placesError } = await supabase
      .from("place_cache")
      .select("place_id, name")
      .in("place_id", placeIds);

    if (placesError) {
      console.error("place_cache query failed:", placesError);
    } else {
      for (const place of places ?? []) {
        if (place.name) placeNames.set(place.place_id as string, place.name as string);
      }
    }
  }

  const items: MyReviewItem[] = reviewRows.map((row) => {
    const entrances = entrancesByReview.get(row.id) ?? [];
    return {
      id: row.id,
      placeId: row.place_id,
      placeName: placeNames.get(row.place_id) ?? row.place_id,
      createdAt: row.created_at,
      reviewText: primaryNotes(row, entrances),
      providedFeatures: providedFeatures(row, entrances),
      photoUrls: allPhotoUrls(row, entrances),
    };
  });

  const profileRow = profile as ProfileRow | null;
  const mobilityAids = profileRow?.mobility_aids ?? [];

  return json({
    status: "ok",
    userName: profileRow?.display_name?.trim() || "You",
    userRole: deriveUserRole(mobilityAids),
    profileImageUrl: profileRow?.avatar_url ?? null,
    reviews: items,
  });
});

function deriveUserRole(mobilityAids: string[]): string | null {
  if (mobilityAids.length === 0) return null;
  if (mobilityAids.includes("Wheelchair")) return "Wheelchair User";
  return "Community Contributor";
}

function entranceTags(entrance: ReviewEntranceRow): string[] {
  const tags: string[] = [];
  if (entrance.has_dropoff_ramp === true) tags.push("Ramp");
  if (entrance.has_rails === true) tags.push("Handrail");
  if (entrance.door_type === "automatic") tags.push("Automatic Doors");
  if (entrance.door_type === "manual") tags.push("Manual Doors");
  return tags;
}

function providedFeatures(row: ReviewRow, entrances: ReviewEntranceRow[]): string[] {
  const tags: string[] = [];
  for (const entrance of entrances) {
    tags.push(...entranceTags(entrance));
  }
  if (row.elevator_exists === true) tags.push("Elevator");
  if (row.has_disabled_toilet === true) tags.push("Toilet");
  return [...new Set(tags)];
}

function primaryNotes(row: ReviewRow, entrances: ReviewEntranceRow[]): string {
  if (row.notes && row.notes.trim().length > 0) return row.notes.trim();
  if (row.elevator_review_text && row.elevator_review_text.trim().length > 0) {
    return row.elevator_review_text.trim();
  }
  if (row.toilet_review_text && row.toilet_review_text.trim().length > 0) {
    return row.toilet_review_text.trim();
  }
  for (const entrance of entrances) {
    if (entrance.review_text && entrance.review_text.trim().length > 0) {
      return entrance.review_text.trim();
    }
  }
  return "No review notes written.";
}

function allPhotoUrls(row: ReviewRow, entrances: ReviewEntranceRow[]): string[] {
  const urls: string[] = [];
  for (const entrance of entrances) {
    urls.push(...((entrance.photo_urls ?? []).filter((u) => typeof u === "string" && u.length > 0)));
  }
  urls.push(...((row.elevator_photo_urls ?? []).filter((u) => typeof u === "string" && u.length > 0)));
  urls.push(...((row.toilet_photo_urls ?? []).filter((u) => typeof u === "string" && u.length > 0)));
  return urls;
}

async function requireUserId(req: Request): Promise<string | null> {
  const authorization = req.headers.get("Authorization");
  if (!authorization) return null;
  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authorization } },
  });
  const { data: { user }, error } = await userClient.auth.getUser();
  if (error || !user) return null;
  return user.id;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
