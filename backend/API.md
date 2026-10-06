# Rollspot API (Cloudflare Worker)

Base URL: `https://api.rollspot.app` in production, `http://localhost:8787` with `npm run dev`
(the Android emulator reaches it at `http://10.0.2.2:8787`).

The Kotlin client in `Mobile/shared/.../api/RollspotApi.kt` mirrors this file. **Change both in the same PR.**

## Conventions
- JSON in and out. Errors are `{ "error": "<code>", "message": "<human readable>" }` with a 4xx/5xx status.
- **Auth:** `Authorization: Bearer <session token>`. A token comes back in the `set-auth-token` response header
  from any Better Auth sign-in. 🔒 marks routes that need it.
- **Place keys:** wherever a path or body takes a place, it accepts the Rollspot place ID (UUID) *or*
  `osm:<node|way|relation>/<id>`. URL-encode the slash in paths: `osm:way%2F520645071`.
- Places come from our own directory (`places` table), which is refreshed from OpenStreetMap by a weekly
  cron. Apps must show "© OpenStreetMap contributors" wherever they show place data.

## Places
| Method | Path | Notes |
|---|---|---|
| GET | `/v1/places/nearby?lat&lng&radius=5000` | Up to 80 places, nearest first. radius 500–20000 m. → `{ places: Place[], attribution }` |
| GET | `/v1/places/search?q&lat?&lng?` | Prefix full-text search over name + address, nearer first when lat/lng are given. → `{ places: Place[], attribution }` |
| GET | `/v1/places/:key` | → `{ place: Place }` |
| GET | `/v1/places/:key/accessibility` | → `{ place: Place, grade: FeatureGrade[] }` |
| GET | `/v1/places/:key/photos` | Curated place photos → `PlacePhoto[]` |
| GET | `/v1/places/:key/reviews` | Up to 100 reviews, newest first → `{ reviews: PlaceReview[] }` |
| GET | `/v1/places/:key/review-photos` | → `{ placeId, photos: { url, facility, label, caption }[] }` |

```jsonc
// Place
{ "id": "uuid", "osm_ref": "way/520645071", "name": "Beachwalk Bali", "category": "mall",
  "lat": -8.71, "lng": 115.16, "address": "Jalan Pantai Kuta, Kuta", "phone": null, "website": null,
  "opening_hours": "10:00-22:00", "osm_wheelchair": "yes" | "limited" | "no" | null,
  "grade": FeatureGrade[] }
// FeatureGrade: one per reviewed feature
{ "feature": "entrance" | "elevator" | "restroom", "best_value": "yes" | "limited" | "no", "confidence": 0.75 }
```

## Saved places 🔒
| Method | Path | Notes |
|---|---|---|
| GET | `/v1/saved-places` | → `{ place_ids: string[], places: Place[] }`, newest first |
| PUT | `/v1/saved-places/:key` | 204 |
| DELETE | `/v1/saved-places/:key` | 204 |

## Reviews
| Method | Path | Notes |
|---|---|---|
| POST 🔒 | `/v1/reviews` | Body below. Idempotent per `submissionId`: a retry returns the original review. → `{ reviewId, placeId, grade }` |
| GET 🔒 | `/v1/me/reviews` | → `{ userName, userRole, profileImageUrl, reviews: { id, placeId, placeName, createdAt, reviewText, providedFeatures, photoUrls, photoCaptions }[] }` |
| DELETE 🔒 | `/v1/reviews/:id` | Own reviews only. 204 |
| PUT 🔒 | `/v1/media/review-photos/:placeKey/:facility/:photoId` | Raw `image/jpeg` body ≤ 10 MB. facility ∈ lobby, basement, elevator, toilet, exit_side, other, uploads. Same photoId = overwrite (safe retry). → `{ url }` |
| GET | `/v1/media/:objectKey` | Photo bytes |

```jsonc
// POST /v1/reviews
{ "submissionId": "client-generated uuid, reused on retry",
  "placeId": "uuid or osm:way/123",
  "entrances": [{ "location": "lobby" | "basement" | "exit_side" | "other",
                  "hasDropoffRamp": true, "hasRails": null, "doorType": "manual" | "automatic" | null,
                  "isWideEnough": true, "review": Note | null }] | null,
  "elevator": { "exists": true, "wheelchairAccessible": false, "blockers": ["no_ramp", "too_small"], "review": Note | null } | null,
  "toilet": { "hasDisabledToilet": true, "review": Note | null } | null }
// Note: photoUrls are the `url`s returned by the media upload
{ "text": "string | null", "photoUrls": ["…"], "photoCaptions": ["…"] }
```

## Profile 🔒
| Method | Path | Notes |
|---|---|---|
| GET | `/v1/profile` | → `Profile` (created on first call) |
| PATCH | `/v1/profile` | `{ displayName?, mobilityAids?: string[], showRealName? }` → `Profile` |
| PUT | `/v1/profile/avatar` | Raw `image/jpeg` ≤ 5 MB → `{ url }` |

`Profile`: `{ id, display_name, avatar_url, mobility_aids: string[], pseudonym, show_real_name }`

## Auth
Better Auth routes live under `/api/auth/*`. The ones the apps use:

| Method | Path | Body | Notes |
|---|---|---|---|
| POST | `/v1/auth/email-registered` | `{ email }` | → `{ registered }`. Drives "sign in" vs "create account". |
| POST | `/api/auth/sign-up/email` | `{ name, email, password, callbackURL }` | Sends a verification email. No session until verified. |
| POST | `/api/auth/send-verification-email` | `{ email, callbackURL }` | Resend. |
| POST | `/api/auth/sign-in/email` | `{ email, password }` | `set-auth-token` header. 403 if the email isn't verified. |
| POST | `/api/auth/sign-in/social` | `{ provider: "apple" \| "google", idToken: { token, nonce? } }` | Native ID-token sign-in. `set-auth-token` header. |
| GET 🔒 | `/api/auth/get-session` | | → `{ user, session }` or `null` |
| POST 🔒 | `/api/auth/change-password` | `{ currentPassword, newPassword, revokeOtherSessions }` | |
| POST 🔒 | `/api/auth/sign-out` | | |
| GET 🔒 | `/v1/auth/providers` | | → `{ providers: ["credential", "google", "apple"] }` |

`callbackURL` is `puspadi://auth/callback`: the verification link opens the app on both platforms.

## Admin
| Method | Path | Notes |
|---|---|---|
| POST | `/v1/admin/sync-places` | `Authorization: Bearer $ADMIN_TOKEN`. Runs the OSM place sync now (the cron runs Mondays 03:00 UTC). Regions are rows in `sync_regions`. |
