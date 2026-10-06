# Rollspot

Rollspot is an iOS accessibility guide for finding places and sharing first-hand information about entrances, elevators, and toilets.

## Architecture

- **Maps and place search:** Apple MapKit only. The iOS app renders maps, searches, resolves saved places, and opens directions with Apple Maps.
- **Place identity:** the backend persists only `MKMapItem.Identifier` values. Names, addresses, coordinates, phone numbers, websites, and Apple imagery stay in MapKit and are not copied into the database.
- **API:** a Cloudflare Worker in `backend/src`.
- **Database:** Cloudflare D1 with normalized review, facility, signal, profile, and saved-place tables.
- **Media:** Cloudflare R2 for avatars and review photos.
- **Authentication:** Better Auth on the Worker supports Sign in with Apple, Google Sign-In, and verified email/password accounts. The native app stores its bearer session in Keychain.

The minimum deployment target is iOS 18 because stable Apple Place IDs were introduced there.

## iOS app

Open `Mobile/Rollspot.xcodeproj` in Xcode. Before running authentication against a deployed backend, configure:

1. `ROLLSPOT_API_BASE_URL` in `Mobile/Info.plist`.
2. `GOOGLE_IOS_CLIENT_ID` and the reversed-client-ID URL scheme in `Mobile/Info.plist`.
3. Sign in with Apple for the `com.puspadifellas.app` App ID and signing target.

The project uses Swift Package Manager for Google Sign-In. Apple authentication and MapKit are system frameworks.

## Cloudflare backend

```sh
cd backend
npm install
npm run check
npm run db:migrate:local
npm run dev
```

For a new Cloudflare environment:

1. Create a D1 database and replace the placeholder `database_id` in `backend/wrangler.jsonc`.
2. Create the `rollspot-media` R2 bucket.
3. Copy `backend/.dev.vars.example` to `.dev.vars` for local work.
4. Set production secrets with `wrangler secret put` for `BETTER_AUTH_SECRET`, Apple credentials, Google credentials, and `RESEND_API_KEY`.
5. Set `API_BASE_URL` and the allowed provider client IDs in `wrangler.jsonc`.
6. Run `npm run db:migrate:remote`, then `npm run deploy`.

Never place provider secrets in the iOS app. Only the public Google iOS client ID belongs there.

## Mutation safety

Review submissions carry a stable UUID and D1 enforces one submission per user and UUID. Save/remove endpoints are idempotent. The client also disables or gates an action while it is in flight, so a repeated tap cannot create a second mutation.

API responses use `Cache-Control: no-store`. Saved place display data is resolved from Apple Maps instead of being persisted or served from a stale cross-session cache.
