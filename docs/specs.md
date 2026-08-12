# Wheelchair Routes — Product & Technical Spec

## 1. Overview

A wheelchair map app that lets users check, discover, save, share, and contribute
accessibility information for places — backed by Supabase. Search is the core
feature the rest of the app builds on.

**Pivoted (2026-08-12) from the original TikTok/Apify design.** Analyzing TikTok
videos for accessibility signal turned out to be both hard (video understanding is
unreliable) and low-yield (the videos usually don't contain the accessibility facts
we need). The app is now a thin data layer over existing map platforms instead:

- **OpenStreetMap** (`wheelchair=yes/no/limited` + supporting tags), queried via the
  free Overpass API, is the **primary, required** base signal — no API key, no
  cost, always attempted.
- **Google Places API** (`accessibilityOptions`: wheelchair-accessible entrance,
  parking, restroom, seating) is **secondary and optional** (flipped 2026-08-12 —
  explicit decision not to have a hard dependency on Google). The Edge Function
  only calls it if `GOOGLE_MAPS_API_KEY` is configured; the app works, with a
  smaller signal set, when it isn't.
- **Apple Maps / MapKit has no public accessibility field at all** — confirmed
  directly against Apple's own Maps Server API docs (the `Place` object only
  exposes `country`, `countryCode`, `displayMapRegion`, `formattedAddressLines`,
  `name`, `coordinate`, `structuredAddress`, `alternateIds`, `id`). Apple Business
  Connect lets business owners self-report "Wheelchair Accessible" in the consumer
  Maps app, but that attribute isn't exposed through any public API. MapKit is,
  however, exactly what handles **search and geocoding** now — `MKLocalSearch`
  runs entirely on-device, free, no key — so the Edge Function no longer does any
  text search at all; it only ever receives an already-resolved `{lat, lng, name}`
  and enriches that one location.
- Crowdsourced contributions (reviews + one-tap confirmations) enrich that base
  data into an **Accessibility Grade**: a confidence-weighted, time-decayed blend
  across every signal collected for a place, official or crowdsourced (§6).

Cost constraint, changed shape: Google's `accessibilityOptions` field is billed at
**Pro tier** ($17/1,000 calls, 5,000 free/month) — but since Google is now optional
secondary enrichment rather than required, this is a cost the team can *choose* to
opt into per-deployment, not a fixed dependency. OSM/Overpass has no per-call cost
at all. The same mitigation as before applies regardless — a **global, shared
cache** so any place is fetched from OSM (and Google, if enabled) at most once per
refresh cycle, ever, no matter how many users look at it.

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

**Client** — iOS app (Swift), using MapKit (`MKLocalSearch`) for all search and
geocoding — entirely on-device, free — and `supabase-swift` via SPM for Auth,
Postgres (PostgREST), Storage, Realtime, and Edge Functions. Keeps a thin local
response cache purely to cut repeat-view latency — not offline-first. Apple's
on-device Foundation Models framework is no longer load-bearing for the core flow
(there's no video to synthesize anymore) — it's optional polish, e.g. phrasing the
structured grade as a natural-language summary for display.

**Backend** — Supabase: Auth, Postgres (the shared cache, the accessibility signal
ledger, and all user data), and one Edge Function (`place-accessibility`) that
takes an already-resolved `{lat, lng, name}` (MapKit did the search) and enriches
it: OSM/Overpass always, Google Places only if a key is configured. The client
never holds a Google Maps API key, and doesn't need OSM to hold one either.

**External** — OpenStreetMap via the public Overpass API (primary, free,
best-effort, no SLA — see §9), Google Places API (New) (secondary, optional, the
only cost driver in this pipeline, Pro tier, only ever called from the Edge
Function and only if enabled).

See `architecture-plan-v2.excalidraw` for the full system design diagram, updated
for this pivot — Flow A now shows the Google/OSM cache-gate instead of Apify, and
a new shared "Accessibility Signal Ledger & Grade" section shows how Flow A and
Flow C both feed `accessibility_signals`. `architecture-plan.excalidraw` is the
original pre-pivot v1 sketch, kept for history only.

## 4. Feature Specs

### 4.1 Check Accessibility (Search) — no auth required — Owner 1

- Exact-location or descriptive search → `MKLocalSearch` on-device (free, no
  backend call at all for this step) → user picks 1 result (lat, lng, name).
- Flow from there: client calls the Edge Function with `{lat, lng, name}` →
  canonical `place_id` derived from the coordinate itself (`loc_<lat>_<lng>`, not
  any provider's ID) → cache check against `place_cache` → (miss) OSM/Overpass
  lookup (always) + Google Places lookup (only if `GOOGLE_MAPS_API_KEY` is set) →
  both written into `place_cache` + `accessibility_signals` → client gets back the
  base data plus the live `accessibility_grade()` for the place. Every future
  viewer of that place skips both external calls entirely until the cache TTL
  (90 days — accessibility features change slowly) expires.
- `search_query_cache` (from the first pivot migration) is now unused — caching a
  list of candidate place IDs only made sense when search itself was a paid
  Google call. Left in the schema rather than dropped; harmless if empty.
- Dropped with the pivot: the TikTok/IG share-extension import path from the
  original Story 1 diagram — there's no video content to import anymore.

### 4.2 Discover Nearby — no auth required — Owner 1

- Pure read against `place_cache` — a PostGIS radius query (`nearby_places()`) on
  the cache's lat/lng, ranked by distance + each place's live `accessibility_grade()`.
  **No Google Places call is ever triggered by this path.**
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
- Form: structured yes/no/limited answers for entrance, parking, restroom, and
  seating accessibility (tightened from the original freeform
  entrance/exit/indoor/outdoor fields so a review maps directly onto the same
  `accessibility_feature`/`accessibility_value` vocabulary Google and OSM signals
  use), plus a free-text notes field.
- Write to `reviews` → a trigger (`review_to_signals`) fans each structured answer
  out into `accessibility_signals` (source `review`, weight 0.4), where it's just
  one more piece of evidence feeding that place's live `accessibility_grade()`. A
  review no longer marks `place_cache` stale — the base Google/OSM data doesn't
  need re-fetching just because a user left a review; only the grade
  recomputation, which happens live at read time, sees it.
- Resolved by the pivot: this replaces the earlier "majority vote" idea — see §6
  for the confidence-weighted blend that now aggregates reviews, one-tap
  confirmations, and API data together.

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
  accessibility flags) → marks that place's `venue_imdf_archives` row stale (not
  `place_cache` — a recorded route says nothing new about Google/OSM's base data,
  only about the rendered venue archive below).

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

- `place_cache` is **global** — shared across every user, not per-user. One Google
  Places call, ever (per 90-day refresh cycle), serves every user who looks at
  that place.
- Two distinct cache tables now, since the two search paths cache different
  *shapes* of thing:
  - `place_cache` — per-place base data (Google `accessibilityOptions` +
    OpenStreetMap tags), keyed by Google Place ID.
  - `search_query_cache` — per-query candidate list (an array of place IDs a
    descriptive search resolved to), keyed by a hash of the normalized query
    text, TTL'd shorter (30 days) since search result rankings churn faster than
    a place's own accessibility facts do.
- Freshness is now purely about the *base API data* being stale (`fetched_at` +
  90-day TTL) — it is deliberately **decoupled** from user contributions. A new
  review or confirmation doesn't mean Google's data is wrong or needs re-fetching;
  it's a separate signal that feeds the grade directly (§6.1), not a cache
  invalidation event. This is a change from the pre-pivot design, where reviews
  and routes flipped `place_cache.is_stale` — that coupling no longer makes sense
  now that "the cache" and "the grade" are different things computed differently.

### 6.1 Accessibility Grade — confidence-weighted, time-decayed blend

Every piece of evidence about a place's accessibility — Google's field, OSM's tag,
a detailed review, a one-tap confirmation — is written as a row in
`accessibility_signals` (`place_id`, `feature` [entrance/parking/restroom/seating],
`value` [yes/no/limited/unknown], `source` [google/osm/review/confirmation],
`confidence_weight`, `created_at`). The grade is **computed live**, not stored, via
`accessibility_grade(place_id)`: for each feature, every signal's weight decays
over time (half-life 180 days, tunable) before being summed per candidate value;
the highest-weight value wins, with its summed weight reported as the confidence.

This was the explicit choice over two alternatives we considered: "official data
as a baseline that crowd answers simply override" (simpler, but throws away
disagreement information) and "per-feature facts with no single score" (most
transparent, but doesn't produce the single "Accessibility Grade" the feature is
named after). The confidence-weighted blend was chosen because it degrades
gracefully — one bad-faith or mistaken contribution doesn't flip the grade outright,
and old signals fade rather than staying authoritative forever.

Default starting weights per source (set by the inserting code, not hardcoded in
the schema, so they're tunable without a migration): OSM 0.6 (primary), Google 0.5
(secondary, when enabled), review 0.4, single confirmation tap 0.2. Flipped
2026-08-12 to put OSM ahead of Google, matching the source-priority decision above
— these are still v1 defaults, expect to tune them once real usage data exists
(see §8).

A repeat signal from the same user for the same place/feature/source **updates**
their existing row rather than stacking additional weight (enforced by a unique
constraint on `place_id, feature, source, user_id`), so one person tapping "yes"
five times doesn't out-weigh five different people each tapping once.

### 6.2 Frictionless Crowdsourcing — proximity-triggered micro-confirmations

The default contribution mechanism is a single-tap "is this accessible?" quest,
StreetComplete-style, not the full review form (which remains available as an
optional "detailed review" path for users who want to contribute more). Chosen
over an in-app-only ("only prompt when the user opens a place's Detail view")
alternative because proximity nudges drive meaningfully more contribution volume
per the gamification research behind StreetComplete/mPASS — at the cost of needing
background location permission, which has real battery and privacy implications
the team has accepted as a tradeoff worth making.

Mechanism: the client periodically calls `places_needing_confirmation(lat, lng,
radius, confidence_threshold)`, which returns nearby places with at least one
feature below the confidence threshold, and registers a `CLCircularRegion` geofence
for each. On region entry, the app surfaces a notification/prompt for the specific
missing feature ("Does Java House Westlands have a wheelchair-accessible
entrance?"). A tap writes directly to `accessibility_signals` (source
`confirmation`, weight 0.2) — no form, no detail-view visit required.

## 7. Team Ownership (3 people)

| Owner | Vertical | Owns |
|---|---|---|
| **Owner 1** | Search & Discover | Check Accessibility (4.1), Discover Nearby (4.2), Edge Function `place-accessibility` (Google Places + OSM cache-gate), `place_cache`/`search_query_cache` schema + cache logic |
| **Owner 2** | Account & Personal Features | Auth Gate + Supabase Auth integration + RLS policies, Save Places (4.3), Share Places (4.4) |
| **Owner 3** | Community & Route Data | Review Accessibility (4.5), the Accessibility Grade model (§6.1) and proximity-nudge crowdsourcing (§6.2), Record Route (4.6) + IMDF/CoreMotion positioning + moderation, self-hosted per-venue IMDF archive generation + MapKit rendering |

Dependency note: Owner 3's grade/crowdsourcing work reads Owner 1's `place_cache`
(for `nearby_places()`/`places_needing_confirmation()`) and writes into
`accessibility_signals`, which both owners' code touches — Owner 1 writes
google/osm-sourced rows from the Edge Function, Owner 3 writes review/confirmation
rows from the client. Neither blocks the other; the shared table is what needs
coordinating, not sequencing.

## 8. Open Questions Remaining

- Sign in with Apple vs. email/OTP (or both) for Auth — final call needed.
- Web fallback page hosting for share links.
- Tune the default confidence-weight-per-source and 180-day half-life in
  `accessibility_grade()` once real usage data exists (§6.1) — v1 values are a
  starting guess, not measured.
- Tune the `confidence_threshold` and geofence radius in
  `places_needing_confirmation()` (§6.2) — too aggressive and it's spammy, too
  conservative and it never fires.
- Route moderation process for user-submitted waypoints (who reviews/approves).
- How strictly our self-hosted per-venue IMDF archives should conform to the full
  IMDF spec vs. a practical accessibility-only subset — only matters if we ever
  want to submit one to Apple's Indoor Maps Program for a partner venue later.
- `GOOGLE_MAPS_API_KEY` is optional (flipped 2026-08-12) — the Edge Function
  runs fine without it, just with OSM as the only signal. Whether to provision
  one at all (Google Cloud Console, Places API (New) enabled, billing attached)
  is now a cost/coverage tradeoff decision, not a blocker.
- MapKit (`MKLocalSearch`) isn't wired into the Xcode project yet — the app's
  current search UI (`Views/Home/SearchSheet.swift`) still runs on
  `Models/Place.swift` mock data.

## 9. Data Sourcing & Licensing Notes

- **Apple Maps/MapKit is not a data source for this app** — verified directly
  against Apple's Maps Server API docs, no accessibility field exists on the
  `Place` object. Kept only for rendering/search/geocoding.
- **OpenStreetMap data is read-only for now** (explicit decision, 2026-08-12) —
  we consume the public `wheelchair` tag via Overpass but do not write confirmed
  contributions back into OSM. Revisit this once the app has real usage; writing
  back would grow a public good but means accepting OSM's ODbL share-alike terms
  and community edit-review norms as an ongoing dependency.
- **Overture Maps was evaluated and ruled out** — it explicitly excludes
  OpenStreetMap data from its Places theme and has no accessibility attributes.
- The public Overpass API has no hard rate limit but also no SLA ("fair use" load
  shedding) — fine for v1 traffic; self-hosting Overpass is the documented path if
  this becomes unreliable at scale.
