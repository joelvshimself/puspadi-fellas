import type { Auth } from "./auth";
import { requireUserId } from "./auth";
import type { Env } from "./env";
import { HttpError, json, methodNotAllowed } from "./http";
import { isOsmRef } from "./osm";

interface SignalCount {
  place_id: string;
  feature: string;
  value: "yes" | "no" | "limited";
  count: number;
}

export interface FeatureGrade {
  feature: string;
  best_value: SignalCount["value"];
  confidence: number;
}

interface PlaceRow {
  id: string;
  osm_ref: string;
  name: string;
  category: string | null;
  lat: number;
  lng: number;
  address: string | null;
  phone: string | null;
  website: string | null;
  opening_hours: string | null;
  osm_wheelchair: "yes" | "limited" | "no" | null;
}

const DEFAULT_RADIUS = 5_000;
const MAX_RADIUS = 20_000;
const OSM_ATTRIBUTION = "© OpenStreetMap contributors";

/**
 * Clients address a place by its Rollspot ID or by `osm:<type>/<id>`, so a
 * link built from an OSM result works before the app has seen the Rollspot ID.
 */
export async function findPlaceId(env: Env, rawKey: string): Promise<string | null> {
  let key: string;
  try {
    key = decodeURIComponent(rawKey).trim();
  } catch {
    throw new HttpError(400, "Place key is invalid.");
  }
  if (key.startsWith("osm:")) {
    const ref = key.slice(4);
    if (!isOsmRef(ref)) throw new HttpError(400, "OSM place key must look like osm:way/123.");
    const row = await env.DB.prepare(`SELECT id FROM places WHERE osm_ref = ?`).bind(ref).first<{ id: string }>();
    return row?.id ?? null;
  }
  if (!/^[0-9a-f-]{36}$/.test(key)) throw new HttpError(400, "Place ID is invalid.");
  const row = await env.DB.prepare(`SELECT id FROM places WHERE id = ?`).bind(key).first<{ id: string }>();
  return row?.id ?? null;
}

export async function requirePlaceId(env: Env, rawKey: string): Promise<string> {
  const id = await findPlaceId(env, rawKey);
  if (!id) throw new HttpError(404, "Place not found.");
  return id;
}

async function placeRows(env: Env, ids: string[]): Promise<PlaceRow[]> {
  const unique = [...new Set(ids)];
  if (!unique.length) return [];
  const rows = await env.DB.prepare(
    `SELECT * FROM places WHERE id IN (${unique.map(() => "?").join(",")})`,
  ).bind(...unique).all<PlaceRow>();
  const byId = new Map(rows.results.map((row) => [row.id, row]));
  return ids.flatMap((id) => byId.get(id) ?? []);
}

/** The place JSON every endpoint returns. */
export async function placeOutputs(env: Env, rows: PlaceRow[]) {
  const grades = await loadGrades(env, rows.map((row) => row.id));
  return rows.map((row) => ({
    id: row.id,
    osm_ref: row.osm_ref,
    name: row.name,
    category: row.category,
    lat: row.lat,
    lng: row.lng,
    address: row.address,
    phone: row.phone,
    website: row.website,
    opening_hours: row.opening_hours,
    osm_wheelchair: row.osm_wheelchair,
    grade: grades.get(row.id) ?? [],
  }));
}

function coordinate(url: URL, name: string, required: boolean): number | null {
  const raw = url.searchParams.get(name);
  if (raw === null || raw === "") {
    if (required) throw new HttpError(400, `${name} is required.`);
    return null;
  }
  const value = Number(raw);
  const limit = name === "lat" ? 90 : 180;
  if (!Number.isFinite(value) || Math.abs(value) > limit) throw new HttpError(400, `${name} is invalid.`);
  return value;
}

function boundingBox(lat: number, lng: number, radiusMeters: number) {
  const dLat = radiusMeters / 111_320;
  const dLng = dLat / Math.max(Math.cos((lat * Math.PI) / 180), 0.01);
  return [lat - dLat, lat + dLat, lng - dLng, lng + dLng] as const;
}

/** Squared equirectangular distance: fine for ordering places a few km apart. */
const DISTANCE_ORDER = `((lat - ?1) * (lat - ?1) + (lng - ?2) * (lng - ?2) * ?3)`;

export async function handleNearby(request: Request, env: Env, url: URL): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const lat = coordinate(url, "lat", true)!;
  const lng = coordinate(url, "lng", true)!;
  const radius = Math.min(Math.max(Number(url.searchParams.get("radius") ?? DEFAULT_RADIUS) || DEFAULT_RADIUS, 500), MAX_RADIUS);
  const [south, north, west, east] = boundingBox(lat, lng, radius);
  const cosLat = Math.cos((lat * Math.PI) / 180) ** 2;
  const rows = await env.DB.prepare(
    `SELECT * FROM places
     WHERE lat BETWEEN ?4 AND ?5 AND lng BETWEEN ?6 AND ?7
     ORDER BY ${DISTANCE_ORDER}
     LIMIT 80`,
  ).bind(lat, lng, cosLat, south, north, west, east).all<PlaceRow>();
  return json({ status: "ok", places: await placeOutputs(env, rows.results), attribution: OSM_ATTRIBUTION });
}

/** Turns user input into a safe FTS5 prefix query: "bali gal" -> "bali"* "gal"* */
export function ftsQuery(input: string): string | null {
  const terms = input.toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? [];
  return terms.length ? terms.slice(0, 8).map((term) => `"${term}"*`).join(" ") : null;
}

export async function handleSearch(request: Request, env: Env, url: URL): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const query = url.searchParams.get("q")?.trim() ?? "";
  if (query.length < 2 || query.length > 200) throw new HttpError(400, "q must be 2–200 characters.");
  const match = ftsQuery(query);
  if (!match) return json({ status: "ok", places: [], attribution: OSM_ATTRIBUTION });
  const lat = coordinate(url, "lat", false);
  const lng = coordinate(url, "lng", false);
  // Text relevance first; among equally good matches, the nearer place wins.
  const nearFirst = lat !== null && lng !== null;
  const rows = await env.DB.prepare(
    `SELECT p.* FROM places_fts f JOIN places p ON p.seq = f.rowid
     WHERE places_fts MATCH ?4
     ORDER BY round(bm25(places_fts), 1)${nearFirst ? `, ${DISTANCE_ORDER}` : ""}
     LIMIT 25`,
  ).bind(lat ?? 0, lng ?? 0, nearFirst ? Math.cos((lat! * Math.PI) / 180) ** 2 : 1, match).all<PlaceRow>();
  return json({ status: "ok", places: await placeOutputs(env, rows.results), attribution: OSM_ATTRIBUTION });
}

export async function handleSavedPlaces(
  request: Request,
  env: Env,
  auth: Auth,
  encodedPlaceKey?: string,
): Promise<Response> {
  const userId = await requireUserId(auth, request);
  if (!encodedPlaceKey) {
    if (request.method !== "GET") return methodNotAllowed("GET");
    const saved = await env.DB.prepare(
      `SELECT place_id FROM saved_places WHERE user_id = ? ORDER BY created_at DESC`,
    ).bind(userId).all<{ place_id: string }>();
    const ids = saved.results.map((row) => row.place_id);
    return json({ place_ids: ids, places: await placeOutputs(env, await placeRows(env, ids)) });
  }

  const placeId = await requirePlaceId(env, encodedPlaceKey);
  if (request.method === "PUT") {
    await env.DB.prepare(`INSERT OR IGNORE INTO saved_places (user_id, place_id) VALUES (?, ?)`)
      .bind(userId, placeId).run();
    return new Response(null, { status: 204 });
  }
  if (request.method === "DELETE") {
    await env.DB.prepare(`DELETE FROM saved_places WHERE user_id = ? AND place_id = ?`)
      .bind(userId, placeId).run();
    return new Response(null, { status: 204 });
  }
  return methodNotAllowed("PUT", "DELETE");
}

export async function handlePlace(
  request: Request,
  env: Env,
  encodedPlaceKey: string,
  resource: string | undefined,
): Promise<Response> {
  if (request.method !== "GET") return methodNotAllowed("GET");
  const placeId = await requirePlaceId(env, encodedPlaceKey);
  switch (resource) {
    case undefined: {
      const [place] = await placeOutputs(env, await placeRows(env, [placeId]));
      return json({ status: "ok", place });
    }
    case "accessibility": {
      const [place] = await placeOutputs(env, await placeRows(env, [placeId]));
      return json({ status: "ok", place, grade: place?.grade ?? [] });
    }
    case "photos":
      return placePhotos(env, placeId);
    default:
      throw new HttpError(404, "Place route not found.");
  }
}

export async function loadGrade(env: Env, placeId: string): Promise<FeatureGrade[]> {
  return (await loadGrades(env, [placeId])).get(placeId) ?? [];
}

export async function loadGrades(env: Env, placeIds: string[]): Promise<Map<string, FeatureGrade[]>> {
  const unique = [...new Set(placeIds)];
  const grades = new Map<string, FeatureGrade[]>();
  if (!unique.length) return grades;
  const rows = await env.DB.prepare(
    `SELECT place_id, feature, value, COUNT(*) AS count
     FROM accessibility_signals
     WHERE place_id IN (${unique.map(() => "?").join(",")})
     GROUP BY place_id, feature, value`,
  ).bind(...unique).all<SignalCount>();

  const byPlaceFeature = new Map<string, SignalCount[]>();
  for (const row of rows.results) {
    const key = `${row.place_id}\u0000${row.feature}`;
    const values = byPlaceFeature.get(key) ?? [];
    values.push(row);
    byPlaceFeature.set(key, values);
  }
  const severity: Record<SignalCount["value"], number> = { yes: 0, limited: 1, no: 2 };
  for (const values of byPlaceFeature.values()) {
    const sorted = [...values].sort((a, b) => b.count - a.count || severity[b.value] - severity[a.value]);
    const total = values.reduce((sum, item) => sum + item.count, 0);
    const top = sorted[0]!;
    const list = grades.get(top.place_id) ?? [];
    list.push({ feature: top.feature, best_value: top.value, confidence: top.count / total });
    grades.set(top.place_id, list);
  }
  return grades;
}

async function placePhotos(env: Env, placeId: string): Promise<Response> {
  const rows = await env.DB.prepare(
    `SELECT id, object_key, credit, sort_order
     FROM place_photos WHERE place_id = ? ORDER BY sort_order, created_at`,
  ).bind(placeId).all<{ id: string; object_key: string; credit: string | null; sort_order: number }>();
  return json(rows.results.map((row) => ({
    id: row.id,
    url: `${env.API_BASE_URL}/v1/media/${row.object_key}`,
    source: "community",
    credit: row.credit,
    sort_order: row.sort_order,
  })));
}
