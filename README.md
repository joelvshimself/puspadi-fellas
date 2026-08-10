# Puspadi Fellas

An app that helps people with mobility disabilities make informed decisions by providing accessibility insights extracted from TikTok videos.

## Monorepo layout

```text
puspadi-fellas/
├── Mobile/     # SwiftUI iOS app
└── backend/    # Backend (empty for now)
```

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
- **Search** — Tap “Find a place” to open a top search bar with Cancel; mock results list below (no categories/tabs). Tap a result to open detail.
- **Detail** — Single-place view (Save, Share, Facilities / Routes / Review, gallery, reviews summary).
- **Saved** — TODO placeholder screen from the Saved tab.
- **Contribute** — TODO placeholder screen from the Contribute tab.
- **Analysing** — Disconnected animated demo screen (sparkle pulse + floating cards). Not part of the main search flow.

### Demo gestures

1. Tap the search bar → top search UI + mock results → tap a result (e.g. Park 23) → detail.
2. Tap **Saved** or **Contribute** in the home card → TODO screen; back returns to the map.
3. Long-press the profile button (top right) → Analysing screen; tap ✕ to close.

## Backend

The `backend/` folder is reserved for the future API and processing services. It is intentionally empty for now.
