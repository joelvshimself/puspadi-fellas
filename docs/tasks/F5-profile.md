# F5: Profile, saved places, my reviews

## Goal
The profile tab on both apps: account details, avatar, mobility profile, change password, my reviews
(with delete), my photos, saved places, about and settings (including language).

## Today
- Backend: `GET/PATCH /v1/profile`, avatar upload `/v1/profile/avatar` (`src/profile.ts`),
  `/v1/saved-places` (`src/places.ts`), `GET /v1/me/reviews`, `DELETE /v1/reviews/:id`.
- iOS logic: `Services/ProfileService.swift`, `SavedPlacesService.swift`, `SavedPlaceSnapshotStore.swift`,
  `ReviewService.fetchMyReviews/deleteMyReview`, `LanguageManager.swift`, `Models/MobilityProfile.swift`.
- iOS views: `Views/Profile/*` (ProfileView, ProfileTab, MyAccount, MobilityProfileSheet,
  ChangePasswordSheet, ProfileReviews, ProfilePhotos, ProfileSettings, AboutApp), `Views/Saved/SavedView.swift`.
- Android: `ui/screens/saved/SavedScreen.kt` (Supabase). There's no profile screen.

## Shared
- [ ] `profile/ProfileModel`: profile load and update (display name, mobility aids), avatar upload (bytes in),
      and change password (via `AuthRepository`).
- [ ] `profile/MyReviewsModel`: list, delete with optimistic removal + rollback, and my photos.
- [ ] `saved/SavedPlacesModel`: saved IDs, toggle save (optimistic), and an offline snapshot of saved places
      (port `SavedPlaceSnapshotStore`). `isSaved(placeId)` is used by F3's save button.
- [ ] Mobility aid options list in shared, so both apps offer the same choices.

## iOS
- [ ] Profile views and SavedView render the shared models. Delete `ProfileService`/`SavedPlacesService` logic.

## Android
- [ ] Profile tab, my account, mobility sheet, change password, my reviews, my photos, settings/about,
      and the Saved screen. Follow the Figma profile frames.

## Acceptance criteria
- Changing the mobility profile or avatar on one app shows up on the other after a refresh.
- Saving a place on Android shows it as saved on iOS.
- Deleting a review in "My reviews" removes it from the place page (F3) on both apps.
