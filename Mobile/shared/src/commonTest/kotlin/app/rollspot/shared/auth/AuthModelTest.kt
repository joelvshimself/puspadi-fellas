package app.rollspot.shared.auth

import app.rollspot.shared.api.RollspotApi
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
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
    val registered = mutableSetOf("known@rollspot.app")
    val verified = mutableSetOf("known@rollspot.app")
    var profileAids: List<String> = listOf("Wheelchair")
    val calls = mutableListOf<String>()
    val bodies = mutableMapOf<String, String>()

    val engine = MockEngine { request ->
        val path = request.url.encodedPath
        calls += "${request.method.value} $path"
        val body = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
        bodies[path] = body
        val json = headersOf(HttpHeaders.ContentType, "application/json")
        val session = headersOf(HttpHeaders.ContentType to listOf("application/json"), "set-auth-token" to listOf("tok"))
        fun email() = Regex("\"email\":\"([^\"]+)\"").find(body)?.groupValues?.get(1).orEmpty()
        val user = """{"user":{"id":"u1","email":"x@y.z","emailVerified":true}}"""
        when (path) {
            "/v1/auth/email-registered" -> respond("""{"registered":${email() in registered}}""", headers = json)
            "/api/auth/sign-up/email" -> { registered += email(); respond("""{"token":null}""", headers = json) }
            "/api/auth/sign-in/email" -> when {
                email() !in registered || !body.contains("\"password\":\"Passw0rd!\"") ->
                    respond("""{"message":"Invalid email or password","code":"INVALID_EMAIL_OR_PASSWORD"}""", HttpStatusCode.Unauthorized, json)
                email() !in verified ->
                    respond("""{"message":"Email not verified","code":"EMAIL_NOT_VERIFIED"}""", HttpStatusCode.Forbidden, json)
                else -> respond(user, headers = session)
            }
            "/api/auth/sign-in/social" -> respond(user, headers = session)
            "/api/auth/send-verification-email" -> respond("""{"status":true}""", headers = json)
            "/v1/auth/providers" -> respond("""{"providers":["credential"]}""", headers = json)
            "/v1/profile" -> {
                if (request.method.value == "PATCH") profileAids = Regex("\"mobilityAids\":\\[([^]]*)]").find(body)
                    ?.groupValues?.get(1)?.split(",")?.map { it.trim('"') }?.filter { it.isNotEmpty() } ?: profileAids
                respond("""{"id":"u1","pseudonym":"rollspot-u1","mobility_aids":[${profileAids.joinToString(",") { "\"$it\"" }}]}""", headers = json)
            }
            "/api/auth/sign-out" -> respond("""{"success":true}""", headers = json)
            else -> respond("""{"error":"not_found"}""", HttpStatusCode.NotFound, json)
        }
    }
}

class AuthModelTest {
    private val server = FakeServer()
    private val tokens = InMemoryTokenStore()
    private val model = AuthModel(RollspotApi("https://api.test", tokens, server.engine))

    @Test
    fun rulesMatchTheIosApp() {
        assertTrue(AuthRules.looksLikeEmail(" a@b.co "))
        assertFalse(AuthRules.looksLikeEmail("a@b"))
        assertTrue(AuthRules.isValidPassword("Passw0rd!"))
        assertFalse(AuthRules.isValidPassword("password1"))
        assertFalse(AuthRules.isValidPassword("Pass!1"))
        assertEquals("a@b.co", AuthRules.normalizeEmail("  A@B.co "))
    }

    @Test
    fun knownEmailSignsInStraightToDone() = runTest {
        assertEquals(AuthStep.EmailFound("known@rollspot.app"), model.continueWithEmail(" Known@Rollspot.app"))
        assertEquals(AuthStep.Done, model.signIn("known@rollspot.app", "Passw0rd!"))
        assertTrue(model.isSignedIn)
        assertEquals("tok", tokens.load())
        assertTrue((model.session.value as AuthSession.SignedIn).canChangePassword)
    }

    @Test
    fun wrongPasswordGetsFriendlyCopy() = runTest {
        val error = assertFailsWith<AuthException> { model.signIn("known@rollspot.app", "nope") }
        assertEquals("That email and password don't match.", error.message)
        assertFalse(model.isSignedIn)
    }

    @Test
    fun newEmailWalksTheWholeSignUp() = runTest {
        assertEquals(AuthStep.CreatePassword("new@rollspot.app"), model.continueWithEmail("new@rollspot.app"))
        assertFailsWith<AuthException> { model.choosePassword("weak") }
        assertEquals(AuthStep.Name(""), model.choosePassword("Passw0rd!"))
        assertEquals(AuthStep.Mobility, model.chooseName("  Ayu "))
        assertEquals(AuthStep.VerifyEmail("new@rollspot.app"), model.finishMobility(listOf("Wheelchair")))
        assertTrue(server.bodies["/api/auth/sign-up/email"]!!.contains("\"name\":\"Ayu\""))
        assertTrue(server.bodies["/api/auth/sign-up/email"]!!.contains("puspadi://auth/callback"))

        // Tapping "continue" before confirming the email.
        val notYet = assertFailsWith<AuthException> { model.completeVerifiedSignUp() }
        assertEquals("EMAIL_NOT_VERIFIED", notYet.code)

        server.verified += "new@rollspot.app"
        assertEquals(AuthStep.Done, model.completeVerifiedSignUp())
        assertTrue(model.isSignedIn)
        assertTrue(server.bodies["/v1/profile"]!!.contains("\"mobilityAids\":[\"Wheelchair\"]"))
    }

    @Test
    fun firstTimeAppleSignInWaitsForOnboarding() = runTest {
        val step = model.signInWithIdToken("apple", "id-token", "nonce", suggestedName = "Made Wira", isNewAccount = true)
        assertEquals(AuthStep.Name("Made Wira"), step)
        assertFalse(model.isSignedIn)
        assertTrue(server.calls.none { it.contains("sign-in/social") })

        model.chooseName("Made Wira")
        assertEquals(AuthStep.Done, model.finishMobility(listOf("Crutches")))
        assertTrue(model.isSignedIn)
        assertTrue(server.bodies["/api/auth/sign-in/social"]!!.contains("\"nonce\":\"nonce\""))
    }

    @Test
    fun returningSocialUserWithoutOnboardingIsAskedForIt() = runTest {
        server.profileAids = emptyList()
        val step = model.signInWithIdToken("google", "id-token", null, suggestedName = "Kadek", isNewAccount = false)
        assertEquals(AuthStep.Name("Kadek"), step)
        assertTrue(model.isSignedIn)
        model.chooseName("Kadek")
        assertEquals(AuthStep.Done, model.finishMobility(listOf("No mobility aid")))
    }

    @Test
    fun signOutForgetsTheSession() = runTest {
        model.signIn("known@rollspot.app", "Passw0rd!")
        model.signOut()
        assertIs<AuthSession.SignedOut>(model.session.value)
        assertEquals(null, tokens.load())
    }

    @Test
    fun restoreWithoutTokenIsSignedOut() = runTest {
        model.restore()
        assertIs<AuthSession.SignedOut>(model.session.value)
    }
}
