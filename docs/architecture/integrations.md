# Integrations

## Integration matrix

| Source | Destination | Protocol | Authentication | Data | Failure handling |
|---|---|---|---|---|---|
| iOS/Android shared client | Worker | HTTPS REST/JSON | Bearer for protected routes | places, profiles, reviews, saved places | GET retry; explicit mutation retry |
| Mobile media picker | Worker/R2 | HTTPS PUT JPEG | Bearer | JPEG up to 10 MB | deterministic key; no automatic write retry |
| Worker | D1 | Binding/SQL | Cloudflare binding | relational application/auth data | errors become HTTP failure; batches for related writes |
| Worker | R2 | Binding | Cloudflare binding | JPEG objects | cross-store operation is not atomic |
| Worker | Overpass | HTTPS POST, Overpass QL | none | OSM place elements | busy errors stop run; ordinary tile errors retry later |
| Better Auth | Apple/Google | Provider protocol via Better Auth | configured client credentials | identity tokens/account data | provider errors flow to auth response |
| Better Auth | Resend | HTTPS JSON | `RESEND_API_KEY` | verification/reset email | request fails; local mode logs email |
| iOS | MapKit | Apple framework | OS/service-managed | tiles, map rendering, Look Around, directions | native framework behavior |
| Android | OpenFreeMap | HTTPS style/tiles through MapLibre | none | map style and tiles | no surfaced style-load recovery |
| Website | iOS | HTTPS Universal Link/AASA | signed app association | place-link query | website fallback |
| Website | Android | custom URI scheme | none | expected `place_id` | tracked page omits required ID (**potential issue**) |

## Data contracts

- Encoding: JSON over HTTPS except raw JPEG PUTs.
- Mobile uses Kotlin serialization with `ignoreUnknownKeys=true`, `explicitNulls=false`, and
  `coerceInputValues=true`.
- Backend request payload fields are camelCase; response DTOs map snake_case using `@SerialName`.
- Database timestamps are UTC ISO-8601 text (`strftime('%Y-%m-%dT%H:%M:%fZ','now')`); Better Auth uses
  integer timestamps in its own tables.
- Contribution writes explicitly send `version: 2`; backend preserves legacy projection fields.
- Most wire-domain codes are strings, so the backend is the final enum validator.

## Verified contract findings

| Finding | Status | Evidence |
|---|---|---|
| Shared API routes match the Worker dispatch paths | Verified | `RollspotApi.kt`, `backend/src/index.ts` |
| Shared client has no methods for health/admin/direct media reads | Verified/intentional | operational or URL-driven endpoints |
| Rich V2 review fields are returned but not modeled by `PlaceReview` | Potential issue | unknown keys are discarded, so clients use legacy projections |
| `show_real_name` is stored but review output does not consult it | Potential privacy issue | `profile.ts`, `reviews.ts` |
| Reviewer dedupe uses display name rather than user ID | Potential issue | `FacilityReview.dedupeKey` |
| API base URL differs between `backend/API.md` and deployed defaults | Potential issue | custom-domain status is unknown |

## Direct mobile integrations

iOS directly uses Apple MapKit, Core Location, Photos/UIImagePickerController, Keychain, Speech (currently
unreachable), and Google Sign-In. Android directly uses MapLibre/OpenFreeMap, platform LocationManager,
System Photo Picker, Android Keystore, and Credential Manager. Neither app talks directly to Overpass or a
public OSM data API.
