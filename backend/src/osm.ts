/**
 * Where our places come from. Only the weekly sync (sync.ts) calls this; user
 * requests are answered from D1 and never wait on an outside service.
 *
 * The source is one Overpass query per region per sync. Swap fetchRegionPlaces
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

/** Which OSM features become Rollspot places. Widen this as the app covers more than malls. */
export const PLACE_FILTER = `["shop"~"^(mall|department_store)$"]["name"]`;

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
      category: tag(tags, "shop", "amenity", "tourism", "leisure"),
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

export async function fetchRegionPlaces(box: BoundingBox): Promise<OsmPlace[]> {
  const query = `[out:json][timeout:120];
nwr${PLACE_FILTER}(${box.south},${box.west},${box.north},${box.east});
out center tags;`;
  const response = await fetch(OVERPASS_URL, {
    method: "POST",
    headers: { "user-agent": USER_AGENT, "content-type": "application/x-www-form-urlencoded" },
    body: `data=${encodeURIComponent(query)}`,
  });
  if (!response.ok) throw new Error(`Overpass returned ${response.status}.`);
  return parseOverpass(await response.json());
}
