package app.rollspot.shared

import app.rollspot.shared.auth.AuthException
import app.rollspot.shared.auth.AuthStep
import app.rollspot.shared.auth.InMemoryTokenStore
import kotlinx.coroutines.runBlocking
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertIs
import kotlin.test.assertTrue

/**
 * Runs the shared code against a real backend. Skipped unless ROLLSPOT_LIVE_URL is set:
 *
 *   cd backend && npm run dev     # and sync places once (see CLAUDE.md)
 *   ROLLSPOT_LIVE_URL=http://localhost:8787 ./gradlew :shared:testDebugUnitTest --tests '*LiveBackendTest*'
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
}
