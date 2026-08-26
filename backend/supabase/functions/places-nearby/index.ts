// supabase/functions/places-nearby/index.ts
//
// The directory read side — curated places near a coordinate, straight out of
// place_cache.
//
// WHY THIS EXISTS
// ---------------
// Until now the client's only source of places was MKLocalSearch: HomeMapView
// swept the visible region for "shopping mall" and SearchSheet ran its own
// query per keystroke. place_cache was a cache of whatever that happened to
// return, never a list anything could browse — nearby_places() has been in the
// schema since the first migration and has never had a caller.
//
// That is fine until you have data of your own. The Bali mall seed is 22 malls
// we deliberately imported, with addresses, hours and (soon) grades; MapKit
// returns a different subset of them depending on the region, the spelling and
// the day, so seeding alone would leave most of them invisible. This function
// is what makes the seeded directory the authority for "what malls are near
// me", with MapKit merged in on the client as the long tail.
//
// Request:  { lat, lng, radiusMeters?, limit? }
// Response: { status: "ok", places: [...], attribution: [...] }
//
// Public (verify_jwt = false): a directory of malls is public information, and
// the same rows are already readable through PostgREST under place_cache's
// "publicly readable" policy. This exists for the RPC and the shaping, not to
// gate anything.

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

/// Wide by default: south Bali end to end is about 25km, and the point of the
/// directory is that a user in Kuta can see Denpasar's malls exist. Capped in
/// the RPC too, so a hand-rolled request cannot ask for the planet.
const DEFAULT_RADIUS_M = 15_000;
const MAX_RADIUS_M = 50_000;
const DEFAULT_LIMIT = 100;

interface RequestBody {
  lat?: unknown;
  lng?: unknown;
  radiusMeters?: unknown;
  limit?: unknown;
}

Deno.serve(async (req: Request) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return json({ error: "invalid JSON body" }, 400);
  }

  const lat = Number(body.lat);
  const lng = Number(body.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return json({ error: "lat and lng are required numbers" }, 400);
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return json({ error: "lat/lng out of range" }, 400);
  }

  const radius = clamp(toInt(body.radiusMeters, DEFAULT_RADIUS_M), 100, MAX_RADIUS_M);
  const limit = clamp(toInt(body.limit, DEFAULT_LIMIT), 1, 500);

  const { data, error } = await supabase.rpc("places_directory_nearby", {
    user_lat: lat,
    user_lng: lng,
    radius_meters: radius,
    max_results: limit,
  });

  if (error) {
    console.error("places_directory_nearby failed:", error);
    return json({ error: "failed to load places", detail: error.message }, 500);
  }

  const rows = (data ?? []) as DirectoryRow[];

  return json({
    status: "ok",
    places: rows.map(shape),
    // ODbL requires attribution to travel with the data. Collected from the
    // rows themselves rather than hardcoded, so a directory that later mixes
    // sources credits each of them.
    attribution: [...new Set(rows.map((r) => r.data_attribution).filter(Boolean))],
  });
});

interface DirectoryRow {
  place_id: string;
  name: string | null;
  lat: number;
  lng: number;
  address: string | null;
  city: string | null;
  category: string | null;
  phone: string | null;
  website: string | null;
  opening_hours: string | null;
  levels: number | null;
  image_url: string | null;
  image_attribution: string | null;
  data_attribution: string | null;
  distance_meters: number;
  worst_value: "yes" | "no" | "limited" | "unknown";
  graded_features: number;
  /// Every name this place is known by. The client has no copy of
  /// place_aliases, so without these it can only match a MapKit result against
  /// the seeded name — and "Park23" does not equal "Park23 Mall", which is how
  /// one building ended up with two pins on the map.
  aliases: string[] | null;
}

/// snake_case in, camelCase out — the Swift client decodes these with
/// convertFromSnakeCase off for review rows and on for enrichment, so the
/// safest thing a NEW endpoint can do is speak the client's own idiom.
function shape(row: DirectoryRow) {
  return {
    placeId: row.place_id,
    name: row.name ?? "Place",
    lat: row.lat,
    lng: row.lng,
    address: row.address,
    city: row.city,
    category: row.category ?? "Mall",
    phone: row.phone,
    website: row.website,
    openingHours: row.opening_hours,
    levels: row.levels,
    imageUrl: row.image_url,
    imageAttribution: row.image_attribution,
    attribution: row.data_attribution,
    distanceMeters: Math.round(row.distance_meters),
    // 0 graded features means nobody has said anything about this place yet,
    // which the client renders as an unrated pin — distinct from a place that
    // has been assessed and found inaccessible.
    grade: row.graded_features > 0 ? row.worst_value : "unknown",
    gradedFeatures: row.graded_features,
    aliases: row.aliases ?? [],
  };
}

function toInt(value: unknown, fallback: number): number {
  const n = Number(value);
  return Number.isFinite(n) ? Math.trunc(n) : fallback;
}

function clamp(n: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, n));
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}
