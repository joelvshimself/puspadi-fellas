package app.rollspot.shared

import app.rollspot.shared.api.ContributionElevator
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.auth.AuthException
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.AuthStep
import app.rollspot.shared.auth.InMemoryTokenStore
import app.rollspot.shared.auth.MobilityRole
import app.rollspot.shared.place.PlaceDetailState
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.reviews.PendingContributionPhoto
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
 * The full journey also needs a verified account it may delete: set ROLLSPOT_LIVE_EMAIL and
 * ROLLSPOT_LIVE_PASSWORD (sign up, then open the verification link from the wrangler output).
 */
class LiveBackendTest {
    private val baseUrl = System.getenv("ROLLSPOT_LIVE_URL")

    private fun live(block: suspend (RollspotSdk) -> Unit) {
        if (baseUrl.isNullOrBlank()) return
        runBlocking { block(RollspotSdk(baseUrl, InMemoryTokenStore())) }
    }

    @Test
    fun placesComeFromTheDirectory() = live { sdk ->
        val nearby = sdk.places.nearby(-8.72, 115.17)
        assertTrue(nearby.isNotEmpty(), "sync places first: POST /v1/admin/sync-places")
        val found = sdk.places.search("beachwalk", -8.72, 115.17)
        val place = sdk.places.place("osm:${found.first().osmRef}")
        assertEquals(found.first().id, place.id)
    }

    @Test
    fun emailSignUpStopsAtVerification() = live { sdk ->
        val email = "live-${System.currentTimeMillis()}@example.com"
        assertIs<AuthStep.CreatePassword>(sdk.auth.continueWithEmail(email))
        sdk.auth.choosePassword("Passw0rd!")
        sdk.auth.chooseName("Live Test")
        assertEquals(AuthStep.VerifyEmail(email), sdk.auth.finishMobility(listOf("Wheelchair")))
        val error = runCatching { sdk.auth.completeVerifiedSignUp() }.exceptionOrNull()
        assertIs<AuthException>(error)
        assertEquals("EMAIL_NOT_VERIFIED", error.code)
        assertEquals(AuthStep.EmailFound(email), sdk.auth.continueWithEmail(email))
    }

    /**
     * Every feature, in the order a user meets them, through the same shared models the apps
     * use: sign in (F1), map (F2), place page (F3), contribute (F4), profile/saved/my reviews and
     * account deletion (F5).
     */
    @Test
    fun fullJourney() {
        val email = System.getenv("ROLLSPOT_LIVE_EMAIL") ?: return
        val password = System.getenv("ROLLSPOT_LIVE_PASSWORD") ?: return
        live { sdk ->
            // F1: a known, verified email signs in (onboarding first if it was never finished).
            assertEquals(AuthStep.EmailFound(email.lowercase()), sdk.auth.continueWithEmail(email))
            var step = sdk.auth.signIn(email, password)
            if (step is AuthStep.Name) {
                sdk.auth.chooseName("Live Journey")
                step = sdk.auth.finishMobility(listOf("Wheelchair"))
            }
            assertTrue(step == AuthStep.Done || step == AuthStep.AllSet, "signed in: $step")
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
            assertIs<AuthStep.CreatePassword>(sdk.auth.continueWithEmail(email))
        }
    }
}
