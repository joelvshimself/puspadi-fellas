#!/usr/bin/env node
//
// Uploads the APPROVED photos from ../seed/mall-photos.json to Supabase
// Storage and records them in place_photos.
//
//   node backend/scripts/fetch-mall-photos.mjs     # gather candidates
//   # ...review them, set "approved": true on the real ones...
//   node backend/scripts/upload-mall-photos.mjs    # publish those
//
// Nothing with approved:false is touched. That gate is the whole point: the
// automated grab is not good enough to trust. Of the first sixteen candidates
// it collected, two were photographs of the building — the rest were clothing
// catalogues, a perfume promo, a scam warning notice and a decorative paint
// texture. Uploading unreviewed output would put a picture of somebody's
// sneakers on a mall's page.
//
// Idempotent: re-running upserts on (place_id, url), so an approved photo that
// is already live is left alone rather than duplicated.

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED_DIR = join(HERE, "..", "seed");
const MANIFEST = join(SEED_DIR, "mall-photos.json");
const BUCKET = "place-photos";

const env = await readEnv(join(HERE, "..", ".env"));
const SUPABASE_URL = env.SUPABASE_URL?.replace(/\/$/, "");
const SERVICE_ROLE_KEY = env.SUPABASE_SERVICE_ROLE_KEY;
if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error("SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY must be set in backend/.env");
  process.exit(1);
}

const manifest = JSON.parse(await readFile(MANIFEST, "utf8"));
const approved = (manifest.photos ?? []).filter((p) => p.approved);

if (approved.length === 0) {
  console.log("Nothing approved in the manifest — nothing to upload.");
  process.exit(0);
}
console.log(`${approved.length} approved photo(s) of ${manifest.photos.length} candidate(s)\n`);

let uploaded = 0;
for (const [index, photo] of approved.entries()) {
  process.stdout.write(`${photo.name.padEnd(24)} `);
  try {
    const bytes = await readFile(join(SEED_DIR, "mall-photos", photo.file));
    const ext = photo.file.split(".").pop();
    // The place_id in the path makes an orphaned object traceable back to a
    // place even if the row is gone.
    const objectPath = `${photo.place_id}/${index}.${ext}`;

    const put = await fetch(`${SUPABASE_URL}/storage/v1/object/${BUCKET}/${objectPath}`, {
      method: "POST",
      headers: {
        Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
        "Content-Type": photo.content_type,
        // Overwrite rather than fail when the object is already there.
        "x-upsert": "true",
      },
      body: bytes,
    });
    if (!put.ok) throw new Error(`storage ${put.status}: ${(await put.text()).slice(0, 160)}`);

    const publicURL = `${SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${objectPath}`;

    const row = {
      place_id: photo.place_id,
      url: publicURL,
      source: "official_website",
      source_page: photo.source_page,
      credit: photo.credit,
      width: photo.width,
      height: photo.height,
      sort_order: index,
    };
    const insert = await fetch(
      `${SUPABASE_URL}/rest/v1/place_photos?on_conflict=place_id,url`,
      {
        method: "POST",
        headers: {
          apikey: SERVICE_ROLE_KEY,
          Authorization: `Bearer ${SERVICE_ROLE_KEY}`,
          "Content-Type": "application/json",
          Prefer: "resolution=merge-duplicates,return=minimal",
        },
        body: JSON.stringify(row),
      },
    );
    if (!insert.ok) throw new Error(`place_photos ${insert.status}: ${(await insert.text()).slice(0, 160)}`);

    uploaded++;
    console.log(`ok  ${publicURL}`);
  } catch (err) {
    console.log(`FAILED — ${err.message}`);
  }
}

console.log(`\n${uploaded} of ${approved.length} uploaded`);

async function readEnv(path) {
  const out = {};
  try {
    for (const line of (await readFile(path, "utf8")).split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) continue;
      const i = trimmed.indexOf("=");
      out[trimmed.slice(0, i).trim()] = trimmed.slice(i + 1).trim();
    }
  } catch { /* caller reports */ }
  return out;
}
