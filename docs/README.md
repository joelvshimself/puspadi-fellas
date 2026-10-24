# Rollspot engineering documentation

This is the code documentation of the V1.1.

## Status labels

- **Verified** — confirmed in source, configuration, tests, or a command executed during the audit.
- **Inferred** — strongly suggested by the implementation, but not explicit.
- **Unknown** — not recoverable from the repository.
- **Potential issue** — an evidenced inconsistency or risk; not necessarily a confirmed defect.

## Start here

| Area | Document |
|---|---|
| System architecture | [`architecture/system-overview.md`](architecture/system-overview.md) |
| Components | [`architecture/components.md`](architecture/components.md) |
| End-to-end flows | [`architecture/data-flow.md`](architecture/data-flow.md) |
| Integrations | [`architecture/integrations.md`](architecture/integrations.md) |
| Deployment topology | [`architecture/deployment.md`](architecture/deployment.md) |
| Development setup | [`getting-started.md`](getting-started.md) |
| iOS | [`ios/README.md`](ios/README.md) |
| Android and parity | [`android/README.md`](android/README.md) |
| Backend internals | [`backend/README.md`](backend/README.md) |
| Relational model | [`backend/data-models.md`](backend/data-models.md) |
| API inventory | [`api/README.md`](api/README.md) |
| Security and privacy | [`security.md`](security.md) |
| Testing and quality | [`testing.md`](testing.md) |
| Deployment and runbooks | [`operations/README.md`](operations/README.md) |
| Architecture decisions | [`engineering/architecture-decisions.md`](engineering/architecture-decisions.md) |
| Technical debt | [`engineering/technical-debt.md`](engineering/technical-debt.md) |
| Partner maintenance summary | [`operations-and-failure-modes.md`](operations-and-failure-modes.md) |

## Verified inventory

| Component | Location | Technology | Responsibility | Direct dependencies |
|---|---|---|---|---|
| Backend API | [`backend/`](../backend/) | Cloudflare Worker, TypeScript 5.9, Better Auth 1.7 | HTTP API, auth, validation, grade aggregation, scheduled place sync | D1, R2, Resend, Apple, Google, Overpass |
| Shared mobile logic | [`Mobile/shared/`](../Mobile/shared/) | Kotlin 2.4, KMP, Ktor 3.6, coroutines/Flow, SKIE | API client, DTOs, state models, validation, review orchestration | Backend API |
| iOS app | [`Mobile/Rollspot/`](../Mobile/Rollspot/) | SwiftUI, MapKit, Shared static framework | Native UI, Apple map rendering, permissions, native identity and media pickers | Shared, Apple frameworks, Google Sign-In |
| Android app | [`Mobile/android/`](../Mobile/android/) | Kotlin, Compose, MapLibre 13.6 | Native UI, OSM map rendering, permissions, Credential Manager | Shared, OpenFreeMap, Google identity |
| Website | [`web/`](../web/) | Static HTML/CSS/JS, AASA | Landing and place links | Cloudflare Pages (verified from live response; deployment source unknown) |
| Database | [`backend/migrations/`](../backend/migrations/) | Cloudflare D1 / SQLite | Auth, places, reviews, signals, profiles, saved places, sync state | Worker |
| Media | R2 binding in [`wrangler.jsonc`](../backend/wrangler.jsonc) | Cloudflare R2 | Review photos and avatars | Worker |

## Boundaries

Business rules and all backend calls are intended to live in `Mobile/shared`; iOS and Android remain
native presentation layers. Verified exceptions and legacy code are recorded in
[`engineering/technical-debt.md`](engineering/technical-debt.md).

No WebSocket, GraphQL, gRPC, message queue, push-notification service, offline database, or mobile
background worker is implemented in the inspected repository.
