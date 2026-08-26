# Puspadi Fellas

Rollspot is an app that helps people with mobility disabilities make informed decisions by showing accessibility info for places — sourced from Google Places / OpenStreetMap and enriched by crowdsourced reviews and one-tap confirmations. (Pivoted 2026-08-12 from an earlier TikTok-video-analysis design — see `docs/specs.md` §1 for why.)

## Monorepo layout

```text
puspadi-fellas/
├── Mobile/     # Rollspot — SwiftUI iOS app
├── backend/    # Supabase project (Postgres, Auth, Storage, Edge Functions)
└── docs/       # Spec + system design diagrams — read this first
```

Start with [`docs/specs.md`](docs/specs.md) — it's the source of truth for what
each feature does and who owns it. `docs/architecture-plan-v2.excalidraw` is the
current system design diagram (open it at excalidraw.com or with the Excalidraw
VS Code extension); `docs/architecture-plan.excalidraw` is an earlier draft kept
for history.

## Team ownership

Three owners, each a full vertical slice (client UI + their Postgres tables +
their backend logic), mapped onto the folders that already exist in this repo:

| Owner | Vertical | Mobile | Backend |
|---|---|---|---|
| **Owner 1** | Search & Discover | `Views/Home/` (map, search sheet), `Models/Place.swift`, the search-results portion of `Views/Detail/PlaceDetailView.swift` | `supabase/functions/place-accessibility`, `place_cache` + `nearby_places()` in the migration |
| **Owner 2** | Save & Share | `Views/Saved/`, the Save/Share buttons in `Views/Detail/PlaceDetailView.swift` | `profiles`, `folders`, `saved_places` in the migration; Auth Gate wiring |
| **Owner 3** | Review & Record Route | `Views/Contribute/`, the Facilities/Routes/Review tabs in `Views/Detail/PlaceDetailView.swift`, the proximity-nudge quest UI (new) | `reviews`, `routes`, `venue_imdf_archives`, `accessibility_signals` + `accessibility_grade()` / `places_needing_confirmation()`, `supabase/functions/submit-accessibility-review` |

`Views/Detail/PlaceDetailView.swift` currently holds pieces of all three
owners' UI (Save, Share, Facilities/Routes/Review tabs) — expect to split it
into per-owner subviews early rather than all three editing one file.

Full detail per feature (including the lazy-auth trigger points, the two-tier
cache, and the IMDF/CoreMotion positioning split for route recording) is in
`docs/specs.md` §4–§7.

## Mobile

Open the iOS app in Xcode:

```bash
open Mobile/Rollspot.xcodeproj
```

Then select a simulator and run (⌘R).

### Folder layout

```text
Mobile/Rollspot/
├── App/                 # App entry (RollspotApp)
├── Models/              # Domain models + mock data
├── Views/
│   ├── ContentView.swift
│   ├── Home/            # Map home + search sheet / panel
│   ├── Detail/          # Single place view
│   ├── Saved/           # Saved places (TODO)
│   ├── Contribute/      # Contribute flow (TODO)
│   └── Analysing/       # Disconnected analysing screen
└── Resources/           # Assets.xcassets
```

### Screens

- **Home** — Full-screen MapKit map with pins, filter/profile buttons, location control, and a floating Liquid Glass card (search, category cards, Explore / Saved / Contribute).
- **Search** — Tap “Find a place”: the same sheet expands to the top; category row and tabs fade out; mock results appear under the search field.
- **Detail** — Single-place view (Save, Share, Facilities / Routes / Review, gallery, reviews summary).
- **Saved** — TODO placeholder screen from the Saved tab.
- **Contribute** — TODO placeholder screen from the Contribute tab.
- **Analysing** — Disconnected animated demo screen (sparkle pulse + floating cards). Not part of the main search flow.

### Demo gestures

1. Tap the search bar → top search UI + mock results → tap a result (e.g. Park 23) → detail.
2. Tap **Saved** or **Contribute** in the home card → TODO screen; back returns to the map.
3. Long-press the profile button (top right) → Analysing screen; tap ✕ to close.

## Backend

A Supabase project lives in `backend/`. Schema, RLS policies, the
`nearby_places()` / `places_needing_confirmation()` RPCs, and the
confidence-weighted `accessibility_grade()` function are spread across a few
migrations (applied in order); Edge Functions: `place-accessibility` (Owner 1 —
only writer allowed to call Google Places) and `submit-accessibility-review`
(Owner 3 — iPhone contribution payload). See `docs/specs.md` §3/§4.5/§6.

```text
backend/
├── .env.example                          # copy to .env, fill in locally, never commit it
├── scripts/                              # place-directory seed pipeline (see below)
├── seed/                                 # the downloaded dataset + curated aliases
└── supabase/
    ├── config.toml
    ├── migrations/
    │   ├── <ts>_init_schema.sql          # place_cache, profiles, folders,
    │   │                                  # saved_places, reviews, routes,
    │   │                                  # venue_imdf_archives, RLS
    │   ├── <ts>_maps_data_pivot.sql       # accessibility_signals,
    │   │                                  # accessibility_grade(),
    │   │                                  # places_needing_confirmation(),
    │   │                                  # search_query_cache
    │   ├── <ts>_restore_imdf_stale_trigger.sql
    │   └── <ts>_submit_accessibility_review.sql  # elevator feature, reviews.details,
    │                                              # nullable user_id (testing)
    └── functions/
        ├── place-accessibility/           # Owner 1 — Google Places / OSM cache-gate
        ├── places-nearby/                 # Owner 1 — curated place directory reads
        └── submit-accessibility-review/   # Owner 3 — contribute payload from iPhone
```

### Place directory (Bali malls)

`place_cache` is two things at once: a cache of whatever a user's lookup
happened to resolve, and — since 2026-08-26 — a curated directory of places we
imported deliberately (`is_seeded = true`). The first directory is the south
Bali shopping malls, 22 of them, downloaded from OpenStreetMap.

```text
backend/
├── scripts/
│   ├── fetch-bali-malls.mjs          # Overpass -> seed/bali-malls.json
│   ├── generate-bali-mall-seed.mjs   # that JSON -> the seed migration
│   └── bali-mall-seed.template.sql   # what the generator renders
└── seed/
    ├── bali-malls.json               # the dataset, reviewable as a diff
    └── bali-mall-aliases.json        # hand-curated: the other names each mall goes by
```

To refresh it:

```bash
node backend/scripts/fetch-bali-malls.mjs        # re-download from OSM
node backend/scripts/generate-bali-mall-seed.mjs # rewrite the seed migration
cd backend && npx supabase db push
```

The seed migration has a fixed filename and is idempotent, so a refresh
*updates* it rather than stacking a second seed migration.

**Why OpenStreetMap and not Google.** ODbL lets us store the data, redistribute
it and build on it, provided the attribution travels with it — which is why
`place_cache.data_attribution` exists and the detail page renders it. Google
Places' terms allow caching a place ID and not much else, so Google stays where
it already is: live enrichment behind `place-accessibility`, never a stored
dataset.

**Why the alias table.** Every source spells a mall differently — OSM says
"Beachwalk Bali", MapKit says "Beachwalk Shopping Center" — and
`resolve_place_id()` matches names exactly. Without `place_aliases` a client
lookup misses the seeded row and mints a duplicate beside it. That failure is
already visible in the live table (five Beachwalk rows, five Icon Bali rows);
the seed migration folds those into the seeded id, reviews and saved places
first.

**Reading it back.** `places_directory_nearby()` (via the `places-nearby` Edge
Function) is the directory's read side; the iOS client merges it with
MKLocalSearch in `NearbyPlacesService.search`. `nearby_places()` is the older
RPC and still has no caller.

### Getting started (per owner, on your own machine)

The Supabase CLI isn't installed globally in this environment — use `npx` so
everyone's on the same version without a global install:

```bash
cd backend
npx supabase login          # once, per machine
npx supabase init           # already done — should no-op / show existing config
npx supabase start          # local Postgres + Auth + Storage + Studio
npx supabase db push        # applies migrations/
```

To link to the shared hosted project once one exists:

```bash
npx supabase link --project-ref <project-ref>
npx supabase db push
```

To work on the Edge Function locally:

```bash
npx supabase functions serve place-accessibility --env-file .env
```

The iOS app needs `SUPABASE_URL` and `SUPABASE_ANON_KEY` (see `.env.example`)
wired up via `supabase-swift` (SPM) — not added to the Xcode project yet.
