#!/usr/bin/env node
//
// Downloads the south-Bali shopping-mall directory from OpenStreetMap and
// writes it to ../seed/bali-malls.json, which generate-bali-mall-seed.mjs
// turns into a migration.
//
//   node backend/scripts/fetch-bali-malls.mjs
//
// WHY OSM AND NOT GOOGLE
// ----------------------
// Google Places' terms permit caching a place ID and little else — storing
// their names, addresses and hours in our own table and serving them to our
// own clients is exactly what they forbid, and it is the dependency
// 20260812223213_osm_primary_google_optional.sql deliberately walked away
// from. OSM is ODbL: we may store it, redistribute it and build on it, as
// long as the attribution in ATTRIBUTION below travels with it. Google stays
// where it already is — live enrichment behind place-accessibility, never a
// stored dataset.
//
// WHAT OSM ACTUALLY HAS
// ---------------------
// Names, coordinates, addresses, phone, opening hours and floor counts for
// essentially every mall in the region. Accessibility, almost nothing: of the
// 45 raw hits, 4 carry `wheelchair` and 2 carry `toilets:wheelchair`. That is
// the point of the app, not a gap in the seed — this file supplies the places,
// the community supplies the accessibility.

import { writeFile, readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED_DIR = join(HERE, "..", "seed");
const OUT_FILE = join(SEED_DIR, "bali-malls.json");
const ALIAS_FILE = join(SEED_DIR, "bali-mall-aliases.json");

const OVERPASS_ENDPOINTS = [
  "https://overpass-api.de/api/interpreter",
  "https://overpass.kumi.systems/api/interpreter",
];

/// South Bali: Canggu/Seminyak down through Kuta and Jimbaran to Nusa Dua,
/// east to Denpasar and Sanur. Kuta is the centre of gravity the brief asked
/// for; the box is wider because a Kuta user's map pans well past Kuta.
const BBOX = { south: -8.87, west: 115.08, north: -8.58, east: 115.32 };

/// Kuta Beach, the reference point every record is ranked against.
const KUTA = { lat: -8.7175, lng: 115.1686 };

const ATTRIBUTION = "© OpenStreetMap contributors (ODbL)";

/// Overpass's usage policy asks callers to identify themselves.
const USER_AGENT =
  "puspadi-fellas-mall-seed/1.0 (github.com/joelvshimself/puspadi-fellas)";

/// Tags OSM uses for the accessibility half of a place. Copied into
/// place_cache.osm_accessibility in the same shape overpassWheelchairTag()
/// writes in place-accessibility, so a seeded row and an enriched one are
/// indistinguishable downstream.
const ACCESSIBILITY_TAGS = [
  "wheelchair",
  "wheelchair:description",
  "toilets:wheelchair",
  "entrance",
  "highway",
  "ramp",
  "ramp:wheelchair",
  "handrail",
  "elevator",
  "lift",
  "automatic_door",
  "tactile_paving",
  "parking:disabled",
  "capacity:disabled",
];

/// Excluded by hand, with the reason, rather than by a cleverer filter.
/// `shop=mall` and `shop=department_store` are mapped loosely in Indonesia —
/// souvenir warehouses, a hotel, a kitchenware shop and one mis-tagged alley
/// all carry them. A rule tight enough to drop these also dropped real malls
/// (Park23 has no addr:*, Seminyak Square no building), so the judgement is
/// written down here where it can be reviewed and argued with.
const EXCLUDED = {
  "Harrads Hotel": "hotel, mis-tagged shop=mall",
  "Dapur Prima": "kitchenware shop, not a mall",
  "Dapur Prima(kitchen accessoires)": "kitchenware shop, not a mall",
  "Dod meets Pop": "clothing boutique",
  "Oakley Vault": "single-brand outlet store",
  "Чесночный переулок-магазины.": "mis-tagged market alley, name is not a venue",
  "GM Discovery Shopping Mall Room": "a room inside Discovery Mall, not a venue",
  "Krishna Pusat Oleh Oleh (24 Hours)": "souvenir warehouse, not a mall",
  "Krisna Oleh-Oleh (Bali Bypass)": "souvenir warehouse, not a mall",
  "The Find": "concept store in Pererenan, bare node with no supporting tags",
  "Bandung Collection": "clothing shop",
  "Darma": "unclear single shop, no supporting tags",
  "Palmbay Bali": "beach club, mis-tagged",
  "Robinson": "department-store tenant inside another mall",
  "Matahari Department Store": "department-store tenant inside another mall",
  "Centro Department Store": "department-store tenant inside Discovery Mall",
  "Center of Kuta": "shophouse row, not a mall",
  "The Keranjang": "souvenir centre, not a mall",
  "Jimbaran Corner": "small shophouse block",
  "Transmart": "supermarket anchor tenant of Trans Studio Mall",
  "Rimo Trade Center": "defunct — building vacant since 2019",
};

const QUERY = `[out:json][timeout:90];
(
  nwr["shop"="mall"](${BBOX.south},${BBOX.west},${BBOX.north},${BBOX.east});
  nwr["shop"="department_store"](${BBOX.south},${BBOX.west},${BBOX.north},${BBOX.east});
  nwr["building"="retail"]["name"~"[Mm]all|[Pp]laza"](${BBOX.south},${BBOX.west},${BBOX.north},${BBOX.east});
);
out center tags;`;

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function main() {
  const elements = await overpass(QUERY);
  console.log(`Overpass returned ${elements.length} element(s)`);

  const aliasFile = JSON.parse(await readFile(ALIAS_FILE, "utf8"));

  const kept = [];
  const dropped = [];
  for (const el of elements) {
    const tags = el.tags ?? {};
    const name = (tags.name ?? "").trim();
    if (!name) {
      dropped.push({ name: "(unnamed)", reason: "no name tag" });
      continue;
    }
    if (EXCLUDED[name]) {
      dropped.push({ name, reason: EXCLUDED[name] });
      continue;
    }
    const lat = el.lat ?? el.center?.lat;
    const lng = el.lon ?? el.center?.lon;
    if (typeof lat !== "number" || typeof lng !== "number") {
      dropped.push({ name, reason: "no coordinate" });
      continue;
    }
    kept.push(toMall(el, tags, name, lat, lng));
  }

  const aliasMap = aliasFile.aliases ?? {};
  const malls = attachAliases(dedupe(kept, aliasIndex(aliasMap)), aliasMap);
  malls.sort((a, b) => a.distance_from_kuta_m - b.distance_from_kuta_m);

  const doc = {
    generated_at: new Date().toISOString(),
    generated_by: "backend/scripts/fetch-bali-malls.mjs",
    source: "OpenStreetMap via the Overpass API",
    license: "ODbL 1.0",
    attribution: ATTRIBUTION,
    bbox: BBOX,
    reference_point: { name: "Kuta Beach", ...KUTA },
    counts: { returned: elements.length, kept: malls.length, dropped: dropped.length },
    dropped,
    malls,
  };

  await writeFile(OUT_FILE, JSON.stringify(doc, null, 2) + "\n");
  console.log(`Wrote ${malls.length} mall(s) to ${OUT_FILE} (${dropped.length} dropped)`);
  for (const m of malls) {
    const acc = Object.keys(m.osm_accessibility).length;
    console.log(
      `  ${(m.distance_from_kuta_m / 1000).toFixed(1).padStart(5)}km  ${m.name.padEnd(30)} ` +
        `${m.place_id.padEnd(24)} ${acc ? `${acc} a11y tag(s)` : "-"}`,
    );
  }
}

function toMall(el, tags, name, lat, lng) {
  const osmAccessibility = {};
  for (const key of ACCESSIBILITY_TAGS) {
    if (tags[key] != null) osmAccessibility[key] = tags[key];
  }

  return {
    place_id: canonicalPlaceId(lat, lng),
    osm_id: `${el.type}/${el.id}`,
    name,
    lat: round(lat, 6),
    lng: round(lng, 6),
    // Kept as one display line, matching what shortAddress() builds from a
    // MapKit placemark on the client — the two have to look alike in a list.
    address: [tags["addr:housenumber"] && tags["addr:street"]
      ? `${tags["addr:street"]} ${tags["addr:housenumber"]}`
      : tags["addr:street"], tags["addr:city"]]
      .filter(Boolean)
      .join(", ") || null,
    city: tags["addr:city"] ?? null,
    postcode: tags["addr:postcode"] ?? null,
    phone: tags.phone ?? tags["contact:phone"] ?? null,
    website: tags.website ?? tags["contact:website"] ?? null,
    opening_hours: tags.opening_hours ?? null,
    levels: tags["building:levels"] ? Number(tags["building:levels"]) : null,
    category: tags.shop === "department_store" ? "DepartmentStore" : "Mall",
    osm_accessibility: osmAccessibility,
    distance_from_kuta_m: Math.round(haversine(lat, lng, KUTA.lat, KUTA.lng)),
    aliases: [],
  };
}

/// Maps every known spelling of a venue -- the canonical name and each of its
/// aliases -- onto one key, so two records that OSM spells differently are
/// recognised as the same place.
function aliasIndex(aliasMap) {
  const index = new Map();
  for (const [canonical, aliases] of Object.entries(aliasMap)) {
    const key = normalizeName(canonical);
    index.set(key, { key, name: canonical });
    for (const alias of aliases) {
      index.set(normalizeName(alias), { key, name: canonical });
    }
  }
  return index;
}

/// OSM maps one venue more than once — an outline way plus a node, or two
/// spellings of the same name. "Mall Bali Galeria" and "Mal Bali Galeria" sit
/// 60m apart in this dataset and are one mall; "Seminyak Square" and "Seminyak
/// Village" sit 60m apart and are two. Distance alone cannot tell them apart,
/// so the merge asks the alias file, which is the only place that knows. The
/// remaining rule is resolve_place_id's: punctuation-insensitive name equality
/// within a radius. Richest record wins so the survivor keeps the most tags.
function dedupe(malls, index) {
  const ranked = [...malls].sort((a, b) => richness(b) - richness(a));
  const winners = [];
  for (const mall of ranked) {
    const key = index.get(normalizeName(mall.name))?.key ?? normalizeName(mall.name);
    const existing = winners.find(
      (w) =>
        (index.get(normalizeName(w.name))?.key ?? normalizeName(w.name)) === key &&
        haversine(w.lat, w.lng, mall.lat, mall.lng) <= 250,
    );
    if (existing) {
      // Never lose a tag to a merge.
      for (const [k, v] of Object.entries(mall.osm_accessibility)) {
        existing.osm_accessibility[k] ??= v;
      }
      for (const key of ["address", "city", "postcode", "phone", "website", "opening_hours", "levels"]) {
        existing[key] ??= mall[key];
      }
      continue;
    }
    // The canonical spelling is the one the alias file (and therefore
    // place_aliases) is keyed on — a survivor keeping OSM's variant spelling
    // would leave its own canonical name unmapped.
    const canonical = index.get(normalizeName(mall.name))?.name;
    if (canonical) mall.name = canonical;
    winners.push(mall);
  }
  return winners;
}

function richness(mall) {
  return (
    Object.keys(mall.osm_accessibility).length * 4 +
    (mall.address ? 2 : 0) +
    (mall.phone ? 1 : 0) +
    (mall.website ? 1 : 0) +
    (mall.opening_hours ? 1 : 0)
  );
}

/// The names MapKit hands the iOS client are not the names OSM stores —
/// "Beachwalk Bali" against "Beachwalk Shopping Center", "Park23" against
/// "Park 23 Mall". resolve_place_id matches names exactly, so without these
/// the client mints a duplicate row next to the seeded one and the seed is
/// wasted. bali-mall-aliases.json is where the observed variants live.
function attachAliases(malls, aliasMap) {
  for (const mall of malls) {
    const entry = aliasMap[mall.name];
    if (!entry) continue;
    // Deduped on the NORMALISED form, not the literal string: "Park23 Mall"
    // and "Park 23 Mall" are two spellings of one alias, and place_aliases is
    // keyed on the normalised one. Emitting both would collide on insert.
    const seen = new Set([normalizeName(mall.name)]);
    mall.aliases = entry.filter((a) => {
      const key = normalizeName(a);
      if (key === "" || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }
  const unmatched = Object.keys(aliasMap).filter((k) => !malls.some((m) => m.name === k));
  if (unmatched.length > 0) {
    console.warn(
      `WARNING: ${unmatched.length} alias entr(ies) match no mall in this run — ` +
        `OSM may have been renamed: ${unmatched.join(", ")}`,
    );
  }
  return malls;
}

async function overpass(query) {
  let lastError;
  for (const endpoint of OVERPASS_ENDPOINTS) {
    try {
      const res = await fetch(endpoint, {
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Accept": "application/json",
          // Same lesson as overpassWheelchairTag() in place-accessibility:
          // without a descriptive User-Agent the public instance answers 406
          // Not Acceptable, regardless of load.
          "User-Agent": USER_AGENT,
        },
        body: `data=${encodeURIComponent(query)}`,
      });
      if (!res.ok) throw new Error(`${endpoint} -> HTTP ${res.status}`);
      const text = await res.text();
      // Overpass answers "server too busy" with a 200 and an HTML body.
      if (!text.trimStart().startsWith("{")) {
        throw new Error(`${endpoint} -> non-JSON body (rate limited?)`);
      }
      return JSON.parse(text).elements ?? [];
    } catch (err) {
      console.warn(`  ${err.message}; trying next endpoint`);
      lastError = err;
    }
  }
  throw lastError ?? new Error("no Overpass endpoint answered");
}

/// Must agree with canonicalPlaceId() in place-accessibility/index.ts and
/// PlaceCacheStore.key on the client — 4 decimals, ~11m.
function canonicalPlaceId(lat, lng) {
  return `loc_${lat.toFixed(4)}_${lng.toFixed(4)}`;
}

/// Same normalisation as resolve_place_id's regexp_replace + lower.
function normalizeName(name) {
  return name.toLowerCase().replace(/[^a-z0-9]+/g, "");
}

function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371000;
  const toRad = (d) => (d * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(a));
}

function round(n, places) {
  const f = 10 ** places;
  return Math.round(n * f) / f;
}
