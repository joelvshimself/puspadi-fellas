package app.rollspot.shared.auth

import app.rollspot.shared.api.ApiException
import app.rollspot.shared.api.AuthUser
import app.rollspot.shared.api.ProfileUpdate
import app.rollspot.shared.api.RollspotApi
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex

sealed interface AuthSession {
    /** Launch: the stored token hasn't been checked yet. */
    data object Unknown : AuthSession
    data object SignedOut : AuthSession
    data class SignedIn(val user: AuthUser) : AuthSession
}

/**
 * The screen the sign-in flow shows next. Both apps render the same steps in the
 * same order; only how each step looks differs. Sign-in is Apple or Google only.
 *
 * Returning user: Welcome → Done
 * New account, or onboarding never finished: Welcome → Name → Mobility → AllSet → Done
 */
sealed interface AuthStep {
    data object Welcome : AuthStep
    /** [suggestedName] prefills the field, e.g. the name Apple or Google shared. */
    data class Name(val suggestedName: String) : AuthStep
    data object Mobility : AuthStep
    /** "You're all set!" after onboarding; its button finishes the flow. */
    data object AllSet : AuthStep
    data object Done : AuthStep
}

/** An auth failure with a message ready to show the user. */
class AuthException(override val message: String, val code: String? = null, cause: Throwable? = null) :
    Exception(message, cause)

/**
 * Apple/Google sign-in and onboarding against Better Auth on the Worker. Views call
 * one action per button and show the [AuthStep] it returns; nothing about the
 * flow is decided in Swift or Compose.
 *
 * Errors are thrown as [AuthException] with user-facing copy.
 */
class AuthModel(private val api: RollspotApi) {
    private val _session = MutableStateFlow<AuthSession>(AuthSession.Unknown)
    val session: StateFlow<AuthSession> = _session.asStateFlow()

    /** One auth request at a time: a double tap must not create two accounts or two sessions. */
    private val inFlight = Mutex()

    // What the user has entered so far in onboarding. Memory only, never persisted.
    private var displayName: String = ""
    private var mobilityAids: List<String> = emptyList()
    private var deferredIdToken: DeferredIdToken? = null

    private data class DeferredIdToken(val provider: String, val idToken: String, val nonce: String?)

    val isSignedIn: Boolean get() = _session.value is AuthSession.SignedIn

    /** Call at launch. */
    @Throws(Exception::class)
    suspend fun restore() {
        val user = try {
            api.currentUser()
        } catch (error: ApiException) {
            // Offline at launch: keep the stored token and try again later rather than signing out.
            if (error.isNetwork) {
                if (_session.value is AuthSession.Unknown) _session.value = AuthSession.SignedOut
                return
            }
            null
        }
        if (user == null) _session.value = AuthSession.SignedOut else accept(user)
    }

    // ---- Apple / Google ----

    /**
     * Native Apple or Google sign-in produced an ID token. [isNewAccount] is true
     * when the provider says this is the first authorization (Apple shares the
     * name only then): the account is created after onboarding instead of now.
     */
    @Throws(Exception::class)
    suspend fun signInWithIdToken(
        provider: String,
        idToken: String,
        nonce: String?,
        suggestedName: String?,
        isNewAccount: Boolean,
    ): AuthStep = guarded {
        resetDraft()
        displayName = suggestedName?.trim().orEmpty()
        if (isNewAccount) {
            deferredIdToken = DeferredIdToken(provider, idToken, nonce)
            return@guarded AuthStep.Name(suggestedName = displayName)
        }
        val user = api.signInWithIdToken(provider, idToken, nonce)
        accept(user)
        afterSignIn(suggestedName = suggestedName ?: user.name)
    }

    // ---- Onboarding ----

    @Throws(AuthException::class)
    fun chooseName(name: String): AuthStep {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) throw AuthException("Enter your name.")
        displayName = trimmed
        return AuthStep.Mobility
    }

    /**
     * Last onboarding answer. Completes a deferred Apple/Google sign-up, or saves
     * the profile of an already signed-in user.
     */
    @Throws(Exception::class)
    suspend fun finishMobility(aids: List<String>): AuthStep = guarded {
        if (aids.isEmpty()) throw AuthException("Choose at least one option.")
        mobilityAids = aids.distinct()
        deferredIdToken?.let { accept(api.signInWithIdToken(it.provider, it.idToken, it.nonce)) }
        if (!isSignedIn) throw AuthException("Something went wrong. Start again.")
        saveOnboarding()
        AuthStep.AllSet
    }

    // ---- Account ----

    /** Deletes the account for good (App Store requirement), then behaves like sign-out. */
    @Throws(Exception::class)
    suspend fun deleteAccount() = guarded {
        api.deleteAccount()
        resetDraft()
        _session.value = AuthSession.SignedOut
    }

    /** Runs while the session is still valid, e.g. to stop pushes to this phone. Set by [app.rollspot.shared.RollspotSdk]. */
    internal var beforeSignOut: (suspend () -> Unit)? = null

    @Throws(Exception::class)
    suspend fun signOut() {
        runCatching { beforeSignOut?.invoke() }
        api.signOut()
        resetDraft()
        _session.value = AuthSession.SignedOut
    }

    // ---- Internals ----

    private suspend fun afterSignIn(suggestedName: String?): AuthStep {
        val profile = api.profile()
        if (!profile.needsOnboarding) return AuthStep.Done
        displayName = profile.displayName ?: suggestedName.orEmpty()
        return AuthStep.Name(suggestedName = displayName)
    }

    private suspend fun saveOnboarding() {
        api.updateProfile(ProfileUpdate(displayName = displayName.ifEmpty { null }, mobilityAids = mobilityAids))
        resetDraft()
    }

    private fun accept(user: AuthUser) {
        _session.value = AuthSession.SignedIn(user)
    }

    private fun resetDraft() {
        displayName = ""
        mobilityAids = emptyList()
        deferredIdToken = null
    }

    private suspend fun <T> guarded(block: suspend () -> T): T {
        if (!inFlight.tryLock()) throw AuthException("Please wait for the current sign-in to finish.")
        try {
            return block()
        } catch (error: CancellationException) {
            throw error
        } catch (error: AuthException) {
            throw error
        } catch (error: ApiException) {
            throw AuthException(messageFor(error), error.code, error)
        } finally {
            inFlight.unlock()
        }
    }

    companion object {
        /** Better Auth error codes → what the user reads. Same words on both apps. */
        fun messageFor(error: ApiException): String = when (error.code) {
            "INVALID_TOKEN", "ID_TOKEN_NOT_SUPPORTED", "PROVIDER_NOT_FOUND" ->
                "That sign-in method isn't available right now. Try the other one."
            "auth_not_configured" -> "Sign in isn't available yet. Try again later."
            else -> error.message
        }
    }
}
