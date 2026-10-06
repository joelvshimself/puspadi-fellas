# F4: Contribute: review forms & photos

## Goal
Anyone signed in can review a place on either app: lobby and basement entrances (ramps/rails, door type,
ease of access), elevator (presence, wheelchair fit, blockers), toilet, notes, and photos with captions.
The wizard logic and the submission are shared. Only the form controls are native.

## Today
- Backend: `POST /v1/reviews`, `GET/DELETE /v1/reviews/:id`, photo upload
  `PUT /v1/media/review-photos/:place/:submission/:file` (`src/reviews.ts`, `src/media.ts`).
- iOS logic: `Models/ReviewDraft.swift` (enums: EntranceLocation, DoorType, EaseOfAccess, ElevatorBlocker;
  drafts; the `ReviewStep` sequence), `ReviewSubmissionPayload.swift`, `ContributeReviewTags.swift`,
  `ReviewQuestionCopy.swift`, `ReviewService.submit` + photo upload orchestration,
  `UnfinishedReviewStore.swift` (resume later), `ImageStore.swift`.
- iOS views: `Views/Review/*` (wizard + step views), `Views/Contribute/ContributeView.swift`,
  `Views/Photos/AddPhotosView.swift`, `PhotoComposerFlow.swift`, `Views/Analysing/AnalysingView.swift`.
- Android: `ui/screens/contribute/ContributeScreen.kt` (stub).

## Slices
**F4.1, shared wizard (no UI):**
- [ ] Port the draft enums and models and the `ReviewStep` sequence, including the skip rules (e.g. no
      elevator → skip the wheelchair step).
- [ ] `review/ReviewWizardModel(placeId)`: current step, answers, `canGoNext`, `next()`, `back()`, progress,
      `canSubmit`, validation messages. Exposes `StateFlow<ReviewWizardState>`.
- [ ] Payload builder (identical JSON to `ReviewSubmissionPayload.swift`) and a test that compares it to the backend's expectations.
- [ ] Submission: generate the `submission_id` once, upload photos (bytes + caption, limited concurrency),
      then POST the review, retry safely, and handle the result `Submitted | Failed(retryable)`.
- [ ] Unfinished drafts persisted with multiplatform-settings, so "continue your review" works on both apps.

**F4.2, iOS:** step views and the photo composer render `ReviewWizardModel`. Delete the Swift draft and submit logic.

**F4.3, Android:** Compose step screens, photo picker (Photo Picker API) + camera, caption entry, the
submitted screen, and the "continue your review" entry point. Follow the Figma review frames.

## Acceptance criteria
- A review with two photos submitted on Android appears on the iOS place page (F3) with the photos and captions, and vice versa.
- Turning on airplane mode mid-submit and then retrying doesn't create a duplicate review.
- Leaving the wizard halfway and reopening the place offers to resume, on both apps.
