import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, uuid } from "./http";
import { fetchRegionPlaces, type OsmPlace } from "./osm";

interface RegionRow {
  id: string;
  name: string;
  south: number;
  west: number;
  north: number;
  east: number;
}

/** Inserts or refreshes places by OSM ref. Rollspot IDs never change, so reviews stay attached. */
export async function upsertPlaces(env: Env, places: OsmPlace[]): Promise<void> {
  const unique = [...new Map(places.map((place) => [place.osmRef, place])).values()];
  // D1 caps a batch; 50 statements keeps each round trip small.
  for (let start = 0; start < unique.length; start += 50) {
    await env.DB.batch(unique.slice(start, start + 50).map((place) => env.DB.prepare(
      `INSERT INTO places (id, osm_ref, name, category, lat, lng, address, phone, website, opening_hours, osm_wheelchair)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(osm_ref) DO UPDATE SET
         name = excluded.name,
         category = excluded.category,
         lat = excluded.lat,
         lng = excluded.lng,
         address = excluded.address,
         phone = excluded.phone,
         website = excluded.website,
         opening_hours = excluded.opening_hours,
         osm_wheelchair = excluded.osm_wheelchair,
         updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`,
    ).bind(
      uuid(), place.osmRef, place.name, place.category, place.lat, place.lng,
      place.address, place.phone, place.website, place.openingHours, place.wheelchair,
    )));
  }
}

/**
 * Refreshes every region from OSM. Places that disappear from OSM are kept:
 * they may carry reviews, and a mall rarely vanishes between two syncs.
 */
export async function syncAllRegions(env: Env): Promise<Array<{ region: string; places?: number; error?: string }>> {
  const regions = await env.DB.prepare(`SELECT id, name, south, west, north, east FROM sync_regions`).all<RegionRow>();
  const results = [];
  for (const region of regions.results) {
    try {
      const places = await fetchRegionPlaces(region);
      await upsertPlaces(env, places);
      await env.DB.prepare(
        `UPDATE sync_regions SET last_synced_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now'),
         last_status = ?, last_count = ? WHERE id = ?`,
      ).bind("ok", places.length, region.id).run();
      results.push({ region: region.name, places: places.length });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`Place sync failed for ${region.name}`, error);
      await env.DB.prepare(`UPDATE sync_regions SET last_status = ? WHERE id = ?`).bind(message, region.id).run();
      results.push({ region: region.name, error: message });
    }
  }
  return results;
}

/** Manual trigger for the first load and for local development: POST /v1/admin/sync-places. */
export async function handleAdminSync(request: Request, env: Env): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  const token = request.headers.get("authorization")?.replace(/^Bearer /, "");
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) throw new HttpError(401, "Admin token required.");
  return json({ status: "ok", regions: await syncAllRegions(env) });
}
