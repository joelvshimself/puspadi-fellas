package app.rollspot.shared.profile

import app.rollspot.shared.RollspotSdk
import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.Place
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import app.rollspot.shared.auth.MobilityRole
import app.rollspot.shared.saved.SaveOutcome
import app.rollspot.shared.saved.SavedPlacesModel
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

private val jsonHeaders = headersOf(HttpHeaders.ContentType, "application/json")

private fun api(handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData) =
    RollspotApi("https://api.test", InMemoryTokenStore("session"), MockEngine { handler(it) })

private fun place(id: String, name: String) = Place(id = id, osmRef = "way/$id", name = name, lat = -8.7, lng = 115.2)

private fun placeJson(id: String, name: String) = """{"id":"$id","osm_ref":"way/$id","name":"$name","lat":-8.7,"lng":115.2,"grade":[]}"""

class ProfileModelTest {
    private val sent = mutableListOf<String>()
    private val model = ProfileModel(
        api { request ->
            (request.body as? OutgoingContent.ByteArrayContent)?.let { sent += it.bytes().decodeToString() }
            when (request.url.encodedPath) {
                "/v1/profile/avatar" -> respond("""{"url":"https://api.test/v1/media/avatars/u1/avatar.jpg"}""", headers = jsonHeaders)
                else -> respond(
                    """{"id":"u1","display_name":"Ayu","mobility_aids":["Wheelchair"],"pseudonym":"rollspot-u1"}""",
                    headers = jsonHeaders,
                )
            }
        },
    )

    @Test
    fun loadedProfileDerivesNameAndRole() = runTest {
        assertEquals("You", model.state.value.displayName)
        model.load()
        assertEquals("Ayu", model.state.value.displayName)
        assertEquals(MobilityRole.WHEELCHAIR_USER, model.state.value.mobilityRole)
        assertEquals("Wheelchair User", model.state.value.roleLabel)
    }

    @Test
    fun nameIsValidatedBeforeTheNetwork() = runTest {
        assertFailsWith<ProfileException> { model.updateDisplayName("   ") }
        assertFailsWith<ProfileException> { model.updateDisplayName("x".repeat(81)) }
        assertTrue(sent.isEmpty())
        model.updateDisplayName("  Ayu  ")
        assertEquals("""{"displayName":"Ayu"}""", sent.single())
    }

    @Test
    fun roleStoresTheCanonicalAnswer() = runTest {
        model.updateMobilityRole(MobilityRole.COMMUNITY_CONTRIBUTOR)
        assertEquals("""{"mobilityAids":["No mobility aid"]}""", sent.single())
        assertEquals(MobilityRole.WHEELCHAIR_USER, MobilityRole.fromAids(listOf("Crutches", "Wheelchair")))
        assertEquals(MobilityRole.COMMUNITY_CONTRIBUTOR, MobilityRole.fromAids(listOf("Crutches")))
        assertNull(MobilityRole.fromAids(emptyList()))
    }

    @Test
    fun avatarIsSizeCheckedAndCacheBusted() = runTest {
        assertFailsWith<ProfileException> { model.uploadAvatar(ByteArray(0)) }
        assertFailsWith<ProfileException> { model.uploadAvatar(ByteArray(ProfileModel.MAX_AVATAR_BYTES + 1)) }
        model.load()
        val url = model.uploadAvatar(byteArrayOf(1, 2, 3))
        assertTrue(url.startsWith("https://api.test/v1/media/avatars/u1/avatar.jpg?v="), url)
        assertEquals(url, model.state.value.avatarUrl)
        assertFalse(model.state.value.isUploadingAvatar)
    }
}

class MyReviewsModelTest {
    private var failDelete = false
    private val deleted = mutableListOf<String>()
    private val model = MyReviewsModel(
        api { request ->
            if (request.method.value == "DELETE") {
                deleted += request.url.encodedPath
                if (failDelete) respond("""{"error":"internal_error","message":"Server down"}""", HttpStatusCode.InternalServerError, jsonHeaders)
                else respond("", HttpStatusCode.NoContent)
            } else {
                respond(
                    """{"status":"ok","userName":"","userRole":"Wheelchair User","reviews":[
                      {"id":"old","placeId":"p1","placeName":"Beachwalk Bali","createdAt":"2026-01-02T10:00:00.000Z","reviewText":"Ramp ok",
                       "providedFeatures":["Ramp"],"photoUrls":["https://x/1.jpg","https://x/2.jpg"],"photoCaptions":[" door ",""]},
                      {"id":"new","placeId":"p2","placeName":"Discovery Mall","createdAt":"2026-03-05T10:00:00.000Z","reviewText":"Lift","photoUrls":[]}
                    ]}""",
                    headers = jsonHeaders,
                )
            }
        },
    )

    @Test
    fun reviewsAreNewestFirstWithPhotosAndLabels() = runTest {
        model.load()
        val state = model.state.value
        assertEquals("You", state.userName)
        assertEquals(listOf("new", "old"), state.reviews.map { it.id })
        assertEquals(listOf("https://x/1.jpg", "https://x/2.jpg"), state.photos.map { it.url })
        assertEquals("door", state.photos.first().caption)
        assertEquals("Beachwalk Bali", state.photos.first().placeName)
        assertTrue(state.reviews.first().dateLabel.isNotEmpty())
    }

    @Test
    fun deleteRemovesAtOnceAndComesBackIfTheServerRefuses() = runTest {
        model.load()
        model.delete("old")
        assertEquals(listOf("new"), model.state.value.reviews.map { it.id })
        assertEquals(listOf("/v1/reviews/old"), deleted)

        failDelete = true
        assertFailsWith<ApiException> { model.delete("new") }
        assertEquals(listOf("new"), model.state.value.reviews.map { it.id })
        assertEquals("Server down", model.state.value.error)
        assertNull(model.state.value.deletingId)
    }
}

@OptIn(kotlinx.coroutines.ExperimentalCoroutinesApi::class)
class SavedPlacesModelTest {
    private var signedIn = true
    private var failWrites = false
    private val writes = mutableListOf<String>()
    private var gate: CompletableDeferred<Unit>? = null

    private val model = SavedPlacesModel(
        api { request ->
            if (request.method.value == "GET") {
                respond("""{"place_ids":["b","a"],"places":[${placeJson("b", "Beachwalk")},${placeJson("a", "Artasedana")}]}""", headers = jsonHeaders)
            } else {
                writes += "${request.method.value} ${request.url.encodedPath}"
                gate?.await()
                if (failWrites) respond("""{"error":"internal_error","message":"Try later"}""", HttpStatusCode.InternalServerError, jsonHeaders)
                else respond("", HttpStatusCode.NoContent)
            }
        },
    ) { signedIn }

    @Test
    fun loadSortsByName() = runTest {
        model.load()
        assertEquals(listOf("Artasedana", "Beachwalk"), model.state.value.places.map { it.name })
        assertTrue(model.isSaved("a"))
    }

    @Test
    fun toggleSavesAndRemoves() = runTest {
        assertEquals(SaveOutcome.Saved, model.toggle(place("c", "Carrefour")))
        assertTrue(model.isSaved("c"))
        assertEquals(SaveOutcome.Removed, model.toggle(place("c", "Carrefour")))
        assertFalse(model.isSaved("c"))
        assertEquals(listOf("PUT /v1/saved-places/c", "DELETE /v1/saved-places/c"), writes)
    }

    @Test
    fun failedSaveFlipsBack() = runTest {
        failWrites = true
        val outcome = model.toggle(place("c", "Carrefour"))
        assertEquals(SaveOutcome.Failed("Try later"), outcome)
        assertFalse(model.isSaved("c"))
        assertTrue(model.state.value.pending.isEmpty())
    }

    @Test
    fun oneRequestPerPlaceAtATime() = runTest {
        gate = CompletableDeferred()
        val first = async { model.toggle(place("c", "Carrefour")) }
        runCurrent()
        // Optimistic: already shown as saved while the request is in flight.
        assertTrue(model.isSaved("c"))
        assertEquals(SaveOutcome.Failed("This place is already being updated."), model.toggle(place("c", "Carrefour")))
        gate!!.complete(Unit)
        assertEquals(SaveOutcome.Saved, first.await())
        assertEquals(1, writes.size)
    }

    @Test
    fun signedOutNeedsSignIn() = runTest {
        signedIn = false
        assertEquals(SaveOutcome.NeedsSignIn, model.toggle(place("c", "Carrefour")))
        model.load()
        assertTrue(model.state.value.places.isEmpty())
        assertTrue(writes.isEmpty())
    }
}

class SdkSessionWiringTest {
    @Test
    fun signingOutClearsPerUserState() = runTest {
        val sdk = RollspotSdk(
            "https://api.test",
            InMemoryTokenStore("session"),
            MockEngine { request ->
                when (request.url.encodedPath) {
                    "/api/auth/sign-in/social" -> respond(
                        """{"user":{"id":"u1","email":"a@b.co","emailVerified":true}}""",
                        headers = headersOf(HttpHeaders.ContentType to listOf("application/json"), "set-auth-token" to listOf("tok")),
                    )
                    "/v1/profile" -> respond("""{"id":"u1","pseudonym":"p","mobility_aids":["Wheelchair"]}""", headers = jsonHeaders)
                    "/v1/saved-places" -> respond("""{"place_ids":["a"],"places":[${placeJson("a", "Artasedana")}]}""", headers = jsonHeaders)
                    else -> respond("""{"success":true}""", headers = jsonHeaders)
                }
            },
        )
        sdk.auth.signInWithIdToken("apple", "id-token", "nonce", suggestedName = null, isNewAccount = false)
        sdk.saved.load()
        sdk.profile.load()
        assertTrue(sdk.saved.isSaved("a"))
        sdk.auth.signOut()
        // The SDK reacts on its own background scope: wait (in real time) for it to catch up.
        kotlinx.coroutines.withContext(kotlinx.coroutines.Dispatchers.Default) {
            kotlinx.coroutines.withTimeout(5_000) {
                sdk.saved.state.first { it.places.isEmpty() }
                sdk.profile.state.first { it.profile == null }
            }
        }
        assertFalse(sdk.saved.isSaved("a"))
        assertNull(sdk.profile.state.value.profile)
    }
}
