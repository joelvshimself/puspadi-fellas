# Architecture decisions and extension guide

These records describe decisions evidenced by implementation. Historical rationale is marked **Unknown**
when it cannot be recovered.

## One backend and shared KMP business logic

- **Context:** two native apps require consistent API contracts, validation, auth state, and grade rules.
- **Decision:** centralize these in `Mobile/shared`; keep SwiftUI/Compose and platform SDK work native.
- **Trade-off:** consistent logic and tests, at the cost of Gradle/Xcode integration and Swift bridging.
- **Evidence:** `CLAUDE.md`, `RollspotSdk`, shared feature models, native adapters.

## Own place directory sourced from OpenStreetMap

- **Decision:** apps query D1 via `/v1/places/*`; a Worker cron imports OSM through Overpass.
- **Consequences:** stable Rollspot IDs and cross-platform parity; attribution required; directory freshness
  depends on scheduled import and Overpass.
- **Rationale:** cross-platform source-of-truth need is evidenced; original product/business rationale is
  **Unknown**.

## Native map renderers

- **Decision:** MapKit on iOS, MapLibre/OpenFreeMap on Android; neither chooses which places exist.
- **Trade-off:** platform-native experience and no Google Maps dependency, with visual/availability
  differences between platforms.

## D1 plus R2

- **Context:** the Worker must store structured application data (users, places, reviews, grades) and
  binary JPEG media. A single storage type is a poor fit for both.
- **Decision:** Cloudflare D1 holds the relational database; Cloudflare R2 holds photo bytes. The Worker
  is the only component that talks to either store.
- **Why D1:** D1 is SQLite at the edge. Rollspot needs SQL joins, uniqueness constraints (for example one
  review per user and `submission_id`), indexes for nearby search and FTS, and foreign-key cascades when a
  user or review is deleted. Those are database concerns, not object-storage concerns. Schema and
  constraints live in [`backend/migrations/`](../../backend/migrations/); query and batch usage live in
  Worker modules such as [`places.ts`](../../backend/src/places.ts), [`reviews.ts`](../../backend/src/reviews.ts),
  [`auth.ts`](../../backend/src/auth.ts), and [`sync.ts`](../../backend/src/sync.ts). The binding name is `DB`
  in [`backend/wrangler.jsonc`](../../backend/wrangler.jsonc).
- **Why R2:** review photos and avatars are opaque JPEG blobs, often several megabytes. Storing them as
  database BLOBs would bloat D1 and complicate streaming. R2 stores objects by key; D1 only stores the
  `object_key` and ownership metadata in `media_uploads`. Upload and read handlers are in
  [`backend/src/media.ts`](../../backend/src/media.ts) and avatar handling in
  [`backend/src/profile.ts`](../../backend/src/profile.ts). The binding name is `MEDIA` and the bucket is
  `rollspot-media` in [`backend/wrangler.jsonc`](../../backend/wrangler.jsonc).
- **How they connect:** a contribution uploads JPEG bytes to R2 first, records the key in D1, then the
  review POST references those keys. Public photo URLs point at `/v1/media/:objectKey`, which the Worker
  serves from R2. Account and review deletion remove D1 rows and then attempt matching R2 deletes.
- **Trade-off:** efficient domain queries and object storage, but D1 and R2 cannot commit in one
  transaction, so a partial failure can leave an orphaned object or a deleted row with leftover bytes.
- **Where to look next:** full table map in [`../backend/data-models.md`](../backend/data-models.md);
  media flow in [`../architecture/data-flow.md`](../architecture/data-flow.md).

## Idempotent client-generated review IDs

- **Decision:** client keeps `submissionId` and photo `fileId`; D1 uniqueness and deterministic R2 keys
  absorb retries.
- **Consequence:** writes need no automatic retry, but the UI must preserve IDs after failure.
