# Rollspot: guide for humans and AI agents

Rollspot is an accessibility map: people find places (malls first, Bali first), see how wheelchair-accessible
the entrances, elevators and toilets are, and contribute reviews and photos.

One repo, one backend, two native apps:

```
backend/            Cloudflare Worker (TypeScript) + D1 (SQLite) + R2 (media) + Better Auth
Mobile/shared/      Kotlin Multiplatform module: ALL business logic, used by both apps
Mobile/Rollspot/    iOS app: SwiftUI views + Apple Maps (MapKit)
Mobile/android/     Android app: Jetpack Compose views + OpenStreetMap
web/                Static site (deep-link landing, apple-app-site-association)
docs/               Product spec (specs.md)
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
| Which places exist: search and nearby from our place directory | Location permission, the map widget itself       |

If you're writing an `if`, a network call or a validation rule inside a Swift or Compose view, it almost
certainly belongs in `Mobile/shared`. Views read state from a shared "model" (exposed as `StateFlow`) and send
user actions to it. That's all they do.

iOS consumes the shared module as an XCFramework built by Gradle. SKIE turns `suspend` into `async` and
`Flow` into `AsyncSequence`.

## How work is organised

Work is split **by feature, not by platform**. Whoever takes a feature delivers all of it: the shared logic,
the iOS views, the Android views, and any backend change.

- **Tasks are GitHub issues.** Each has the label `feature` and the milestone `V1.1`, with checklists and
  acceptance criteria in the body. List them with `gh issue list -m V1.1 -l feature`.
- **Board:** https://github.com/users/kennethmuyoyo/projects/2 (Todo → In Progress → Done).
- **New feature?** Open an issue from the "Feature (end-to-end)" template.
- **Picking one up with Claude Code:** run `/pick-task #33` (see `.claude/skills/pick-task/SKILL.md`).

## Conventions for agents

- Base branch is `V1.1`. Feature branches are `feat/F<n>-<short-name>`, and PRs go back into `V1.1` with `Closes #<issue>`.
- Order of work inside a feature: backend contract → shared logic (with tests) → iOS views → Android views.
- Don't copy business logic from Swift into Compose or the other way round. Move it into `Mobile/shared` instead.
- The backend is the source of truth for API shapes. If you change a response, change the shared DTO in the same PR.
- **Places come from our own directory** (D1 `places`, built from OpenStreetMap by a weekly Worker cron).
  Apps get places only from `/v1/places/nearby|search|:id` via the shared `PlaceRepository`, and never from
  MapKit search, Google Places or public OSM servers. Use the Rollspot place ID everywhere; `osm:<type>/<id>`
  keys are accepted in links. Show "© OpenStreetMap contributors" wherever place data appears.
- No Supabase and no Google Maps/Places. Both were removed in V1.1, so don't add them back.
  (Google *Sign-In* is fine; it's an auth provider.)
- Secrets go in `backend/.dev.vars` (gitignored), `Mobile/android/local.properties` and the Xcode config. Never commit them.
- When you finish a checklist item, tick it in the GitHub issue.

## Commands

```bash
# Backend
cd backend && npm install
npm run dev                 # local worker on :8787
npm run db:migrate:local    # apply D1 migrations locally
npm run check               # typecheck

curl -X POST -H "authorization: Bearer $ADMIN_TOKEN" localhost:8787/v1/admin/sync-places   # load places once

# Shared + Android. Gradle root is Mobile/. JDK 25 (Homebrew: brew install openjdk@25)
export JAVA_HOME=/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home
cd Mobile && ./gradlew :shared:testDebugUnitTest :shared:iosSimulatorArm64Test
cd Mobile && ./gradlew :androidApp:assembleDebug

# iOS (the "Build shared module" phase compiles Mobile/shared first; see Mobile/scripts/build-shared-for-xcode.sh)
xcodebuild -project Mobile/Rollspot.xcodeproj -scheme Rollspot \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

**Pointing the apps at a local backend** (`npm run dev`):
- iOS (debug builds): Xcode scheme → Run → Environment Variables → `ROLLSPOT_API_BASE_URL=http://localhost:8787`
- Android: add `rollspot.apiBaseUrl=http://10.0.2.2:8787` to `Mobile/local.properties`
- Auth emails aren't sent locally; the verification link is printed in the `wrangler dev` output.

A feature is done only when the backend typechecks, the shared tests pass, **both** apps build, and the
acceptance criteria in its task file have been checked on a simulator/emulator.
