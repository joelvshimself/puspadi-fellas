package app.rollspot.shared.auth

import app.rollspot.shared.api.RollspotApi
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

/** A tiny fake of the Worker + Better Auth, enough to walk every flow. */
private class FakeServer {
    var profileAids: List<String> = listOf("Wheelchair")
    var rejectTokens = false
    val calls = mutableListOf<String>()
    val bodies = mutableMapOf<String, String>()

    val engine = MockEngine { request ->
        val path = request.url.encodedPath
        calls += "${request.method.value} $path"
        val body = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
        bodies[path] = body
        val json = headersOf(HttpHeaders.ContentType, "application/json")
        val session = headersOf(HttpHeaders.ContentType to listOf("application/json"), "set-auth-token" to listOf("tok"))
        val user = """{"user":{"id":"u1","email":"x@y.z","emailVerified":true}}"""
        when (path) {
            "/api/auth/sign-in/social" ->
                if (rejectTokens) respond("""{"message":"Invalid token","code":"INVALID_TOKEN"}""", HttpStatusCode.Unauthorized, json)
                else respond(user, headers = session)
            "/v1/profile" -> {
                if (request.method.value == "PATCH") profileAids = Regex("\"mobilityAids\":\\[([^]]*)]").find(body)
                    ?.groupValues?.get(1)?.split(",")?.map { it.trim('"') }?.filter { it.isNotEmpty() } ?: profileAids
                respond("""{"id":"u1","pseudonym":"rollspot-u1","mobility_aids":[${profileAids.joinToString(",") { "\"$it\"" }}]}""", headers = json)
            }
            "/api/auth/sign-out" -> respond("""{"success":true}""", headers = json)
            "/v1/me" -> respond("", HttpStatusCode.NoContent)
            else -> respond("""{"error":"not_found"}""", HttpStatusCode.NotFound, json)
        }
    }
}

class AuthModelTest {
    private val server = FakeServer()
    private val tokens = InMemoryTokenStore()
    private val model = AuthModel(RollspotApi("https://api.test", tokens, server.engine))

    @Test
    fun returningUserSignsInStraightToDone() = runTest {
        assertEquals(AuthStep.Done, model.signInWithIdToken("google", "id-token", null, suggestedName = "Kadek", isNewAccount = false))
        assertTrue(model.isSignedIn)
        assertEquals("tok", tokens.load())
    }

    @Test
    fun firstTimeAppleSignInWaitsForOnboarding() = runTest {
        val step = model.signInWithIdToken("apple", "id-token", "nonce", suggestedName = "Made Wira", isNewAccount = true)
        assertEquals(AuthStep.Name("Made Wira"), step)
        assertFalse(model.isSignedIn)
        assertTrue(server.calls.none { it.contains("sign-in/social") })

        assertFailsWith<AuthException> { model.chooseName("  ") }
        assertEquals(AuthStep.Mobility, model.chooseName("Made Wira"))
        assertFailsWith<AuthException> { model.finishMobility(emptyList()) }
        assertEquals(AuthStep.AllSet, model.finishMobility(listOf("Crutches")))
        assertTrue(model.isSignedIn)
        assertTrue(server.bodies["/api/auth/sign-in/social"]!!.contains("\"nonce\":\"nonce\""))
        assertTrue(server.bodies["/v1/profile"]!!.contains("\"mobilityAids\":[\"Crutches\"]"))
    }

    @Test
    fun returningSocialUserWithoutOnboardingIsAskedForIt() = runTest {
        server.profileAids = emptyList()
        val step = model.signInWithIdToken("google", "id-token", null, suggestedName = "Kadek", isNewAccount = false)
        assertEquals(AuthStep.Name("Kadek"), step)
        assertTrue(model.isSignedIn)
        model.chooseName("Kadek")
        assertEquals(AuthStep.AllSet, model.finishMobility(listOf("No mobility aid")))
    }

    @Test
    fun rejectedTokenGetsFriendlyCopy() = runTest {
        server.rejectTokens = true
        val error = assertFailsWith<AuthException> {
            model.signInWithIdToken("google", "bad", null, suggestedName = null, isNewAccount = false)
        }
        assertEquals("That sign-in method isn't available right now. Try the other one.", error.message)
        assertFalse(model.isSignedIn)
    }

    @Test
    fun signOutForgetsTheSession() = runTest {
        model.signInWithIdToken("apple", "id-token", "nonce", suggestedName = null, isNewAccount = false)
        model.signOut()
        assertIs<AuthSession.SignedOut>(model.session.value)
        assertEquals(null, tokens.load())
        assertEquals("{}", server.bodies["/api/auth/sign-out"], "Better Auth answers 415 without a JSON body")
    }

    @Test
    fun deleteAccountCallsTheServerAndSignsOut() = runTest {
        model.signInWithIdToken("apple", "id-token", "nonce", suggestedName = null, isNewAccount = false)
        model.deleteAccount()
        assertTrue("DELETE /v1/me" in server.calls)
        assertIs<AuthSession.SignedOut>(model.session.value)
        assertEquals(null, tokens.load())
    }

    @Test
    fun restoreWithoutTokenIsSignedOut() = runTest {
        model.restore()
        assertIs<AuthSession.SignedOut>(model.session.value)
    }
}
