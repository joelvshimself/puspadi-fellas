# Rollspot: guide for humans and AI agents

Rollspot is an accessibility map: people find places (malls first, Bali first), see how wheelchair-accessible
the entrances, elevators and toilets are, and contribute reviews and photos.

One repo, one backend, two native apps:

```
backend/            Cloudflare Worker (TypeScript) + D1 (SQLite) + R2 (media) + Better Auth
Mobile/shared/      Kotlin Multiplatform module: ALL business logic, used by both apps   (created in task F0)
Mobile/Rollspot/    iOS app: SwiftUI views + Apple Maps (MapKit)
Mobile/android/     Android app: Jetpack Compose views + OpenStreetMap
web/                Static site (deep-link landing, apple-app-site-association)
docs/               Product spec (specs.md), v1.1 plan and per-feature task files (docs/tasks/)
```

## The one rule: logic is shared, views are native

| Lives in `Mobile/shared` (Kotlin, written once)          | Lives in each app (Swift / Kotlin, written twice)     |
|----------------------------------------------------------|-------------------------------------------------------|
| Every call to the Cloudflare API, plus the request/response models | Screens, components, navigation, animation       |
| Auth session: sign in/up, token storage, refresh, sign out | Apple/Google sign-in *buttons* that return an ID token |
| Form state machines: which step is next, validation, "can submit" | Text fields, toggles, buttons, sheets           |
| Review submission: photo upload order, idempotency, retry, drafts | Camera / photo picker → hands bytes to shared   |
| Accessibility grade rules (collapse grades → overall)    | Grade *colors and icons*                              |
| Review list mapping, dedupe, tags, date labels           | Map rendering (MapKit on iOS, OSM on Android)         |
| Place identity (resolve a map result to a Rollspot place) | Place *search* provider (MapKit / OSM), location permission |

If you're writing an `if`, a network call or a validation rule inside a Swift or Compose view, it almost
certainly belongs in `Mobile/shared`. Views read state from a shared "model" (exposed as `StateFlow`) and send
user actions to it. That's all they do.

iOS consumes the shared module as an XCFramework built by Gradle. SKIE turns `suspend` into `async` and
`Flow` into `AsyncSequence`.

## How work is organised

Work is split **by feature, not by platform**. Whoever takes a feature delivers all of it: the shared logic,
the iOS views, the Android views, and any backend change. The board is `docs/tasks/README.md`, and each
feature has its own file `docs/tasks/F<n>-<name>.md` with checklists and acceptance criteria.

To pick up a task with Claude Code, run `/pick-task F3` (see `.claude/skills/pick-task/SKILL.md`).

## Conventions for agents

- Base branch is `V1.1`. Feature branches are `feat/F<n>-<short-name>`, and PRs go back into `V1.1`.
- Order of work inside a feature: backend contract → shared logic (with tests) → iOS views → Android views.
- Don't copy business logic from Swift into Compose or the other way round. Move it into `Mobile/shared` instead.
- The backend is the source of truth for API shapes. If you change a response, change the shared DTO in the same PR.
- Place IDs are Rollspot place IDs from `/v1/places/resolve`. Never key data by an Apple or OSM ID directly.
- No Supabase and no Google Maps/Places. Both were removed in V1.1, so don't add them back.
  (Google *Sign-In* is fine; it's an auth provider.)
- Secrets go in `backend/.dev.vars` (gitignored), `Mobile/android/local.properties` and the Xcode config. Never commit them.
- When you finish a checklist item in a task file, tick it in the same PR.

## Commands

```bash
# Backend
cd backend && npm install
npm run dev                 # local worker on :8787
npm run db:migrate:local    # apply D1 migrations locally
npm run check               # typecheck

# Shared + Android (Gradle root is Mobile/ after F0; before F0 it is Mobile/android)
cd Mobile && ./gradlew :shared:allTests
cd Mobile && ./gradlew :androidApp:assembleDebug

# iOS
xcodebuild -project Mobile/Rollspot.xcodeproj -scheme Rollspot \
  -destination 'platform=iOS Simulator,name=iPhone 16' build
```

A feature is done only when the backend typechecks, the shared tests pass, **both** apps build, and the
acceptance criteria in its task file have been checked on a simulator/emulator.
