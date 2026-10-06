# Rollspot technical specification

## Product boundary

Rollspot helps mobility-impaired users discover places and exchange structured, first-hand accessibility observations. Place discovery and rendering are Apple Maps-only. Rollspot does not aggregate third-party place or accessibility datasets.

## Place data

`MKLocalSearch` supplies live search results. `MKMapItem.Identifier` is the stable `apple_place_id` used to associate community reviews, saved-place records, photos, and grades. The server must not persist Apple place names, coordinates, addresses, contact details, imagery, or category metadata.

Saved places are resolved again with `MKMapItemRequest` when needed. Temporary in-process values are permitted for UI continuity but are not a durable place-data cache.

## Accessibility grade

Each authenticated contributor has at most one current signal for a place and feature. A later review updates that contributor's signal instead of multiplying their weight. For each feature, the API chooses the value with the most contributor votes and reports confidence as the winning count divided by all current votes. Unknown means no community signal exists.

Supported features are entrance, elevator, and restroom. Supported values are yes, no, and limited.

## Reviews and media

Reviews are normalized into a review row, entrance rows, photo rows, and accessibility signals. Every submission has a client-generated `submission_id`; `(user_id, submission_id)` is unique. Replaying the same request returns the existing review.

JPEG media uploads use deterministic R2 keys. Metadata and ownership live in D1. Review reads are public; writing, deleting, saving, and profile operations require a bearer session.

## Authentication

Better Auth owns its user, session, account, and verification tables in D1. Supported methods are:

- Sign in with Apple using the native Apple identity token and nonce.
- Google Sign-In using the native Google identity token.
- Email and password with required email verification and transactional email through Resend.

The app stores only the Better Auth bearer token in Keychain. Passwords and provider secrets never enter application tables or the iOS bundle.

## Caching and concurrency

Worker JSON and media responses are sent with `Cache-Control: no-store`. UI-level image reuse may remain memory-bound for rendering performance, but database and place-record responses are fetched explicitly. Controls disable during writes, client services reject overlapping mutations for the same entity, and database constraints make retries safe.

## Deployment requirements

- iOS 18 or newer
- Cloudflare Workers, D1, and R2
- Apple developer credentials for Sign in with Apple
- Google OAuth web and iOS client IDs
- Resend API key and a verified sender domain
