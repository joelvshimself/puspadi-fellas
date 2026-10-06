package app.rollspot.shared.api

import app.rollspot.shared.auth.TokenStore
import io.ktor.client.HttpClient
import io.ktor.client.HttpClientConfig
import io.ktor.client.call.body
import io.ktor.client.engine.HttpClientEngine
import io.ktor.client.plugins.HttpRequestTimeoutException
import io.ktor.client.plugins.HttpTimeout
import io.ktor.client.plugins.contentnegotiation.ContentNegotiation
import io.ktor.client.request.HttpRequestBuilder
import io.ktor.client.request.bearerAuth
import io.ktor.client.request.request
import io.ktor.client.request.setBody
import io.ktor.client.statement.HttpResponse
import io.ktor.client.statement.bodyAsText
import io.ktor.http.ContentType
import io.ktor.http.HttpMethod
import io.ktor.http.appendPathSegments
import io.ktor.http.contentType
import io.ktor.http.isSuccess
import io.ktor.http.takeFrom
import io.ktor.serialization.kotlinx.json.json
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.io.IOException
import kotlinx.serialization.json.Json

/**
 * The apps' one network boundary: one function per endpoint in backend/API.md.
 * Feature code calls repositories, which call this; views never do.
 *
 * Place parameters take a Rollspot place ID or an `osm:<type>/<id>` key.
 */
class RollspotApi(
    private val baseUrl: String,
    private val tokens: TokenStore,
    engine: HttpClientEngine? = null,
) {
    @PublishedApi
    internal val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false
        coerceInputValues = true
    }

    private val configure: HttpClientConfig<*>.() -> Unit = {
        expectSuccess = false
        install(ContentNegotiation) { json(json) }
        install(HttpTimeout) {
            requestTimeoutMillis = 30_000
            connectTimeoutMillis = 15_000
        }
    }

    @PublishedApi
    internal val http: HttpClient = engine?.let { HttpClient(it, configure) } ?: HttpClient(configure)

    // ---- Places ----

    @Throws(Exception::class)
    suspend fun nearbyPlaces(lat: Double, lng: Double, radiusMeters: Int = 5_000): List<Place> =
        call<PlacesResponse>(HttpMethod.Get, listOf("v1", "places", "nearby")) {
            url.parameters.append("lat", lat.toString())
            url.parameters.append("lng", lng.toString())
            url.parameters.append("radius", radiusMeters.toString())
        }.places

    @Throws(Exception::class)
    suspend fun searchPlaces(query: String, lat: Double? = null, lng: Double? = null): List<Place> =
        call<PlacesResponse>(HttpMethod.Get, listOf("v1", "places", "search")) {
            url.parameters.append("q", query)
            if (lat != null && lng != null) {
                url.parameters.append("lat", lat.toString())
                url.parameters.append("lng", lng.toString())
            }
        }.places

    @Throws(Exception::class)
    suspend fun place(placeKey: String): Place =
        call<PlaceResponse>(HttpMethod.Get, listOf("v1", "places", placeKey)).place

    @Throws(Exception::class)
    suspend fun placePhotos(placeKey: String): List<PlacePhoto> =
        call(HttpMethod.Get, listOf("v1", "places", placeKey, "photos"))

    @Throws(Exception::class)
    suspend fun placeReviews(placeKey: String): List<PlaceReview> =
        call<PlaceReviewsResponse>(HttpMethod.Get, listOf("v1", "places", placeKey, "reviews")).reviews

    @Throws(Exception::class)
    suspend fun placeReviewPhotos(placeKey: String): ReviewPhotos =
        call(HttpMethod.Get, listOf("v1", "places", placeKey, "review-photos"))

    // ---- Saved places ----

    @Throws(Exception::class)
    suspend fun savedPlaces(): SavedPlaces = call(HttpMethod.Get, listOf("v1", "saved-places"), auth = true)

    @Throws(Exception::class)
    suspend fun savePlace(placeKey: String) {
        send(HttpMethod.Put, listOf("v1", "saved-places", placeKey), auth = true)
    }

    @Throws(Exception::class)
    suspend fun unsavePlace(placeKey: String) {
        send(HttpMethod.Delete, listOf("v1", "saved-places", placeKey), auth = true)
    }

    // ---- Reviews ----

    @Throws(Exception::class)
    suspend fun submitReview(submission: ReviewSubmission): ReviewSubmitted =
        call(HttpMethod.Post, listOf("v1", "reviews"), auth = true) { jsonBody(submission) }

    @Throws(Exception::class)
    suspend fun myReviews(): MyReviews = call(HttpMethod.Get, listOf("v1", "me", "reviews"), auth = true)

    @Throws(Exception::class)
    suspend fun deleteReview(reviewId: String) {
        send(HttpMethod.Delete, listOf("v1", "reviews", reviewId), auth = true)
    }

    /** Uploads one JPEG and returns its URL for [ReviewNote.photoUrls]. Reusing [photoId] overwrites, so retries are safe. */
    @Throws(Exception::class)
    suspend fun uploadReviewPhoto(placeKey: String, facility: String, photoId: String, jpeg: ByteArray): String =
        call<UploadedMedia>(HttpMethod.Put, listOf("v1", "media", "review-photos", placeKey, facility, photoId), auth = true) {
            contentType(ContentType.Image.JPEG)
            setBody(jpeg)
        }.url

    // ---- Profile ----

    @Throws(Exception::class)
    suspend fun profile(): Profile = call(HttpMethod.Get, listOf("v1", "profile"), auth = true)

    @Throws(Exception::class)
    suspend fun updateProfile(update: ProfileUpdate): Profile =
        call(HttpMethod.Patch, listOf("v1", "profile"), auth = true) { jsonBody(update) }

    @Throws(Exception::class)
    suspend fun uploadAvatar(jpeg: ByteArray): String =
        call<UploadedMedia>(HttpMethod.Put, listOf("v1", "profile", "avatar"), auth = true) {
            contentType(ContentType.Image.JPEG)
            setBody(jpeg)
        }.url

    // ---- Auth (Better Auth) ----

    @Throws(Exception::class)
    suspend fun emailRegistered(email: String): Boolean =
        call<EmailRegistered>(HttpMethod.Post, listOf("v1", "auth", "email-registered")) { jsonBody(EmailBody(email)) }.registered

    /** Creates the account and sends the verification email. No session until the email is verified. */
    @Throws(Exception::class)
    suspend fun signUpWithEmail(name: String, email: String, password: String, callbackUrl: String) {
        send(HttpMethod.Post, listOf("api", "auth", "sign-up", "email")) {
            jsonBody(EmailSignUp(name, email, password, callbackUrl))
        }
    }

    @Throws(Exception::class)
    suspend fun sendVerificationEmail(email: String, callbackUrl: String) {
        send(HttpMethod.Post, listOf("api", "auth", "send-verification-email")) {
            jsonBody(VerificationEmail(email, callbackUrl))
        }
    }

    /** Stores the session token on success. */
    @Throws(Exception::class)
    suspend fun signInWithEmail(email: String, password: String): AuthUser =
        signIn(listOf("api", "auth", "sign-in", "email"), EmailPassword(email, password))

    /** Exchanges an Apple or Google ID token for a session. Stores the session token on success. */
    @Throws(Exception::class)
    suspend fun signInWithIdToken(provider: String, idToken: String, nonce: String?): AuthUser =
        signIn(listOf("api", "auth", "sign-in", "social"), SocialSignIn(provider, SocialSignIn.IdToken(idToken, nonce)))

    /** The signed-in user, or null when the stored token is missing, expired or revoked. */
    @Throws(Exception::class)
    suspend fun currentUser(): AuthUser? {
        if (tokens.load() == null) return null
        val response = execute(HttpMethod.Get, listOf("api", "auth", "get-session"), auth = true) {}
        if (response.status.value == 401) return null
        // Better Auth answers `null` when the session is gone.
        val text = response.bodyAsText()
        if (text.isBlank() || text == "null") return null
        return json.decodeFromString<AuthUserResponse>(text).user
    }

    @Throws(Exception::class)
    suspend fun linkedProviders(): List<String> =
        call<Providers>(HttpMethod.Get, listOf("v1", "auth", "providers"), auth = true).providers

    @Throws(Exception::class)
    suspend fun changePassword(currentPassword: String, newPassword: String) {
        send(HttpMethod.Post, listOf("api", "auth", "change-password"), auth = true) {
            jsonBody(ChangePassword(currentPassword, newPassword, revokeOtherSessions = true))
        }
    }

    /** Ends the session on the server (best effort) and always forgets it locally. */
    @Throws(Exception::class)
    suspend fun signOut() {
        try {
            if (tokens.load() != null) send(HttpMethod.Post, listOf("api", "auth", "sign-out"), auth = true)
        } catch (error: ApiException) {
            // The local session is cleared regardless; a dead server session expires on its own.
        } finally {
            tokens.clear()
        }
    }

    private suspend inline fun <reified B> signIn(path: List<String>, body: B): AuthUser {
        val response = execute(HttpMethod.Post, path) { jsonBody(body) }
        val token = response.headers["set-auth-token"]
        val user = decode<AuthUserResponse>(response).user
        if (token.isNullOrBlank() || user == null) {
            throw ApiException(response.status.value, "missing_session", "Sign-in finished without a session. Please try again.")
        }
        tokens.save(token)
        return user
    }

    // ---- Plumbing ----

    @PublishedApi
    internal inline fun <reified B> HttpRequestBuilder.jsonBody(body: B) {
        contentType(ContentType.Application.Json)
        setBody(body)
    }

    @PublishedApi
    internal suspend inline fun <reified T> call(
        method: HttpMethod,
        path: List<String>,
        auth: Boolean = false,
        noinline block: HttpRequestBuilder.() -> Unit = {},
    ): T = decode(execute(method, path, auth, block))

    @PublishedApi
    internal suspend fun send(
        method: HttpMethod,
        path: List<String>,
        auth: Boolean = false,
        block: HttpRequestBuilder.() -> Unit = {},
    ) {
        val response = execute(method, path, auth, block)
        if (!response.status.isSuccess()) throw error(response)
    }

    @PublishedApi
    internal suspend inline fun <reified T> decode(response: HttpResponse): T {
        if (!response.status.isSuccess()) throw error(response)
        return try {
            response.body()
        } catch (cause: CancellationException) {
            throw cause
        } catch (cause: Exception) {
            throw ApiException(response.status.value, "invalid_response", "The server sent an unexpected response.", cause)
        }
    }

    /**
     * Sends one request. Reads (GET) are retried twice on network failures with
     * backoff; writes are not, because only the caller knows whether a retry is safe.
     */
    @PublishedApi
    internal suspend fun execute(
        method: HttpMethod,
        path: List<String>,
        auth: Boolean = false,
        block: HttpRequestBuilder.() -> Unit,
    ): HttpResponse {
        val token = if (auth) tokens.load() ?: throw ApiException(401, "unauthorized", "Sign in to continue.") else null
        val attempts = if (method == HttpMethod.Get) 3 else 1
        var delayMs = 400L
        repeat(attempts) { attempt ->
            try {
                return http.request {
                    this.method = method
                    url {
                        takeFrom(baseUrl)
                        // encodeSlash: an osm:way/123 place key is one path segment.
                        appendPathSegments(path, encodeSlash = true)
                    }
                    token?.let { bearerAuth(it) }
                    block()
                }
            } catch (cause: CancellationException) {
                throw cause
            } catch (cause: Exception) {
                val transient = cause is IOException || cause is HttpRequestTimeoutException
                if (!transient) throw ApiException(0, "request_failed", cause.message ?: "Request failed.", cause)
                if (attempt == attempts - 1) throw ApiException.network(cause)
                delay(delayMs)
                delayMs *= 2
            }
        }
        error("unreachable")
    }

    @PublishedApi
    internal suspend fun error(response: HttpResponse): ApiException {
        val status = response.status.value
        val body = runCatching { json.decodeFromString<ErrorBody>(response.bodyAsText()) }.getOrNull()
        if (status == 401 && body?.code == null) tokens.clear()
        val message = body?.message?.takeIf { it.isNotBlank() } ?: when (status) {
            401 -> "Sign in to continue."
            404 -> "Not found."
            in 500..599 -> "Rollspot is having trouble right now. Try again in a moment."
            else -> "Request failed ($status)."
        }
        return ApiException(status, body?.code ?: body?.error, message)
    }
}
