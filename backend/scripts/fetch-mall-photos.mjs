#!/usr/bin/env node
//
// Downloads each mall's own promotional photo from its official website and
// writes it to ../seed/mall-photos/, with a manifest recording exactly where
// every file came from.
//
//   node backend/scripts/fetch-mall-photos.mjs
//   node backend/scripts/upload-mall-photos.mjs   # then push them to Storage
//
// LICENSING — READ THIS BEFORE ADDING A SOURCE
// -------------------------------------------
// These images are NOT openly licensed the way the OSM data is. They are the
// malls' own copyrighted marketing photographs, used here to identify the
// business they depict, credited to it and linked back to it. That is a
// judgement call the project has made deliberately, not a licence we hold, and
// it is why every row records `source_page`: if a mall asks us to stop using
// its photo, the answer has to be one DELETE away, and we have to be able to
// say which image came from where without guessing.
//
// Consequences that follow from that, and should not be quietly dropped:
//   * Only the mall's OWN site is a valid source. Never a stock library, never
//     an image search, never another directory's photo of the mall.
//   * robots.txt is checked and honoured. It is not a copyright licence, but
//     ignoring it is a separate discourtesy on top of the first one.
//   * The credit travels with the image into the database and onto the screen.
//
// The openly-licensed sources stay in place and are still preferred where they
// have coverage: Mapillary (CC BY-SA) for street-level, then Apple Look Around,
// then a map snapshot.

import { writeFile, readFile, mkdir } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const HERE = dirname(fileURLToPath(import.meta.url));
const SEED_DIR = join(HERE, "..", "seed");
const OUT_DIR = join(SEED_DIR, "mall-photos");
const CANDIDATE_DIR = join(OUT_DIR, "candidates");
const MANIFEST = join(SEED_DIR, "mall-photos.json");

const USER_AGENT =
  "puspadi-fellas-photo-fetch/1.0 (accessibility directory; +github.com/joelvshimself/puspadi-fellas)";

/// Be a guest. One page per mall and a handful of images, spaced out — there
/// is no version of this that justifies hammering a small mall's web host.
const DELAY_MS = 1500;
const MAX_CANDIDATES = 8;
const MAX_BYTES = 5 * 1024 * 1024;
const MIN_BYTES = 8 * 1024; // below this it is a logo or a tracking pixel

main().catch((err) => {
  console.error(err);
  process.exit(1);
});

async function main() {
  const doc = JSON.parse(await readFile(join(SEED_DIR, "bali-malls.json"), "utf8"));
  const withSites = doc.malls.filter((m) => m.website);
  console.log(`${withSites.length} of ${doc.malls.length} malls have a website\n`);

  await mkdir(CANDIDATE_DIR, { recursive: true });

  // Whatever a human already decided stays decided — re-running the fetch must
  // not silently un-approve a photo that was checked and accepted.
  let previous = { photos: [] };
  try {
    previous = JSON.parse(await readFile(MANIFEST, "utf8"));
  } catch { /* first run */ }
  const approvedBefore = new Map(
    (previous.photos ?? []).filter((p) => p.approved).map((p) => [p.source_image, p]),
  );

  const entries = [];
  for (const mall of withSites) {
    console.log(mall.name);
    let found;
    try {
      found = await fetchCandidates(mall);
    } catch (err) {
      console.log(`  skipped — ${err.message}\n`);
      await sleep(DELAY_MS);
      continue;
    }
    for (const c of found) {
      const prior = approvedBefore.get(c.source_image);
      entries.push({ ...c, approved: prior?.approved ?? false });
      console.log(`  ${c.file.padEnd(34)} ${String(c.width) + "x" + c.height} ${c.bytes.toLocaleString()}B`);
    }
    console.log();
    await sleep(DELAY_MS);
  }

  const manifest = {
    generated_at: new Date().toISOString(),
    generated_by: "backend/scripts/fetch-mall-photos.mjs",
    licence_note:
      "Each image is the copyright of the mall it depicts, taken from that mall's own website, " +
      "used to identify the business and credited to it. Not openly licensed. Remove on request — " +
      "source_page records where each one came from.",
    review_note:
      "approved:false by default and NOTHING uploads until it is true. og:image is usually a logo " +
      "or a campaign graphic rather than a photograph of the building — of the first three fetched, " +
      "one was the storefront, one was a decorative paint texture and one was a wordmark. A human " +
      "looks at each candidate and flips the flag; upload-mall-photos.mjs ignores the rest.",
    photos: entries,
  };
  await writeFile(MANIFEST, JSON.stringify(manifest, null, 2) + "\n");

  const approved = entries.filter((e) => e.approved).length;
  console.log(`${entries.length} candidate(s) from ${new Set(entries.map((e) => e.place_id)).size} mall(s); ${approved} already approved`);
  console.log(`Review them, set "approved": true on the good ones in ${MANIFEST}, then run upload-mall-photos.mjs`);
}

async function fetchCandidates(mall) {
  const site = new URL(mall.website);

  if (!(await robotsAllows(site))) {
    throw new Error(`robots.txt disallows ${site.pathname}`);
  }

  const html = await getText(site.href);
  const urls = collectImageURLs(html, site).slice(0, MAX_CANDIDATES);
  if (urls.length === 0) throw new Error("no usable images on the page");

  const out = [];
  for (const [index, url] of urls.entries()) {
    try {
      out.push(await download(mall, site, url, index));
    } catch { /* one bad candidate is not a failure of the mall */ }
    await sleep(300);
  }
  if (out.length === 0) throw new Error("no candidate downloaded cleanly");
  return out;
}

async function download(mall, site, url, index) {
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT } });
  if (!res.ok) throw new Error(`image fetch ${res.status}`);

  const contentType = (res.headers.get("content-type") ?? "").split(";")[0].trim();
  if (!contentType.startsWith("image/")) throw new Error(`not an image (${contentType})`);

  const bytes = new Uint8Array(await res.arrayBuffer());
  if (bytes.byteLength < MIN_BYTES) throw new Error("too small — probably a logo");
  if (bytes.byteLength > MAX_BYTES) throw new Error("too large");

  const dims = dimensions(bytes, contentType);
  // A venue photo is landscape-ish and reasonably large. A tall banner or a
  // square badge is almost never a picture of the building.
  if (dims.width < 600 || dims.height < 300) throw new Error("too small on screen");

  const ext = contentType === "image/png" ? "png" : contentType === "image/webp" ? "webp" : "jpg";
  const file = `${mall.place_id}-${index}.${ext}`;
  await writeFile(join(CANDIDATE_DIR, file), bytes);

  return {
    place_id: mall.place_id,
    name: mall.name,
    file: `candidates/${file}`,
    content_type: contentType,
    bytes: bytes.byteLength,
    width: dims.width,
    height: dims.height,
    source_page: site.href,
    source_image: url,
    credit: `Photo © ${mall.name}`,
    fetched_at: new Date().toISOString(),
  };
}

/// Enough of each header to get width and height — no image library, and the
/// only thing we need from the pixels is their count.
function dimensions(b, contentType) {
  try {
    if (contentType === "image/png") {
      return { width: readU32(b, 16), height: readU32(b, 20) };
    }
    if (contentType === "image/webp") {
      const fmt = String.fromCharCode(...b.slice(12, 16));
      if (fmt === "VP8X") return { width: readU24LE(b, 24) + 1, height: readU24LE(b, 27) + 1 };
      if (fmt === "VP8 ") return { width: readU16LE(b, 26) & 0x3fff, height: readU16LE(b, 28) & 0x3fff };
      if (fmt === "VP8L") {
        const bits = b[21] | (b[22] << 8) | (b[23] << 16) | (b[24] << 24);
        return { width: (bits & 0x3fff) + 1, height: ((bits >> 14) & 0x3fff) + 1 };
      }
    }
    // JPEG: walk the segment markers to the start-of-frame.
    let i = 2;
    while (i < b.length) {
      if (b[i] !== 0xff) { i++; continue; }
      const marker = b[i + 1];
      if (marker >= 0xc0 && marker <= 0xcf && marker !== 0xc4 && marker !== 0xc8 && marker !== 0xcc) {
        return { width: (b[i + 7] << 8) | b[i + 8], height: (b[i + 5] << 8) | b[i + 6] };
      }
      i += 2 + ((b[i + 2] << 8) | b[i + 3]);
    }
  } catch { /* fall through */ }
  return { width: 0, height: 0 };
}

const readU32 = (b, o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
const readU24LE = (b, o) => b[o] | (b[o + 1] << 8) | (b[o + 2] << 16);
const readU16LE = (b, o) => b[o] | (b[o + 1] << 8);

/// Every plausible image on the page, og:image first because that is the one
/// the site nominated to represent itself elsewhere.
function collectImageURLs(html, base) {
  const urls = [];
  const push = (u) => {
    const abs = absolute(u, base);
    if (abs && !urls.includes(abs)) urls.push(abs);
  };

  for (const re of [
    /<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]+content=["']([^"']+)["']/gi,
    /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["']/gi,
  ]) {
    for (const m of html.matchAll(re)) push(m[1]);
  }

  for (const m of html.matchAll(/<img[^>]+(?:data-)?src=["']([^"']+)["'][^>]*>/gi)) {
    const src = m[1];
    if (/logo|icon|sprite|placeholder|avatar|pixel|banner-ad|favicon/i.test(src)) continue;
    if (!/\.(jpe?g|png|webp)(\?|$)/i.test(src)) continue;
    push(src);
  }
  return urls;
}

function absolute(url, base) {
  try {
    return new URL(url, base).href;
  } catch {
    return null;
  }
}

async function robotsAllows(site) {
  let txt;
  try {
    txt = await getText(new URL("/robots.txt", site.origin).href);
  } catch {
    // No robots.txt is not a prohibition.
    return true;
  }

  // Only the wildcard group matters to us; a rule aimed at Googlebot is not
  // aimed at us. Longest-match wins, which is what the spec says.
  let inStar = false;
  let verdict = true;
  let matched = 0;
  for (const raw of txt.split(/\r?\n/)) {
    const line = raw.split("#")[0].trim();
    if (!line) continue;
    const [field, ...rest] = line.split(":");
    const value = rest.join(":").trim();
    const key = field.trim().toLowerCase();
    if (key === "user-agent") {
      inStar = value === "*";
      continue;
    }
    if (!inStar || (key !== "allow" && key !== "disallow")) continue;
    const path = value.replace(/\*$/, "");
    if (path === "" ) continue;
    if (site.pathname.startsWith(path) && path.length >= matched) {
      matched = path.length;
      verdict = key === "allow";
    }
  }
  return verdict;
}

async function getText(url) {
  const res = await fetch(url, { headers: { "User-Agent": USER_AGENT }, redirect: "follow" });
  if (!res.ok) throw new Error(`GET ${url} -> ${res.status}`);
  return await res.text();
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
