// supabase/functions/place-accessibility/index.ts
//
// Owner 1 — Search & Discover. Gates every optional paid call in the
// accessibility-enrichment pipeline. See docs/specs.md §4.1/§6 and Flow A in
// docs/architecture-plan-v2.excalidraw.
//
// Google-primary, OSM-supplement (2026-08-13): search/geocoding is MapKit's
// job entirely on-device (free, no key), so this function only ever receives
// an already-resolved location. On a cache miss it tries Google Places FIRST
// (the trusted accessibility source, when GOOGLE_MAPS_API_KEY is set), then
// also queries OpenStreetMap/Overpass (free) to cover places Google has no
// data for. Both feed the confidence-weighted grade, Google weighted higher.
// The 90-day place_cache means each place is fetched from Google at most once
// per cycle regardless of how many users view it — that's the cost control.
// If no key is configured the function still works, on OSM data alone.
//
// Request body: { lat: number, lng: number, name?: string }
// `name` is required for the Google lookup (Text Search needs a query); the
// OSM lookup needs nothing but the coordinate.
//
// Response: merged base data + the live confidence-weighted grade from
// accessibility_grade() (see the migrations for how that's computed).

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GOOGLE_MAPS_API_KEY = Deno.env.get("GOOGLE_MAPS_API_KEY"); // optional — see module comment
const MAPILLARY_TOKEN = Deno.env.get("MAPILLARY_TOKEN"); // optional — open street-level imagery (CC BY-SA)
const PLACE_IMAGES_BUCKET = "place-images";

// service_role bypasses RLS — this function is the only writer of
// place_cache / google+osm accessibility_signals rows, by design.
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

const PLACE_CACHE_TTL_DAYS = 90; // accessibility features change slowly
const GOOGLE_FIELD_MASK = "id,displayName,location,accessibilityOptions";

interface RequestBody {
  lat: number;
  lng: number;
  name?: string;
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

  const { lat, lng, name }: RequestBody = await req.json();
  if (typeof lat !== "number" || typeof lng !== "number") {
    return json({ error: "lat and lng are required numbers" }, 400);
  }

  const placeId = canonicalPlaceId(lat, lng);

  const { data: cached } = await supabase
    .from("place_cache")
    .select("*")
    .eq("place_id", placeId)
    .maybeSingle();

  const needsRefresh = !cached || isExpired(cached.fetched_at, PLACE_CACHE_TTL_DAYS) ||
    (!cached.osm_accessibility && !cached.google_accessibility);

  if (needsRefresh) {
    await ensurePlaceRow(placeId, lat, lng, name);

    // Primary: Google Places (when a key is configured). This is the trusted
    // accessibility source; the result is cached for PLACE_CACHE_TTL_DAYS, so
    // a place is only ever fetched from Google once per cycle no matter how
    // many users look at it — that's what keeps the paid call count down.
    if (GOOGLE_MAPS_API_KEY && name) {
      try {
        await tryEnrichFromGoogle(placeId, lat, lng, name);
      } catch (err) {
        // Never fail the whole request on a Google error — OSM below (and
        // any existing cached data) can still answer.
        console.error("Google enrichment failed (non-fatal):", err);
      }
    }

    // Supplement/fallback: OpenStreetMap (free). Still queried so places
    // Google has no accessibilityOptions for can be covered by community
    // tags, and both feed the confidence-weighted grade. Costs nothing, so
    // there's no reason to skip it even when Google returned data.
    await tryEnrichFromOSM(placeId, lat, lng);

    // Photo: Mapillary (open, CC BY-SA street-level imagery). Downloaded once
    // and stored in Supabase Storage — its license permits caching the bytes,
    // and its own thumbnail URLs expire, so we store our own permanent copy.
    await tryCacheMapillaryImage(placeId, lat, lng);
  }

  const { data: grade } = await supabase.rpc("accessibility_grade", { target_place_id: placeId });
  const { data: place } = await supabase.from("place_cache").select("*").eq("place_id", placeId).maybeSingle();

  return json({ status: "ok", place, grade });
});

// --- identity ---------------------------------------------------------------

// Our own canonical location key — deliberately NOT tied to any provider's
// ID, so nothing about place identity depends on Google being available.
// ~1.1m precision at the equator, plenty for "is this the same place".
function canonicalPlaceId(lat: number, lng: number): string {
  return `loc_${lat.toFixed(5)}_${lng.toFixed(5)}`;
}

async function ensurePlaceRow(placeId: string, lat: number, lng: number, name?: string): Promise<void> {
  await supabase.from("place_cache").upsert(
    { place_id: placeId, lat, lng, name: name ?? null, fetched_at: new Date().toISOString() },
    { onConflict: "place_id" },
  );
}

// --- OpenStreetMap (Overpass) — PRIMARY, free, keyless, best-effort --------

async function tryEnrichFromOSM(placeId: string, lat: number, lng: number): Promise<void> {
  try {
    const osmTags = await overpassWheelchairTag(lat, lng);
    if (!osmTags) return;

    await supabase.from("place_cache").update({ osm_accessibility: osmTags }).eq("place_id", placeId);

    if (osmTags.wheelchair) {
      const value = osmTags.wheelchair === "yes" ? "yes" : osmTags.wheelchair === "limited" ? "limited" : "no";
      await supabase.from("accessibility_signals").upsert(
        { place_id: placeId, feature: "entrance", value, source: "osm", user_id: null, confidence_weight: 0.5 },
        { onConflict: "place_id,feature,source,user_id" },
      );
    }
  } catch (err) {
    // Overpass is public infrastructure with no SLA (see docs/specs.md §9) —
    // genuinely does return a transient "server too busy" 200-OK HTML body
    // under load (confirmed by hand during integration), separate from the
    // 406 rejection fixed above. Either way, a failure here must never fail
    // the whole request — Google (if enabled) or a plain cache miss still
    // return fine.
    console.error("OSM enrichment failed (non-fatal):", err);
  }
}

async function overpassWheelchairTag(lat: number, lng: number): Promise<Record<string, string> | null> {
  // OSM tags accessibility per physical feature (an entrance, an elevator, a
  // specific business) rather than at "the place"'s general coordinate, so a
  // tight radius mostly misses everything — confirmed against real coordinates
  // (Berlin Hauptbahnhof) during integration: 25m found nothing, even though
  // several wheelchair-tagged features sit within ~100m. Widen the radius and
  // pick the nearest tagged feature by actual distance, not Overpass's
  // arbitrary result order.
  const radiusMeters = 100;
  const ql = `[out:json][timeout:15];(node(around:${radiusMeters},${lat},${lng})["wheelchair"];way(around:${radiusMeters},${lat},${lng})["wheelchair"];);out tags center 10;`;

  // One retry with backoff — the public instance's "server too busy" response
  // is common enough in practice (observed firsthand while integrating this)
  // that a single retry meaningfully improves real-world hit rate.
  let lastErr: unknown;
  for (const delayMs of [0, 1500]) {
    if (delayMs) await new Promise((r) => setTimeout(r, delayMs));
    try {
      const res = await fetch("https://overpass-api.de/api/interpreter", {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
          // Overpass's usage policy asks callers to identify themselves —
          // without this, the public instance returns 406 Not Acceptable.
          // Confirmed by direct testing: identical requests with vs without
          // a descriptive User-Agent were the actual difference, not server
          // load as first assumed.
          "User-Agent": "puspadi-fellas-accessibility/1.0 (github.com/joelvshimself/puspadi-fellas)",
        },
        body: `data=${encodeURIComponent(ql)}`,
      });
      const text = await res.text();
      if (!res.ok || text.includes("The server is probably too busy")) {
        lastErr = new Error(`Overpass busy/error (status ${res.status})`);
        continue;
      }
      const data = JSON.parse(text);
      const elements: Array<{ tags?: Record<string, string>; lat?: number; lon?: number; center?: { lat: number; lon: number } }> =
        data.elements ?? [];
      if (elements.length === 0) return null;

      const nearest = elements.reduce((best, el) => {
        const elLat = el.lat ?? el.center?.lat;
        const elLon = el.lon ?? el.center?.lon;
        if (elLat === undefined || elLon === undefined) return best;
        const d = haversineMeters(lat, lng, elLat, elLon);
        return d < best.d ? { d, el } : best;
      }, { d: Infinity, el: elements[0] });

      return nearest.el.tags ?? null;
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr;
}

function haversineMeters(lat1: number, lon1: number, lat2: number, lon2: number): number {
  const R = 6371000;
  const toRad = (deg: number) => (deg * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLon = toRad(lon2 - lon1);
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

// --- Mapillary — open street-level imagery (CC BY-SA), optional ------------

interface MapillaryImage {
  id: string;
  thumb_1024_url?: string;
  geometry?: { coordinates?: [number, number] }; // [lon, lat]
}

/// Finds the nearest Mapillary image to the coordinate, downloads it once, and
/// stores it in Supabase Storage — then records the permanent public URL on
/// place_cache. No-op (leaves image_url null) if no token or no coverage; the
/// client then falls back to Look Around / a map snapshot.
async function tryCacheMapillaryImage(placeId: string, lat: number, lng: number): Promise<void> {
  if (!MAPILLARY_TOKEN) return;
  try {
    // bbox must be < 0.01 deg square per Mapillary; ~0.0009 ≈ 100m.
    const d = 0.0009;
    const bbox = `${lng - d},${lat - d},${lng + d},${lat + d}`;
    const url =
      `https://graph.mapillary.com/images?fields=id,thumb_1024_url,geometry&bbox=${bbox}&limit=10`;
    const res = await fetch(url, { headers: { Authorization: `OAuth ${MAPILLARY_TOKEN}` } });
    if (!res.ok) return;
    const data = await res.json();
    const images: MapillaryImage[] = data.data ?? [];
    if (images.length === 0) return;

    // Nearest image to the place, not just the first Mapillary returned.
    let best: MapillaryImage | null = null;
    let bestDist = Infinity;
    for (const img of images) {
      const coords = img.geometry?.coordinates;
      if (!coords || !img.thumb_1024_url) continue;
      const dist = haversineMeters(lat, lng, coords[1], coords[0]);
      if (dist < bestDist) { bestDist = dist; best = img; }
    }
    if (!best?.thumb_1024_url) return;

    // Download the (TTL'd) thumbnail and store our own permanent copy.
    const imgRes = await fetch(best.thumb_1024_url);
    if (!imgRes.ok) return;
    const bytes = new Uint8Array(await imgRes.arrayBuffer());

    const path = `${placeId}.jpg`;
    const { error: upErr } = await supabase.storage
      .from(PLACE_IMAGES_BUCKET)
      .upload(path, bytes, { contentType: "image/jpeg", upsert: true });
    if (upErr) {
      console.error("Mapillary image upload failed (non-fatal):", upErr);
      return;
    }

    const { data: pub } = supabase.storage.from(PLACE_IMAGES_BUCKET).getPublicUrl(path);
    await supabase.from("place_cache").update({
      image_url: pub.publicUrl,
      image_attribution: "Imagery © Mapillary contributors (CC BY-SA 4.0)",
    }).eq("place_id", placeId);
  } catch (err) {
    // Photo is a nice-to-have; never fail the request over it.
    console.error("Mapillary caching failed (non-fatal):", err);
  }
}

// --- Google Places (New) — PRIMARY accessibility source, Pro tier ---------

async function tryEnrichFromGoogle(placeId: string, lat: number, lng: number, name: string): Promise<void> {
  const place = await googleTextSearchNear(name, lat, lng);
  if (!place) return;

  await supabase.from("place_cache").update({
    google_place_id: place.id,
    google_accessibility: place.accessibilityOptions ?? {},
  }).eq("place_id", placeId);

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
            place_id: placeId,
            feature,
            value: place.accessibilityOptions[key] ? "yes" : "no",
            source: "google",
            user_id: null,
            confidence_weight: 0.6, // Google is the primary source; outweighs OSM's 0.5
          },
          { onConflict: "place_id,feature,source,user_id" },
        );
      }
    }
  }
}

async function googleTextSearchNear(name: string, lat: number, lng: number): Promise<GooglePlace | null> {
  const res = await fetch("https://places.googleapis.com/v1/places:searchText", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "X-Goog-Api-Key": GOOGLE_MAPS_API_KEY!,
      "X-Goog-FieldMask": `places.${GOOGLE_FIELD_MASK.split(",").join(",places.")}`,
    },
    body: JSON.stringify({
      textQuery: name,
      locationBias: { circle: { center: { latitude: lat, longitude: lng }, radius: 100 } },
    }),
  });
  if (!res.ok) throw new Error(`Google Text Search failed: ${res.status} ${await res.text()}`);
  const data = await res.json();
  return data.places?.[0] ?? null;
}

// --- helpers ---------------------------------------------------------------

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

function isExpired(dateStr: string | null, days: number): boolean {
  if (!dateStr) return true;
  return Date.now() - new Date(dateStr).getTime() > days * 86_400_000;
}
