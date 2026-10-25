package app.rollspot.shared

import app.rollspot.shared.api.ContributionElevator
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.InMemoryTokenStore
import app.rollspot.shared.auth.MobilityRole
import app.rollspot.shared.place.PlaceDetailState
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.reviews.PendingContributionPhoto
import app.rollspot.shared.reviews.ReviewEditState
import app.rollspot.shared.saved.SaveOutcome
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Runs the shared code against a real backend. Skipped unless ROLLSPOT_LIVE_URL is set:
 *
 *   cd backend && npm run dev     # and sync places once (see CLAUDE.md)
 *   ROLLSPOT_LIVE_URL=http://localhost:8787 ./gradlew :shared:testDebugUnitTest --tests '*LiveBackendTest*' --rerun
 *
 * The full journey also needs a signed-in account it may delete. Sign-in is Apple/Google only, so
 * sign in with a debug app pointed at the same backend and pass its session token as
 * ROLLSPOT_LIVE_TOKEN (the `session` table's `token` column in the local D1).
 */
class LiveBackendTest {
    private val baseUrl = System.getenv("ROLLSPOT_LIVE_URL")

    private fun live(token: String? = null, block: suspend (RollspotSdk) -> Unit) {
        if (baseUrl.isNullOrBlank()) return
        runBlocking { block(RollspotSdk(baseUrl, InMemoryTokenStore(token))) }
    }

    @Test
    fun placesComeFromTheDirectory() = live { sdk ->
        val nearby = sdk.places.nearby(-8.72, 115.17)
        assertTrue(nearby.isNotEmpty(), "sync places first: POST /v1/admin/sync-places")
        val found = sdk.places.search("beachwalk", -8.72, 115.17)
        val place = sdk.places.place("osm:${found.first().osmRef}")
        assertEquals(found.first().id, place.id)
    }

    /**
     * Every feature, in the order a user meets them, through the same shared models the apps
     * use: sign in (F1), map (F2), place page (F3), contribute (F4), profile/saved/my reviews and
     * account deletion (F5).
     */
    @Test
    fun fullJourney() {
        val token = System.getenv("ROLLSPOT_LIVE_TOKEN") ?: return
        live(token) { sdk ->
            // F1: the session from the app is valid.
            sdk.auth.restore()
            assertIs<AuthSession.SignedIn>(sdk.auth.session.value)

            // F2: the map's nearby places come from the directory, nearest first.
            val nearby = sdk.places.nearby(-8.7165, 115.1696, 3_000)
            assertTrue(nearby.isNotEmpty())
            val place = nearby.first()

            // F3: the place page loads.
            val detail = sdk.placeDetailModel(place.id)
            val before = detail.reload()
            assertTrue(before is PlaceDetailState.Loaded || before is PlaceDetailState.Empty, "place page: $before")

            // F5: saving flips and persists.
            assertEquals(SaveOutcome.Saved, sdk.saved.toggle(place))
            sdk.saved.load()
            assertTrue(sdk.saved.isSaved(place.id))

            // F4: a v2 contribution with a photo lands on the place page.
            val submission = ContributionSubmission(
                submissionId = "live-${System.currentTimeMillis()}",
                placeId = place.id,
                persona = "wheelchair",
                elevator = ContributionElevator(
                    passes = listOf(
                        ContributionElevatorPass(
                            photos = listOf(ContributionPhoto("local:lift")),
                            wideEntrance = "yes",
                            spaceToManeuver = "yes",
                            reachableButtons = "yes",
                        ),
                    ),
                    notes = "Lift next to the food court",
                ),
            )
            val jpeg = byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0xE0.toByte(), 1, 2, 3)
            val submitted = sdk.reviews.submitContribution(submission, listOf(PendingContributionPhoto("lift", jpeg)))
            assertEquals(place.id, submitted.placeId)
            // A retry with the same submissionId must not create a second review.
            val retried = sdk.reviews.submitContribution(submission, listOf(PendingContributionPhoto("lift", jpeg)))
            assertEquals(submitted.reviewId, retried.reviewId)

            val after = detail.reload()
            assertIs<PlaceDetailState.Loaded>(after)
            assertTrue(after.detail.reviews.any { it.reviewId == submitted.reviewId }, "review on the place page")
            assertTrue(after.detail.gallery.any { it.url.endsWith("/lift.jpg") }, "photo in the gallery")
            assertTrue(after.detail.overall != OverallAccessibility.NO_DATA)

            // Edit Response: change an answer and the notes, add a photo, and the place page follows.
            val edit = sdk.reviewEditModel(submitted.reviewId)
            edit.load()
            edit.choose("elevator/0/wideEntrance", "no")
            edit.setNotes("elevator", "Lift is too narrow")
            assertTrue(edit.addPhoto("elevator/0", jpeg))
            edit.save()
            assertIs<ReviewEditState.Saved>(edit.state.value)
            val edited = detail.reload()
            assertIs<PlaceDetailState.Loaded>(edited)
            assertEquals(2, edited.detail.gallery.count { it.url.contains(submission.submissionId) }, "kept + added photo")

            // F5: profile edits and my reviews.
            sdk.profile.updateDisplayName("Live Journey")
            sdk.profile.updateMobilityRole(MobilityRole.WHEELCHAIR_USER)
            sdk.profile.load()
            assertEquals("Live Journey", sdk.profile.state.value.displayName)
            assertEquals(MobilityRole.WHEELCHAIR_USER, sdk.profile.state.value.mobilityRole)

            sdk.myReviews.load()
            val mine = sdk.myReviews.state.value.reviews.first { it.id == submitted.reviewId }
            assertEquals(place.name, mine.placeName)
            sdk.myReviews.delete(submitted.reviewId)
            val gone = detail.reload()
            val stillThere = (gone as? PlaceDetailState.Loaded)?.detail?.reviews?.any { it.reviewId == submitted.reviewId } ?: false
            assertTrue(!stillThere, "deleted review must leave the place page")

            assertEquals(SaveOutcome.Removed, sdk.saved.toggle(place))
            detail.close()

            // F5: deleting the account signs out, and the account no longer exists.
            sdk.auth.deleteAccount()
            assertIs<AuthSession.SignedOut>(sdk.auth.session.value)
            val again = RollspotSdk(baseUrl, InMemoryTokenStore(token))
            again.auth.restore()
            assertIs<AuthSession.SignedOut>(again.auth.session.value, "the old session must be gone")
        }
    }
}
