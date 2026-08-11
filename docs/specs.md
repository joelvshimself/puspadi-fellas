# Wheelchair Routes — Product & Technical Spec

## 1. Overview

A wheelchair map app that lets users check, discover, save, share, and contribute
accessibility information for places — sourced from TikTok/social content via Apify,
synthesized with Apple's on-device Foundation Models, and backed by Supabase. Search
is the core feature the rest of the app builds on.

Primary cost constraint: Apify calls (and to a lesser extent on-device ML re-runs)
are the expensive/slow step. The architecture is built around a **global, shared
cache** so any place is scraped and synthesized at most once, ever, no matter how
many users look at it.

## 2. User Stories (MoSCoW)

**Must have**
1. Check a place's accessibility, to decide whether it's accessible for me.
2. Save places I want to visit, to find them easily later.
3. Share places with friends, so they can view and visit them later.

**Should have**
4. Record my wheelchair route through a place, so other users can follow an
   accessible path.
5. Review a place's accessibility, so other users can make informed decisions.
6. Discover accessible places nearby, to choose destinations that meet my needs.

## 3. System Architecture

**Client** — iOS app (Swift), using `supabase-swift` via SPM for Auth, Postgres
(PostgREST), Storage, Realtime, and Edge Functions. Runs Apple's on-device
Foundation Models framework locally for multimodal synthesis (video frames → structured
accessibility data via `@Generable`). Keeps a thin local response cache purely to cut
repeat-view latency — not offline-first.

**Backend** — Supabase: Auth, Postgres (the shared cache + all user data), and one
Edge Function (`place-accessibility`) that gatekeeps every call to Apify. The client
never holds an Apify API key.

**External** — Apify (TikTok scraping, the cost driver, only ever called from the
Edge Function), Apple Foundation Models on-device model (free) with Private Cloud
Compute as an escalation path for harder reasoning (still mid-tier vs. frontier
cloud models — not a substitute if a case genuinely needs top-tier reasoning).

See `architecture-plan-v2.excalidraw` for the full system design diagram (`architecture-plan.excalidraw` is the earlier v1 sketch, kept for history).

## 4. Feature Specs

### 4.1 Check Accessibility (Search) — no auth required — Owner 1

- Exact-location search → resolve to a place ID → AI synthesis → 1 result.
- Descriptive search (natural language) → AI synthesis → top-K results → user picks 1.
- Flow: client → Edge Function → cache check → (miss) Apify → raw sources returned to
  client → on-device Foundation Models synthesis → client writes the synthesized
  result back to `place_cache` so every future viewer of that place skips both Apify
  *and* the on-device synthesis step.
- Open: TikTok/IG share-extension import path (seen in the Story 1 diagram) is not
  yet confirmed in/out of scope for v1.

### 4.2 Discover Nearby — no auth required — Owner 1

- Pure read against `place_cache` — a PostGIS radius query on the cache's lat/lng,
  ranked by distance + accessibility score. **No Apify call is ever triggered by
  this path.**
- Known v1 limitation: a place is only discoverable once someone has already
  searched it via 4.1 — this is a cold-start/coverage gap, not a bug. A scheduled
  job to pre-warm the cache for dense areas is a v2 lever, not a v1 requirement.

### 4.3 Save Places — auth required — Owner 2

- Tapping Save on an unauthenticated session triggers the Auth Gate (see §5) before
  anything else happens.
- Choose/create a folder → write a row to `saved_places` (user_id, place_id,
  folder_id). RLS restricts read/write to the owning user.

### 4.4 Share Places — no auth required — Owner 2

- Tap Share → generate a deep link (custom scheme + universal link) encoding the
  place ID → system share sheet.
- Universal link needs a lightweight web fallback page for recipients without the
  app installed (hosting TBD — see open questions).
- No write happens server-side, so no session is needed to share.

### 4.5 Review Accessibility — auth required — Owner 3

- Tap Review on an unauthenticated session triggers the Auth Gate.
- Form: entrance/exit facilities, indoor spaces, outdoor spaces.
- Write to `reviews` (user_id, place_id, fields, created_at) → marks that place's
  `place_cache` row stale.
- Open: aggregation logic for turning N reviews into the single score shown in 4.1's
  results is not designed yet. Recommend starting v1 with "show individual reviews +
  a simple majority vote on ramp-present" rather than a weighted score.

### 4.6 Record Route — auth required — Owner 3

- Tap "record route" on an unauthenticated session triggers the Auth Gate.
- **Positioning strategy while recording** (two paths, chosen automatically per venue):
  1. **IMDF-registered venue** (the venue has been onboarded to Apple's Indoor Maps
     Program — malls, airports, stadiums, large campuses, and has gone through
     Apple's WiFi RF-fingerprint survey): use CoreLocation's indoor positioning for
     floor-accurate ramp/elevator waypoint capture.
  2. **Not IMDF-registered** (the common case — independent cafes, shops, small
     venues): fall back to CoreMotion relative dead-reckoning (step counting +
     heading) plus manual "drop a pin" waypoint marking when the "did you just...?"
     prompt fires. There is no absolute indoor position to anchor to here.
- **Constraint on positioning specifically**: true Apple indoor positioning (the
  "blue dot" via `CLLocation`) requires the venue to have completed the full Indoor
  Maps Program pipeline — enrollment, a professionally-validated archive (IMDF
  Sandbox), and a physical WiFi survey. Most of this app's target locations won't
  have done this, so path 2 above is the common case, not the exception. This
  constraint is about *positioning accuracy during capture* only — see below for
  why it does **not** block using IMDF as a format.
- Submitted route → write to `routes` table (the raw trace: waypoints, timestamps,
  accessibility flags) → marks that place's `place_cache` row stale.

- **Rendering the result — self-hosted IMDF, decoupled from Apple's program**:
  The raw trace itself is never stored *as* IMDF — IMDF has no path/trajectory
  feature type; its vocabulary (Level, Unit, Opening, Amenity, Occupant, Anchor,
  Footprint, Kiosk, Section) only describes a venue's static structure. Instead:
  1. A backend job aggregates `routes` + `reviews` for a place into a per-venue
     IMDF-shaped archive: a `Unit` for the walkway, an `Opening` per doorway tagged
     `accessible: true/false`, an `Amenity` point for a detected elevator or
     accessible restroom.
  2. That archive (a manifest + GeoJSON feature files) is stored in Supabase
     Storage, self-hosted — it is never submitted to Apple.
  3. The client renders it with standard MapKit APIs (`MKGeoJSONDecoder` +
     `addOverlays`/`addAnnotations`, or `importGeoJSON` on web) — the exact
     mechanism Apple's own Indoor Maps Program apps use for display. **This
     rendering path requires no Apple review or approval** — only the two things
     called out above (true "blue dot" positioning, and being shown inside Apple
     Maps itself) require joining the Indoor Maps Program. Rendering an
     IMDF-formatted map you authored yourself is open to any app.
  4. The archive regenerates whenever `is_stale` is set by a new route/review
     submission for that place.

## 5. Auth Strategy — Owner 2

Auth is **lazy**: no session is required to open the app, search, view results, or
discover nearby. A session is required only at the moment a gated action is taken —
**Save**, **Review**, **Record Route**. **Share** does not require a session.

Implementation:
- An "Auth Gate" check runs before any gated action. If no session exists, present
  a Supabase Auth sign-in/sign-up sheet modally; on success, resume the original
  action rather than dropping the user back to a blank state.
- Recommend Sign in with Apple as the primary method for an iOS app (no password
  friction, aligns with Apple review expectations); email/OTP as a secondary option
  — final choice open (see §8).
- RLS: `saved_places`, `reviews`, and `routes` are scoped to the owning user.
  `place_cache` stays globally readable by anyone (anon key) but is only writable
  via the Edge Function / a service-role-scoped path, so a client can never poison
  the shared cache directly.

## 6. Caching Strategy — Owner 1

- `place_cache` is **global** — shared across every user, not per-user. One Apify
  run + one on-device synthesis, ever, serves every user who looks at that place.
- Two distinct cache keys, because they serve two different search paths:
  - place ID (exact-location search)
  - query-hash (descriptive/fuzzy search)
- Two-tier freshness: a cache hit on the *synthesized* result skips both Apify and
  on-device ML entirely; a hit on only the *raw scrape* still needs a fresh
  on-device synthesis pass but skips Apify.
- Invalidation: any new review or recorded route for a place flips that place's
  `place_cache.is_stale` flag — the next request for that place forces a refresh
  instead of silently serving outdated accessibility info.

## 7. Team Ownership (3 people)

| Owner | Vertical | Owns |
|---|---|---|
| **Owner 1** | Search & Intelligence Core | Check Accessibility (4.1), Discover Nearby (4.2), Edge Function `place-accessibility`, `place_cache` schema + cache logic, on-device Foundation Models synthesis pipeline |
| **Owner 2** | Account & Personal Features | Auth Gate + Supabase Auth integration + RLS policies, Save Places (4.3), Share Places (4.4) |
| **Owner 3** | Community & Route Data | Review Accessibility (4.5) + aggregation logic, Record Route (4.6) + IMDF/CoreMotion positioning + moderation, cache-invalidation triggers (publisher side), self-hosted per-venue IMDF archive generation + MapKit rendering |

Dependency note: Owner 2 and Owner 3's write paths depend on Owner 1's
`place_cache.is_stale` column existing, and on the Auth Gate Owner 2 builds. Neither
is a hard blocker — Owner 1 can ship the column early, and Owner 2 can ship a
minimal Auth Gate before Save/Review/Route UIs are ready to call it.

## 8. Open Questions Remaining

- Sign in with Apple vs. email/OTP (or both) for Auth — final call needed.
- Web fallback page hosting for share links.
- Review aggregation algorithm specifics (majority vote vs. weighted score).
- Cold-start seeding strategy for Discover Nearby in unsearched areas.
- TikTok/Instagram share-extension video import — confirm in/out of scope for v1.
- Route moderation process for user-submitted waypoints (who reviews/approves).
- How strictly our self-hosted per-venue IMDF archives should conform to the full
  IMDF spec vs. a practical accessibility-only subset — only matters if we ever
  want to submit one to Apple's Indoor Maps Program for a partner venue later.
