# Testing and reliability

## Existing verification

| Layer | Framework/task | Coverage observed | Audit result |
|---|---|---|---|
| Backend | `npm test`, `npm run check` | TypeScript type-check only | Passed by audit agent |
| Shared KMP | `commonTest` Kotlin tests | API retry/auth headers, auth/map/place/profile/saved/review logic, contribution rules | 117 common + 3 gated live tests found; not rerun in one audit environment |
| Live backend | `LiveBackendTest` | full account/place/save/photo/review/idempotency/profile/delete journey | Runs only with environment variables |
| Android | `assembleDebug`, `testDebugUnitTest` | compilation; no Android app test sources | Passed during audit |
| iOS | Xcode app target | no unit/UI test target | Build not conclusively rerun during audit |
| Web | none | none | static inspection/live AASA check only |

No CI workflow, coverage reporter, backend runtime test runner, screenshot tests, or end-to-end mobile UI
suite is tracked.

## Feature coverage map

| Feature | Shared tests | Backend runtime tests | iOS tests | Android tests |
|---|---|---|---|---|
| Auth state/validation | Yes | No | No | No |
| API retry/error mapping | Yes | No | No | No |
| Place map/filter/detail | Yes | No | No | No |
| Accessibility grade rules | Yes | No | No | No |
| Contribution state/payload/idempotency | Yes | No | No | No |
| Saved/profile optimistic behavior | Yes | No | No | No |
| Secure storage | No | No | No | No |
| Deep links | No verified coverage | No | No | No |
| Cron/import | No | No | N/A | N/A |
| D1 migrations/constraints | Live journey partially | No dedicated test | N/A | N/A |

## Highest-value missing tests

- Backend handler and migration integration tests, including auth/ownership/error shapes.
- Public review identity test proving `show_real_name` is honored.
- V2 structured review read contract and per-pass photo attribution.
- R2/D1 partial-failure and orphan recovery.
- Token clearing on session 401/null and secure-store failures.
- Android route encoding for `osm:way/123`; web-to-app place link.
- iOS raw MapKit selection behavior and profile photo add path.
- Cron tile lease/concurrency and Overpass busy/oversize behavior.
- Both-app smoke UI tests for search, sign-in, contribution, and account deletion.

## Reliability mechanisms

Implemented: GET network retry, stable write IDs, mutation gates, database uniqueness, optimistic rollback,
bounded photo concurrency, scheduled retry through due tiles, and app state reload.

Absent: server retries/backoff for normal API requests, circuit breakers, queues, dead-letter handling,
realtime sync, offline persistence, synthetic monitoring, alerting, and tested disaster recovery.

## Commands

See [`getting-started.md`](getting-started.md). A feature is considered complete by repository convention
only after backend type-check, shared tests, both app builds, and simulator/emulator acceptance checks.
