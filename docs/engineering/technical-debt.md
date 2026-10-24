# Technical debt

## High

| Finding | Evidence | Impact |
|---|---|---|
| Public reviews ignore `show_real_name` | `profiles` stores it; `reviewOutput` does not read it | User privacy preference may not be honored |
| Android place IDs are not route-encoded | Navigation interpolates IDs containing `/` | OSM-key detail/contribute routes may fail |
| Tracked Android open-app link omits required `place_id` | `web/place/index.html` vs `MainActivity.handleDeepLink` | Button cannot resolve place |
| Raw MapKit POI can produce `preview:<UUID>` | iOS selection/model code vs server place-key requirement | Detail/review API requests likely 404 |

## Medium

| Finding | Evidence / consequence |
|---|---|
| Backend has no runtime tests | `npm test` is TypeScript compilation only |
| No CI/CD or production observability | no workflows; logs/health only |
| V2 review read model is discarded | client `PlaceReview` omits structured fields and ignores unknowns |
| D1/R2 operations are non-atomic | orphaned media possible on partial failure |
| Account enumeration | public email-registration check reveals existence |
| No application rate limiting | auth/upload/admin surfaces depend on external controls, if any |
| Android draft is volatile | process death loses answers/photos/submission ID |
| iOS Google config is placeholder | provider fails unless release process substitutes values |
| iOS profile add-photo flow incomplete | state exists without handler/upload |
| Web deployment drift | deployed Pages content differs from tracked web files |
| OSM removals never delete places | incremental/full sync only upserts |
| Cron/manual sync can race | no tile lease/lock |

## Low / maintainability

- Legacy/unreferenced iOS clients, screens, and services remain.
- Live production Swift types retain `Mock` names.
- Android strings are only partially localized.
- Android release minification is disabled; Gradle 10 deprecations are reported.
- Xcode shared-framework phase has no declared inputs/outputs and runs every build.
- Reviewer dedupe uses display name rather than stable user identity.
- Several profile/saved failures become empty states instead of visible errors.
- Unexpected backend errors expose their message.
- Media upload buffers entire request before size validation.
- API documentation and cron comments have drifted from configuration.

## Recommended order

1. Correct reviewer identity privacy and broken place-link/ID flows.
2. Add contract/backend tests around auth, contribution, review output, and migrations.
3. Add request correlation, structured logging, health/sync alerting, and rate limits.
4. Reconcile V2 read DTOs and remove verified legacy code.
5. Define R2 orphan reconciliation and D1 recovery procedures.
6. Establish CI, release provenance, and documented mobile signing custody.
