// supabase/functions/place-review-photos/index.ts
//
// Returns community review photo URLs for a place, labeled by facility
// (lobby / basement / elevator / toilet). Reads public Storage URLs already
// stored on reviews + review_entrances — does not list the bucket.
//
// Request:  { lat: number, lng: number }
// Response: { status: "ok", placeId, photos: [{ url, facility, label, caption }] }
//
// TODO: re-enable JWT before production — same device-testing stance as
// submit-accessibility-review.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

interface RequestBody {
  lat: number;
  lng: number;
  /// Optional: lets resolve_place_id map this onto the id the grade and the
  /// reviews are actually filed under, instead of the raw coordinate key.
  name?: string;
}

type Facility = "lobby" | "basement" | "elevator" | "toilet" | "exit_side" | "other";

interface PhotoItem {
  url: string;
  facility: Facility;
  label: string;
  caption: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body: RequestBody = await req.json();
  const { lat, lng } = body;
  if (typeof lat !== "number" || typeof lng !== "number") {
    return json({ error: "lat and lng are required numbers" }, 400);
  }

  const placeId = await resolvePlaceId(lat, lng, typeof body.name === "string" ? body.name : undefined) ?? canonicalPlaceId(lat, lng);

  const { data: reviews, error: reviewsError } = await supabase
    .from("reviews")
    .select("id, elevator_photo_urls, elevator_photo_captions, toilet_photo_urls, toilet_photo_captions, created_at")
    .eq("place_id", placeId)
    .order("created_at", { ascending: false });

  if (reviewsError) {
    console.error("reviews query failed:", reviewsError);
    return json({ error: "failed to load reviews", detail: reviewsError.message }, 500);
  }

  if (!reviews || reviews.length === 0) {
    return json({ status: "ok", placeId, photos: [] });
  }

  const reviewIds = reviews.map((r) => r.id as string);

  const { data: entrances, error: entrancesError } = await supabase
    .from("review_entrances")
    .select("review_id, location, photo_urls, photo_captions")
    .in("review_id", reviewIds);

  if (entrancesError) {
    console.error("review_entrances query failed:", entrancesError);
    return json({
      error: "failed to load entrance photos",
      detail: entrancesError.message,
    }, 500);
  }

  // Newest review first: group entrances by review, then walk reviews in
  // submission order (newest to oldest) and append elevator/toilet photos.
  const entrancesByReview = new Map<string, Array<{ location: string; photo_urls: string[]; photo_captions: string[] }>>();
  for (const row of entrances ?? []) {
    const id = row.review_id as string;
    const list = entrancesByReview.get(id) ?? [];
    list.push({
      location: row.location as string,
      photo_urls: (row.photo_urls as string[] | null) ?? [],
      photo_captions: (row.photo_captions as string[] | null) ?? [],
    });
    entrancesByReview.set(id, list);
  }

  const photos: PhotoItem[] = [];

  for (const review of reviews) {
    const id = review.id as string;
    for (const entrance of entrancesByReview.get(id) ?? []) {
      const facility = normalizeFacility(entrance.location);
      appendUrls(photos, entrance.photo_urls, entrance.photo_captions, facility);
    }
    appendUrls(
      photos,
      (review.elevator_photo_urls as string[] | null) ?? [],
      (review.elevator_photo_captions as string[] | null) ?? [],
      "elevator",
    );
    appendUrls(
      photos,
      (review.toilet_photo_urls as string[] | null) ?? [],
      (review.toilet_photo_captions as string[] | null) ?? [],
      "toilet",
    );
  }

  return json({ status: "ok", placeId, photos });
});

function appendUrls(
  photos: PhotoItem[],
  urls: string[],
  captions: string[],
  facility: Facility,
) {
  for (let i = 0; i < urls.length; i++) {
    const url = urls[i];
    if (typeof url !== "string" || url.length === 0) continue;
    const rawCaption = typeof captions[i] === "string" ? captions[i].trim() : "";
    photos.push({
      url,
      facility,
      label: facilityLabel(facility),
      caption: rawCaption,
    });
  }
}

function normalizeFacility(location: string): Facility {
  switch (location) {
    case "lobby":
    case "basement":
    case "elevator":
    case "toilet":
    case "exit_side":
    case "other":
      return location;
    default:
      return "other";
  }
}

function facilityLabel(facility: Facility): string {
  switch (facility) {
    case "lobby":
      return "Lobby";
    case "basement":
      return "Basement";
    case "elevator":
      return "Elevator";
    case "toilet":
      return "Toilet";
    case "exit_side":
      return "Exit side";
    case "other":
      return "Other";
  }
}

// Four decimals (~11m), not five. MUST match canonicalPlaceId() in
// place-accessibility/index.ts and PlaceCacheStore.key on the client — a
// review filed under a different id than the one the grade is cached against
// is a review nobody ever sees.
/// Existing id for this venue, or null if we have not seen it. Mirrors the
/// helper in place-accessibility — all three functions must agree on which
/// place an incoming coordinate refers to, or reviews are filed against an id
/// the grade is not cached under.
async function resolvePlaceId(lat: number, lng: number, name?: string): Promise<string | null> {
  if (!name) return null;
  const { data, error } = await supabase.rpc("resolve_place_id", {
    in_lat: lat,
    in_lng: lng,
    in_name: name,
  });
  if (error) {
    console.error("resolve_place_id failed (falling back to coordinate key):", error);
    return null;
  }
  return typeof data === "string" && data.length > 0 ? data : null;
}

function canonicalPlaceId(lat: number, lng: number): string {
  return `loc_${lat.toFixed(4)}_${lng.toFixed(4)}`;
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
