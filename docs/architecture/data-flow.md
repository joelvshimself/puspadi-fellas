# End-to-end data flows

## Startup and session restoration

```mermaid
sequenceDiagram
  participant OS
  participant App as Native app
  participant SDK as RollspotSdk/AuthModel
  participant Store as Keychain/Keystore
  participant API as RollspotApi
  participant Auth as Better Auth
  OS->>App: launch
  App->>SDK: create once
  App->>SDK: restore()
  SDK->>Store: load token
  SDK->>API: GET /api/auth/get-session
  API->>Auth: bearer token
  Auth-->>API: session or 401/null
  API-->>SDK: current user
  SDK-->>App: AuthSession StateFlow
```

iOS starts with `SplashScreenView`; Android restores in `RollspotApplication.appScope`. User-specific saved,
profile, and review state is cleared when the shared session becomes signed out.

## Place discovery and detail

```mermaid
sequenceDiagram
  actor User
  participant View as Native map/search view
  participant Model as MapModel
  participant Repo as PlaceRepository
  participant API as RollspotApi
  participant Worker as places.ts
  participant DB as D1
  User->>View: move map or search
  View->>Model: update viewport/query
  Model->>Repo: nearby/search
  Repo->>API: request
  API->>Worker: GET /v1/places/nearby or search
  Worker->>DB: bounds or FTS query plus signals
  DB-->>Worker: rows
  Worker-->>API: JSON places and grades
  API-->>Model: domain places
  Model-->>View: MapState/pins
```

Selecting a Rollspot place creates `PlaceDetailModel`, which concurrently requests the place, venue
photos, review photos, and reviews. MapKit/OpenFreeMap provide map visuals, not the place directory.

## Authentication

Native Apple/Google controls obtain an identity token; `AuthModel` sends it to
`POST /api/auth/sign-in/social`. Email flows use Better Auth email routes and Resend verification.
The returned bearer token is stored in iOS Keychain or encrypted with Android Keystore. Authenticated
requests attach `Authorization: Bearer`.

**Recovery:** client validation prevents malformed forms; provider/server failures become `ApiException`.
Sign-out clears local state even if the remote sign-out fails. A potential stale-token path remains when
`get-session` returns 401/null without `RollspotApi` clearing storage.

## Contribution and persistence

```mermaid
sequenceDiagram
  actor User
  participant UI as Native contribute UI
  participant Flow as ContributeFlow
  participant Review as ReviewModel
  participant API as RollspotApi
  participant Media as Worker media.ts/R2
  participant Handler as reviews.ts/contribution.ts
  participant DB as D1
  User->>UI: answer sections and select photos
  UI->>Flow: actions
  Flow-->>UI: next step and validation state
  UI->>Review: submit stable submissionId
  loop Up to 3 uploads concurrently
    Review->>API: JPEG bytes and stable fileId
    API->>Media: PUT /v1/media/review-photos/...
    Media->>Media: R2 put
    Media->>DB: upsert media_uploads
  end
  Review->>API: contribution version 2
  API->>Handler: POST /v1/reviews
  Handler->>DB: validate and batch normalized rows/signals
  Handler-->>API: review and grades
  API-->>Review: submitted
  Review-->>UI: success state
```

`UNIQUE(user_id, submission_id)` prevents duplicate reviews. Deterministic object keys make repeated
uploads overwrite the same object. Writes are not automatically retried; the UI must reuse the same
submission. D1 and R2 cannot form one transaction, so partial failures can leave orphaned objects.

## Save/profile mutations

Saved-place toggles and profile changes update shared state optimistically and roll back on failure.
The Worker authenticates with `requireUserId`, performs D1 writes, and returns the authoritative model.

## Background place sync

```mermaid
sequenceDiagram
  participant Cron as Worker scheduled handler
  participant Sync as syncDueTiles
  participant OSM as Overpass API
  participant DB as D1
  Cron->>Sync: every 10 minutes
  Sync->>DB: select up to 10 overdue tiles
  loop each tile
    Sync->>OSM: Overpass QL full/incremental query
    OSM-->>Sync: OSM elements
    Sync->>DB: upsert places and tile status
  end
```

Each populated tile is normally revisited after seven days; empty tiles after 28. Overpass busy responses
stop the run and leave tiles due. There is no alternate provider or lock between manual and cron runs.

## Failure scenarios

| Scenario | Implemented response |
|---|---|
| No network / timeout | Shared GET retries twice; mutations expose error and require explicit retry |
| Auth expired | Auth/session state becomes signed out; protected requests return 401 |
| Server unavailable | `ApiException`; map/detail surfaces retry, some profile/saved paths suppress errors |
| Malformed response | Kotlin serialization fails; `ignoreUnknownKeys` tolerates added fields |
| Third party down | Auth/email operation fails; Overpass delays directory freshness; Android map tiles may be blank |
| Duplicate write | Review ID constraint, deterministic media keys, and idempotent saved PUT/DELETE protect retries |
| Local/remote disagreement | No offline database; reload replaces in-memory state, optimistic writes roll back |
| Realtime/cross-device update | None; clients reload on screen lifecycle or explicit actions |
