# Puspadi Fellas

An app that helps people with mobility disabilities make informed decisions by providing accessibility insights extracted from TikTok videos.

## Monorepo layout

```text
puspadi-fellas/
├── Mobile/     # SwiftUI iOS app
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
| **Owner 3** | Review & Record Route | `Views/Contribute/`, the Facilities/Routes/Review tabs in `Views/Detail/PlaceDetailView.swift` | `reviews`, `routes`, `venue_imdf_archives` in the migration |

`Views/Detail/PlaceDetailView.swift` currently holds pieces of all three
owners' UI (Save, Share, Facilities/Routes/Review tabs) — expect to split it
into per-owner subviews early rather than all three editing one file.

Full detail per feature (including the lazy-auth trigger points, the two-tier
cache, and the IMDF/CoreMotion positioning split for route recording) is in
`docs/specs.md` §4–§7.

## Mobile

Open the iOS app in Xcode:

```bash
open Mobile/Mobile.xcodeproj
```

Then select a simulator and run (⌘R).

### Folder layout

```text
Mobile/Mobile/
├── App/                 # App entry (MobileApp)
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
`nearby_places()` RPC, and cache-invalidation triggers are all in one initial
migration; the `place-accessibility` Edge Function is the only thing allowed
to call Apify (see `docs/specs.md` §6 for why).

```text
backend/
├── .env.example                          # copy to .env, fill in locally, never commit it
└── supabase/
    ├── config.toml
    ├── migrations/
    │   └── <timestamp>_init_schema.sql   # place_cache, profiles, folders,
    │                                      # saved_places, reviews, routes,
    │                                      # venue_imdf_archives, RLS, triggers
    └── functions/
        └── place-accessibility/          # Owner 1 — the Apify cache-gate (stub, see TODOs)
```

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
