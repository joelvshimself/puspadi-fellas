# API reference

Implementation authority: [`backend/src/index.ts`](../../backend/src/index.ts) and its handlers. Client
authority: `Mobile/shared/.../api/RollspotApi.kt`. The manually maintained
[`backend/API.md`](../../backend/API.md) contains detailed payload examples but has known cron/base-URL
drift. No OpenAPI specification is generated, and Better Auth owns a dynamic `/api/auth/*` surface.

Common error shape:

```json
{"error":"error_code","message":"Human-readable message."}
```

Protected routes require `Authorization: Bearer <session-token>`. JSON responses use `no-store`.

## Inventory

| Method / route | Purpose | Auth / authorization | Inputs | Success | Known errors | Consumers | Source |
|---|---|---|---|---|---|---|---|
| `GET /health` | Liveness | Public | none | `{"status":"ok"}` | 500 | Operations | `index.ts` |
| `POST /v1/auth/email-registered` | Check account existence | Public | JSON `email` | `registered` boolean | 400/415 | Both apps | `index.ts` |
| `GET /v1/auth/providers` | Linked provider IDs | Bearer/self | header | provider list | 401 | Both apps | `index.ts` |
| `GET /v1/profile` | Current profile | Bearer/self | header | profile DTO | 401 | Both apps | `profile.ts` |
| `PATCH /v1/profile` | Update profile fields | Bearer/self | name/mobility/visibility | profile DTO | 400/401 | Both apps | `profile.ts` |
| `PUT /v1/profile/avatar` | Replace avatar | Bearer/self | JPEG, max 5 MB | profile/avatar response | 400/401/413/415 | Both apps | `profile.ts` |
| `GET /v1/saved-places` | List bookmarks | Bearer/self | none | places list | 401 | Both apps | `places.ts` |
| `PUT /v1/saved-places/:key` | Save place | Bearer/self | Rollspot/OSM key | saved state | 400/401/404 | Both apps | `places.ts` |
| `DELETE /v1/saved-places/:key` | Unsave place | Bearer/self | key | saved state | 400/401 | Both apps | `places.ts` |
| `POST /v1/reviews` | Submit legacy or V2 review | Bearer/self | review JSON | existing/new review and grades | 400/401/404 | Both apps | `reviews.ts`, `contribution.ts` |
| `GET /v1/reviews/:id` | Read review | Public | review UUID | review DTO | 400/404 | Both apps | `reviews.ts` |
| `DELETE /v1/reviews/:id` | Delete own review | Bearer/owner | review UUID | status | 401/403/404 | Both apps | `reviews.ts` |
| `GET /v1/me/reviews` | Current user's reviews | Bearer/self | none | profile + review list | 401 | Both apps | `reviews.ts` |
| `DELETE /v1/me` | Delete account | Bearer/self | none | deleted status | 401/500 | Both apps | `account.ts` |
| `PUT /v1/media/review-photos/:place/:submission/:file` | Upload staged photo | Bearer/self | JPEG max 10 MB | object URL/key metadata | 400/401/404/413/415 | Both apps | `media.ts` |
| `GET, HEAD /v1/media/:objectKey` | Read media | Public | object key | JPEG/body metadata | 404 | URL consumers | `media.ts` |
| `POST /v1/admin/sync-places` | Run directory sync | Admin bearer | `tiles=1..200`, optional `region` | per-tile results | 401/405 | Operator | `sync.ts` |
| `GET /v1/places/nearby` | Nearby directory | Public | `lat`,`lng`,`radius` | places list | 400 | Both apps | `places.ts` |
| `GET /v1/places/search` | Search directory | Public | `q`, optional location/radius | places list | 400 | Both apps | `places.ts` |
| `GET /v1/places/:key` | Place detail | Public | Rollspot UUID or `osm:type/id` | place DTO | 400/404 | Both apps | `places.ts` |
| `GET /v1/places/:key/accessibility` | Grade detail | Public | key | feature grades | 400/404 | Legacy iOS only, currently unused | `places.ts` |
| `GET /v1/places/:key/photos` | Venue photos | Public | key | photo list | 400/404 | Both apps | `places.ts` |
| `GET /v1/places/:key/reviews` | Place reviews | Public | key | review list | 400; missing place may return empty | Both apps | `reviews.ts` |
| `GET /v1/places/:key/review-photos` | Flattened review photos | Public | key | photo list | 400; missing place may return empty | Both apps | `reviews.ts` |

## Better Auth routes used by clients

| Method / path | Purpose |
|---|---|
| `POST /api/auth/sign-up/email` | Create email account |
| `POST /api/auth/send-verification-email` | Send/resend verification |
| `POST /api/auth/sign-in/email` | Email/password sign-in |
| `POST /api/auth/sign-in/social` | Apple/Google identity token sign-in |
| `GET /api/auth/get-session` | Restore current session |
| `POST /api/auth/change-password` | Change password |
| `POST /api/auth/sign-out` | Revoke/sign out session |

Exact Better Auth request/error schemas and additional vendor routes are **Unknown** without treating the
installed package as a public Rollspot contract.

## Key request contracts

Nearby requires numeric `lat`/`lng`; radius defaults to 5,000 and is clamped to 500–20,000. Search requires
`q`. Place keys must be a Rollspot UUID or accepted OSM reference.

V2 contribution shape is defined by shared `ContributionSubmission` and parsed by
`parseContributionV2`. It includes:

```json
{
  "version": 2,
  "submissionId": "client-stable-uuid",
  "placeId": "rollspot-place-id",
  "persona": "wheelchair",
  "entrances": [],
  "elevators": [],
  "toilets": [],
  "areas": {},
  "sectionNotes": {},
  "finalText": null
}
```

Arrays/objects contain structured answers and staged media URLs. Allowed codes and size/count bounds are
validated in `backend/src/contribution.ts`; clients should use `ContributeCodes` rather than free strings.

## Compatibility

- API namespace is `/v1`; Better Auth uses `/api/auth`.
- Unknown response fields are ignored by clients.
- Required DTO fields and invalid types fail decoding.
- V2 responses currently include structured data the mobile `PlaceReview` DTO discards.
- Writes must retain stable `submissionId` and photo `fileId` across explicit retries.

## Security notes

The public email-existence endpoint permits account enumeration. Media reads and reviews are public.
There is no application rate limiter. See [`../security.md`](../security.md).
