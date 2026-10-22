/**
 * Where our places come from. Only the weekly sync (sync.ts) calls this; user
 * requests are answered from D1 and never wait on an outside service.
 *
 * The source is one Overpass query per sync tile. Swap fetchTilePlaces
 * for another source (an uploaded extract, a paid provider) without touching
 * anything else: everything downstream only sees OsmPlace.
 */

export interface OsmPlace {
  osmRef: string;
  name: string;
  category: string | null;
  lat: number;
  lng: number;
  address: string | null;
  phone: string | null;
  website: string | null;
  openingHours: string | null;
  wheelchair: "yes" | "limited" | "no" | null;
}

export interface BoundingBox {
  south: number;
  west: number;
  north: number;
  east: number;
}

const USER_AGENT = "Rollspot/1.1 places sync (https://rollspot.app; hello@rollspot.app)";
const OVERPASS_URL = "https://overpass-api.de/api/interpreter";
const OSM_REF = /^(node|way|relation)\/\d+$/;

/**
 * Which OSM features become Rollspot places: named places people go to. Street
 * furniture (benches, bins, ATMs, parking) stays out; it would bury search.
 */
const PLACE_STATEMENTS = [
  `nwr["shop"]["name"]`,
  `nwr["amenity"~"^(restaurant|cafe|fast_food|food_court|bar|pub|biergarten|ice_cream|nightclub|` +
    `bank|pharmacy|hospital|clinic|doctors|dentist|veterinary|` +
    `library|cinema|theatre|arts_centre|community_centre|events_venue|conference_centre|exhibition_centre|` +
    `townhall|courthouse|police|post_office|embassy|social_facility|place_of_worship|marketplace|` +
    `university|college|school|kindergarten|bus_station|ferry_terminal)$"]["name"]`,
  `nwr["tourism"~"^(hotel|hostel|guest_house|motel|apartment|museum|gallery|attraction|zoo|aquarium|theme_park|viewpoint)$"]["name"]`,
  `nwr["leisure"~"^(park|garden|sports_centre|stadium|swimming_pool|fitness_centre|water_park|beach_resort)$"]["name"]`,
  `nwr["healthcare"]["name"]`,
  `nwr["railway"="station"]["name"]`,
  `nwr["aeroway"="aerodrome"]["iata"]["name"]`,
];

/** A tile whose answer is bigger than this is split instead of parsed (Workers have 128 MB). */
const MAX_RESPONSE_BYTES = 16 * 1024 * 1024;

export function isOsmRef(value: string): boolean {
  return OSM_REF.test(value);
}

function tag(tags: Record<string, string>, ...keys: string[]): string | null {
  for (const key of keys) {
    const value = tags[key]?.trim();
    if (value) return value;
  }
  return null;
}

function wheelchair(value: string | null): OsmPlace["wheelchair"] {
  return value === "yes" || value === "limited" || value === "no" ? value : null;
}

interface OverpassElement {
  type: "node" | "way" | "relation";
  id: number;
  lat?: number;
  lon?: number;
  center?: { lat: number; lon: number };
  tags?: Record<string, string>;
}

export function parseOverpass(body: { elements?: OverpassElement[] }): OsmPlace[] {
  return (body.elements ?? []).flatMap((element) => {
    const tags = element.tags ?? {};
    const name = tag(tags, "name:en", "name");
    const lat = element.lat ?? element.center?.lat;
    const lng = element.lon ?? element.center?.lon;
    if (!name || lat === undefined || lng === undefined) return [];
    const street = [tag(tags, "addr:housenumber"), tag(tags, "addr:street")].filter(Boolean).join(" ");
    const address = [street, tag(tags, "addr:city", "addr:place")].filter(Boolean).join(", ");
    return [{
      osmRef: `${element.type}/${element.id}`,
      name,
      category: tag(tags, "shop", "amenity", "tourism", "leisure", "healthcare", "railway", "aeroway"),
      lat,
      lng,
      address: address || null,
      phone: tag(tags, "phone", "contact:phone"),
      website: tag(tags, "website", "contact:website"),
      openingHours: tag(tags, "opening_hours"),
      wheelchair: wheelchair(tag(tags, "wheelchair")),
    }];
  });
}

/** Overpass is busy or rate-limiting us: stop this run and try the tile again later. */
export class OverpassBusyError extends Error {}

export type TileResult = { kind: "ok"; places: OsmPlace[] } | { kind: "too_big" };

export function placeQuery(box: BoundingBox): string {
  return `[out:json][timeout:180][bbox:${box.south},${box.west},${box.north},${box.east}];
(
${PLACE_STATEMENTS.map((statement) => `  ${statement};`).join("\n")}
);
out center tags;`;
}

export async function fetchTilePlaces(box: BoundingBox): Promise<TileResult> {
  const response = await fetch(OVERPASS_URL, {
    method: "POST",
    headers: { "user-agent": USER_AGENT, "content-type": "application/x-www-form-urlencoded" },
    body: `data=${encodeURIComponent(placeQuery(box))}`,
  });
  if ([429, 502, 503, 504].includes(response.status)) {
    throw new OverpassBusyError(`Overpass returned ${response.status}.`);
  }
  if (!response.ok) throw new Error(`Overpass returned ${response.status}.`);
  const text = await readCapped(response, MAX_RESPONSE_BYTES);
  if (text === null) return { kind: "too_big" };
  const body = JSON.parse(text) as { elements?: OverpassElement[]; remark?: string };
  // Overpass reports a query that ran out of time or memory in `remark`, with partial data.
  if (body.remark && /runtime (error|remark)/i.test(body.remark)) {
    if (/timed out|out of memory/i.test(body.remark)) return { kind: "too_big" };
    throw new Error(body.remark);
  }
  return { kind: "ok", places: parseOverpass(body) };
}

/** The body as text, or null once it passes maxBytes (the rest is not downloaded). */
async function readCapped(response: Response, maxBytes: number): Promise<string | null> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}
