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
| GET | `/v1/reviews/:id` | One review (same shape as items in `/v1/places/:key/reviews`) plus `placeId`. → `{ placeId, review }` |
| GET 🔒 | `/v1/me/reviews` | → `{ userName, userRole, profileImageUrl, reviews: { id, placeId, placeName, createdAt, reviewText, providedFeatures, photoUrls, photoCaptions }[] }` |
| DELETE 🔒 | `/v1/reviews/:id` | Own reviews only. 204 |
| PUT 🔒 | `/v1/media/review-photos/:placeKey/:submissionId/:fileId` | Raw `image/jpeg` body ≤ 10 MB. Reuse the review's `submissionId` and a stable per-photo `fileId`; same pair overwrites (safe retry). Facility is set on `POST /v1/reviews`, not in this path. → `{ url }` |
| GET | `/v1/media/:objectKey` | Photo bytes |

```jsonc
// POST /v1/reviews — version 2 is the contribute flow. Omit version for the legacy body below.
{ "version": 2,
  "submissionId": "client-generated uuid, reused on retry",
  "placeId": "uuid or osm:way/123",
  "persona": "wheelchair" | "secondary",   // optional; otherwise taken from the profile
  "entrance": { "passes": [EntrancePass], "notes": "string | null" } | omitted,
  "elevator": { "passes": [ElevatorPass], "notes": "string | null" } | omitted,
  "toilet": { "passes": [ToiletPass], "notes": "string | null" } | omitted,
  "pathways": { "notices": [Notice], "photos": [Photo], "notes": "string | null" } | omitted,
  "seating": { "answer": Answer, "photos": [Photo], "notes": "string | null" } | omitted,
  "parking": { "answer": Answer, "photos": [Photo], "notes": "string | null" } | omitted,
  "final": { "text": "string | null", "photos": [Photo] } | omitted }
// notes is the optional descriptive review written at the end of that section (max 4000 characters).
// The apps no longer send final; it remains accepted for older clients.
// Photo is { "url": "<url from the media upload>", "caption": "" }
// At least one of entrance, elevator, toilet, pathways, seating, parking is required.
// A pass is one entrance, elevator, or toilet the contributor reviewed.
// Evidence photos (kind "evidence") are allowed only on an answer of not_sure,
// and at most 3 per pass across all of that pass's questions.
// Section photos (the "Take or upload a photo" screen) are at most 5 per pass.
// Final photos are at most 5. A review holds at most 60 photos, each owned by
// this user and this submissionId.

// EntrancePass: { "photos": [Photo], "points": [Point] }  // 1–10 passes, 1–2 points, locations unique
// Point: { "location": "lobby" | "basement", "tags": [Tag], "ramp": Ramp | null, "handrail": Handrail | null,
//          "evidence": { "ramp": [Photo], "handrail": [Photo] } }
// Tag (lobby): ramp, handrail, automatic_doors, manual_doors, security_assistance, wheelchairs_available
// Tag (basement): elevator, disabled_parking, ramp, handrail, security_assistance
// ramp is required exactly when tags contain ramp. Same for handrail.
// Ramp: yes | with_push | too_steep | not_sure
// Handrail: yes | with_effort | no | not_sure

// ElevatorPass: { "photos": [Photo], "wideEntrance": Tri, "spaceToManeuver": Tri | null,
//   "reachableButtons": Tri | null, "location": "string | null",
//   "evidence": { "wideEntrance": [Photo], "spaceToManeuver": [Photo], "reachableButtons": [Photo] } }
// Tri: yes | no | not_sure. space and buttons are omitted when wideEntrance is no, and required otherwise.

// ToiletPass: { "photos": [Photo], "door": "manual" | "sliding" | "automatic",
//   "seat": "yes" | "too_low" | "too_high" | "not_sure",
//   "grabBars": "yes" | "awkward" | "no" | "not_sure",
//   "space": Tri, "sink": Tri, "emergency": "yes" | "no" | "not_sure" | "none",
//   "location": "string | null",
//   "evidence": { "seat": [Photo], "grabBars": [Photo], "space": [Photo], "sink": [Photo], "emergency": [Photo] } }

// Notice: loose_surface | rough_surface | tight_gap | narrow_path | steep_section | curb_no_ramp | nothing_notable
// nothing_notable cannot be combined with another notice. Answer: yes | no | not_sure.

// Legacy POST /v1/reviews (gallery uploads and older apps)
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

Reads keep the legacy fields and, for version 2, add `schema_version`, `persona`, `final_text`,
`final_photos`, `entrance_passes`, `elevator_passes`, `toilet_passes`, `areas`, and `section_notes`.
`section_notes` is `{ entrance, elevator, toilet, pathways, seating, parking }`, each a string or null.
Each photo is
`{ url, caption, section, kind, question, pass_index, location }`. `kind` is `section`, `evidence`,
`final`, or `legacy`.

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
