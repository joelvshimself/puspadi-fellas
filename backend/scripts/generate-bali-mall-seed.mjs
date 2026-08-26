#!/usr/bin/env node
//
// Renders bali-mall-seed.template.sql with the contents of
// ../seed/bali-malls.json into the migration that actually gets pushed.
//
//   node backend/scripts/generate-bali-mall-seed.mjs
//
// The migration filename is fixed rather than timestamped-per-run: re-running
// this must UPDATE the seed migration, not add a second one. A stack of
// near-identical seed migrations is how a schema history becomes unreadable,
// and the file is idempotent (upserts + on-conflict), so re-pushing the same
// name is the correct behaviour.

import { readFile, writeFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED_FILE = join(HERE, "..", "seed", "bali-malls.json");
const TEMPLATE_FILE = join(HERE, "bali-mall-seed.template.sql");
const OUT_FILE = join(
  HERE,
  "..",
  "supabase",
  "migrations",
  "20260826091000_bali_mall_seed.sql",
);

const doc = JSON.parse(await readFile(SEED_FILE, "utf8"));
const template = await readFile(TEMPLATE_FILE, "utf8");

const malls = doc.malls ?? [];
if (malls.length === 0) {
  console.error(`${SEED_FILE} contains no malls — run fetch-bali-malls.mjs first`);
  process.exit(1);
}

// Only what the SQL reads. `dropped` is a review aid in the JSON file and has
// no business in the database; `generated_at` would make every regeneration
// dirty the migration even when the data is identical.
const payload = {
  attribution: doc.attribution,
  source: doc.source,
  license: doc.license,
  malls: malls.map((m) => ({
    place_id: m.place_id,
    osm_id: m.osm_id,
    name: m.name,
    lat: m.lat,
    lng: m.lng,
    address: m.address,
    city: m.city,
    postcode: m.postcode,
    phone: m.phone,
    website: m.website,
    opening_hours: m.opening_hours,
    levels: m.levels,
    category: m.category,
    osm_accessibility: m.osm_accessibility,
    aliases: m.aliases,
  })),
};

const json = JSON.stringify(payload, null, 2);

// The literal is delimited by $seed$. A dollar-quoted string cannot contain
// its own delimiter, and nothing else needs escaping inside one — but a mall
// named "$seed$" would end the literal early and turn the rest of the file
// into syntax errors, so refuse rather than emit something broken.
if (json.includes("$seed$")) {
  console.error("Seed JSON contains the dollar-quote delimiter $seed$ — aborting");
  process.exit(1);
}

const aliasCount = malls.reduce((n, m) => n + (m.aliases?.length ?? 0) + 1, 0);

const sql = template
  .replaceAll("@@GENERATED_AT@@", doc.generated_at ?? "unknown")
  .replaceAll("@@MALL_COUNT@@", String(malls.length))
  .replaceAll("@@ALIAS_COUNT@@", String(aliasCount))
  .replace("@@SEED_JSON@@", json);

await writeFile(OUT_FILE, sql);
console.log(`Wrote ${OUT_FILE}`);
console.log(`  ${malls.length} mall(s), ${aliasCount} alias(es), ${sql.length} bytes of SQL`);
