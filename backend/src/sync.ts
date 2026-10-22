import type { Env } from "./env";
import { HttpError, json, methodNotAllowed, uuid } from "./http";
import { fetchTilePlaces, OverpassBusyError, type BoundingBox, type OsmPlace } from "./osm";

interface RegionRow extends BoundingBox {
  id: string;
}

interface TileRow extends BoundingBox {
  id: string;
  region_id: string;
  last_count: number | null;
}

/** Regions are cut into tiles this many degrees wide; busy tiles split further. */
const TILE_DEGREES = 1;
/** Below this a tile isn't split again (about 1 km); it is recorded as an error instead. */
const MIN_TILE_DEGREES = 0.01;
/** Tiles per cron run. Runs every 10 minutes, so ~1,400 queries a day at most: inside Overpass's fair-use guidance. */
const TILES_PER_RUN = 10;
/** Pause between Overpass queries, to stay a polite user of a shared service. */
const PAUSE_MS = 2_000;
const RESYNC_DAYS = 7;
/** Sea and empty land: check again monthly instead of weekly. */
const EMPTY_RESYNC_DAYS = 28;

const NOW = `strftime('%Y-%m-%dT%H:%M:%fZ', 'now')`;

/**
 * Inserts new places and updates changed ones by OSM ref. A place that hasn't
 * changed is left alone, so a weekly pass over a region writes (and is billed
 * for) only what changed in OpenStreetMap. Rollspot IDs never change, so
 * reviews stay attached.
 */
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
         updated_at = ${NOW}
       WHERE name IS NOT excluded.name
          OR category IS NOT excluded.category
          OR lat IS NOT excluded.lat
          OR lng IS NOT excluded.lng
          OR address IS NOT excluded.address
          OR phone IS NOT excluded.phone
          OR website IS NOT excluded.website
          OR opening_hours IS NOT excluded.opening_hours
          OR osm_wheelchair IS NOT excluded.osm_wheelchair`,
    ).bind(
      uuid(), place.osmRef, place.name, place.category, place.lat, place.lng,
      place.address, place.phone, place.website, place.openingHours, place.wheelchair,
    )));
  }
}

function tileId(regionId: string, box: BoundingBox): string {
  return `${regionId}:${box.south}:${box.west}:${box.north}:${box.east}`;
}

/** Five decimals: grid edges stay exact instead of drifting by float error. */
const round = (value: number) => Math.round(value * 100_000) / 100_000;

function tileStatement(env: Env, regionId: string, box: BoundingBox) {
  return env.DB.prepare(
    `INSERT OR IGNORE INTO sync_tiles (id, region_id, south, west, north, east) VALUES (?, ?, ?, ?, ?, ?)`,
  ).bind(tileId(regionId, box), regionId, box.south, box.west, box.north, box.east);
}

/** Cuts any active region that has no tiles yet (new, or just switched on) into a grid. */
async function seedTiles(env: Env): Promise<void> {
  const regions = await env.DB.prepare(
    `SELECT id, south, west, north, east FROM sync_regions r
     WHERE r.active = 1 AND NOT EXISTS (SELECT 1 FROM sync_tiles t WHERE t.region_id = r.id)`,
  ).all<RegionRow>();
  for (const region of regions.results) {
    const statements = [];
    for (let south = region.south; south < region.north; south += TILE_DEGREES) {
      for (let west = region.west; west < region.east; west += TILE_DEGREES) {
        const box = {
          south: round(south), west: round(west),
          north: round(Math.min(south + TILE_DEGREES, region.north)),
          east: round(Math.min(west + TILE_DEGREES, region.east)),
        };
        statements.push(tileStatement(env, region.id, box));
      }
    }
    for (let start = 0; start < statements.length; start += 50) {
      await env.DB.batch(statements.slice(start, start + 50));
    }
  }
}

/** Replaces a tile with its four quarters, all due now. */
async function splitTile(env: Env, tile: TileRow): Promise<void> {
  const midLat = round((tile.south + tile.north) / 2);
  const midLng = round((tile.west + tile.east) / 2);
  const quarters = [
    { south: tile.south, west: tile.west, north: midLat, east: midLng },
    { south: tile.south, west: midLng, north: midLat, east: tile.east },
    { south: midLat, west: tile.west, north: tile.north, east: midLng },
    { south: midLat, west: midLng, north: tile.north, east: tile.east },
  ];
  await env.DB.batch([
    env.DB.prepare(`DELETE FROM sync_tiles WHERE id = ?`).bind(tile.id),
    ...quarters.map((box) => tileStatement(env, tile.region_id, box)),
  ]);
}

async function recordTile(env: Env, tile: TileRow, status: string, count: number | null, resyncDays: number) {
  await env.DB.batch([
    env.DB.prepare(
      `UPDATE sync_tiles SET last_status = ?, last_count = COALESCE(?, last_count), last_synced_at = ${NOW},
       next_sync_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now', ?) WHERE id = ?`,
    ).bind(status, count, `+${resyncDays} days`, tile.id),
    env.DB.prepare(
      `UPDATE sync_regions SET last_synced_at = ${NOW}, last_status = ?,
       last_count = (SELECT SUM(last_count) FROM sync_tiles WHERE region_id = ?) WHERE id = ?`,
    ).bind(status, tile.region_id, tile.region_id),
  ]);
}

export interface TileOutcome {
  tile: string;
  places?: number;
  split?: boolean;
  error?: string;
}

/**
 * One cron run: syncs the tiles that are most overdue (never-synced first).
 * Each region is refreshed about weekly, spread over the week instead of in
 * one burst, so neither Overpass nor a single Worker run carries a whole region.
 */
export async function syncDueTiles(env: Env, limit = TILES_PER_RUN, regionId?: string): Promise<TileOutcome[]> {
  await seedTiles(env);
  const due = await env.DB.prepare(
    `SELECT id, region_id, south, west, north, east, last_count FROM sync_tiles
     WHERE (next_sync_at IS NULL OR next_sync_at <= ${NOW}) AND (?1 IS NULL OR region_id = ?1)
       AND region_id IN (SELECT id FROM sync_regions WHERE active = 1)
     ORDER BY next_sync_at IS NOT NULL, next_sync_at
     LIMIT ?2`,
  ).bind(regionId ?? null, limit).all<TileRow>();

  const outcomes: TileOutcome[] = [];
  for (const [index, tile] of due.results.entries()) {
    if (index > 0) await new Promise((resolve) => setTimeout(resolve, PAUSE_MS));
    try {
      const result = await fetchTilePlaces(tile);
      if (result.kind === "too_big") {
        if (tile.north - tile.south > MIN_TILE_DEGREES) {
          await splitTile(env, tile);
          outcomes.push({ tile: tile.id, split: true });
        } else {
          await recordTile(env, tile, "too many places for one tile", null, RESYNC_DAYS);
          outcomes.push({ tile: tile.id, error: "too many places for one tile" });
        }
        continue;
      }
      await upsertPlaces(env, result.places);
      const count = result.places.length;
      await recordTile(env, tile, "ok", count, count === 0 ? EMPTY_RESYNC_DAYS : RESYNC_DAYS);
      outcomes.push({ tile: tile.id, places: count });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      console.error(`Place sync failed for tile ${tile.id}`, error);
      outcomes.push({ tile: tile.id, error: message });
      // Overpass is busy: leave the rest due and stop hammering it until the next run.
      if (error instanceof OverpassBusyError) break;
      await recordTile(env, tile, message, null, 1);
    }
  }
  return outcomes;
}

/**
 * Manual trigger for the first load and for local development: POST /v1/admin/sync-places.
 * `?tiles=50` syncs more tiles than a cron run; `?region=bali` limits it to one region.
 */
export async function handleAdminSync(request: Request, env: Env): Promise<Response> {
  if (request.method !== "POST") return methodNotAllowed("POST");
  const token = request.headers.get("authorization")?.replace(/^Bearer /, "");
  if (!env.ADMIN_TOKEN || token !== env.ADMIN_TOKEN) throw new HttpError(401, "Admin token required.");
  const url = new URL(request.url);
  const tiles = Math.min(Math.max(Number(url.searchParams.get("tiles")) || TILES_PER_RUN, 1), 200);
  const region = url.searchParams.get("region") || undefined;
  return json({ status: "ok", tiles: await syncDueTiles(env, tiles, region) });
}
