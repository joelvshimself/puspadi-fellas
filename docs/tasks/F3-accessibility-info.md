# F3: Accessibility information (place detail)

## Goal
The place page shows how accessible a place is: an overall grade, a facility breakdown (entrances,
elevator, toilet), notes from reviews, review photos and the AI summary. It's identical in content on both apps.

## Today
- Backend: `GET /v1/places/:id/accessibility | photos | reviews | review-photos` (`src/places.ts`, `src/reviews.ts`).
- iOS logic: `Services/AccessibilityService.swift`, `ReviewService.fetchPlaceReviews` + `mapReviews`,
  dedupe, `collapseRepeatVisits` and tag builders (`ReviewService.swift` lines 329–533),
  `PlaceReviewStore.swift`, `PlacePhotoService.swift`, `PlaceAISummaryService.swift` (currently hard-coded
  summaries + on-device synthesis), `Models/AccessibilityGrade.swift`, `PlaceFacilityReview.swift`.
- iOS views: `Views/Detail/*`, `Views/Facilities Details/*`, `Views/Photos/FacilityPhotosView.swift`,
  `FacilityPhotoDetailView.swift`.
- Android: `ui/screens/place/PlaceDetailScreen.kt` + `PlaceDetailViewModel.kt` (Supabase, partial).

## Backend
- [ ] Optional: move the AI summary server-side (`GET /v1/places/:id/summary`, generated from reviews and
      cached in D1) so both apps show the same text. Otherwise remove the hard-coded summaries.

## Shared
- [ ] `place/PlaceDetailModel(placeId)`: loads accessibility, reviews, photos and summary in parallel.
      State is `Loading | Loaded(...) | Empty("not reviewed yet") | Error`.
- [ ] Port `mapReviews`, dedupe, `collapseRepeatVisits`, entrance/elevator/toilet tag builders and date
      labels from `ReviewService.swift` into shared, with unit tests built from real API responses.
- [ ] Facility breakdown and "notes from reviews" grouping.

## iOS
- [ ] `PlaceDetailView`, `FacilityReviewedOverview`, `FacilityReviewsList`, `NotReview`,
      `NotesFromReviewsSection` and `ReviewPhotosSection` render shared state. Delete the Swift mapping code.

## Android
- [ ] Place detail screen with the same sections and order as iOS (follow the Figma place-detail frames).
- [ ] Facility reviews list, photos grid and full-screen photo viewer.

## Acceptance criteria
- For the same place, both apps show the same grade, the same review count, the same notes and the same photos.
- A place with no reviews shows the "not reviewed yet" state with a Contribute button (that hands off to F4).
- The mapping logic is in shared, and neither app contains a copy.
