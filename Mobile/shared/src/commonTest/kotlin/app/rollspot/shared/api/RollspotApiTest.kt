package app.rollspot.shared.api

import app.rollspot.shared.auth.InMemoryTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.MockRequestHandleScope
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.client.request.HttpResponseData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.io.IOException
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue

class RollspotApiTest {
    private val jsonHeaders = headersOf(HttpHeaders.ContentType, "application/json")
    private val requests = mutableListOf<HttpRequestData>()

    private fun api(
        tokens: InMemoryTokenStore = InMemoryTokenStore(),
        handler: suspend MockRequestHandleScope.(HttpRequestData) -> HttpResponseData,
    ) = RollspotApi("https://api.test", tokens, MockEngine { request -> requests += request; handler(request) })

    private val placeJson = """{"id":"p1","osm_ref":"way/520645071","name":"Beachwalk Bali","lat":-8.71,"lng":115.16,
        "osm_wheelchair":"yes","grade":[{"feature":"entrance","best_value":"yes","confidence":1.0}],"future_field":1}"""

    @Test
    fun nearbyDecodesPlacesAndIgnoresUnknownFields() = runTest {
        val places = api { respond("""{"status":"ok","places":[$placeJson]}""", headers = jsonHeaders) }
            .nearbyPlaces(-8.72, 115.17)
        assertEquals("Beachwalk Bali", places.single().name)
        assertEquals("way/520645071", places.single().osmRef)
        assertEquals("/v1/places/nearby", requests.single().url.encodedPath)
        assertEquals("-8.72", requests.single().url.parameters["lat"])
    }

    @Test
    fun osmPlaceKeyIsOnePathSegment() = runTest {
        api { respond("""{"status":"ok","place":$placeJson}""", headers = jsonHeaders) }.place("osm:way/520645071")
        assertEquals("/v1/places/osm:way%2F520645071", requests.single().url.encodedPath)
    }

    @Test
    fun signInStoresTheSessionToken() = runTest {
        val tokens = InMemoryTokenStore()
        val user = api(tokens) {
            respond(
                """{"token":"t","user":{"id":"u1","email":"a@b.co","emailVerified":true}}""",
                headers = headersOf(HttpHeaders.ContentType to listOf("application/json"), "set-auth-token" to listOf("session-123")),
            )
        }.signInWithEmail("a@b.co", "pw")
        assertEquals("u1", user.id)
        assertEquals("session-123", tokens.load())
    }

    @Test
    fun authenticatedCallsSendTheBearerToken() = runTest {
        api(InMemoryTokenStore("session-123")) {
            respond("""{"place_ids":[],"places":[]}""", headers = jsonHeaders)
        }.savedPlaces()
        assertEquals("Bearer session-123", requests.single().headers[HttpHeaders.Authorization])
    }

    @Test
    fun authenticatedCallWithoutTokenFailsBeforeTheNetwork() = runTest {
        val error = assertFailsWith<ApiException> { api { error("no request expected") }.savedPlaces() }
        assertTrue(error.isUnauthorized)
        assertTrue(requests.isEmpty())
    }

    @Test
    fun betterAuthErrorCodeAndMessageAreSurfaced() = runTest {
        val tokens = InMemoryTokenStore("keep-me")
        val error = assertFailsWith<ApiException> {
            api(tokens) {
                respond("""{"message":"Email not verified","code":"EMAIL_NOT_VERIFIED"}""", HttpStatusCode.Forbidden, jsonHeaders)
            }.signInWithEmail("a@b.co", "pw")
        }
        assertEquals(403, error.status)
        assertEquals("EMAIL_NOT_VERIFIED", error.code)
        assertEquals("Email not verified", error.message)
        assertEquals("keep-me", tokens.load())
    }

    @Test
    fun expiredSessionClearsTheStoredToken() = runTest {
        val tokens = InMemoryTokenStore("expired")
        assertFailsWith<ApiException> {
            api(tokens) {
                respond("""{"error":"unauthorized","message":"Sign in is required."}""", HttpStatusCode.Unauthorized, jsonHeaders)
            }.profile()
        }
        assertNull(tokens.load())
    }

    @Test
    fun readsRetryNetworkFailures() = runTest {
        var calls = 0
        val places = api {
            calls++
            if (calls < 3) throw IOException("connection reset")
            respond("""{"status":"ok","places":[]}""", headers = jsonHeaders)
        }.nearbyPlaces(0.0, 0.0)
        assertEquals(3, calls)
        assertTrue(places.isEmpty())
    }

    @Test
    fun writesAreNotRetried() = runTest {
        var calls = 0
        val error = assertFailsWith<ApiException> {
            api(InMemoryTokenStore("t")) { calls++; throw IOException("connection reset") }.savePlace("p1")
        }
        assertEquals(1, calls)
        assertTrue(error.isNetwork)
    }

    @Test
    fun currentUserIsNullWhenSessionIsGone() = runTest {
        assertNull(api(InMemoryTokenStore("t")) { respond("null", headers = jsonHeaders) }.currentUser())
        assertNull(api(InMemoryTokenStore()) { error("no request expected") }.currentUser())
    }
}
