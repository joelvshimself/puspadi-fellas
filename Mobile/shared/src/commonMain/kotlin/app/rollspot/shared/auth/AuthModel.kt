package app.rollspot.shared.auth

import app.rollspot.shared.RollspotSdk
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
    data class SignedIn(val user: AuthUser, val providers: Set<String>) : AuthSession {
        /** Password change only makes sense for accounts that have a password. */
        val canChangePassword: Boolean get() = "credential" in providers
    }
}

/**
 * The screen the sign-in flow shows next. Both apps render the same steps in the
 * same order; only how each step looks differs.
 *
 * Email sign-up: Welcome → CreatePassword → Name → Mobility → VerifyEmail → Done
 * Email sign-in: Welcome → EmailFound → Done (or Name → Mobility → Done if onboarding was never finished)
 * Apple/Google:  Welcome → Done (or Name → Mobility → Done for new accounts)
 */
sealed interface AuthStep {
    data object Welcome : AuthStep
    data class EmailFound(val email: String) : AuthStep
    data class CreatePassword(val email: String) : AuthStep
    /** [suggestedName] prefills the field, e.g. the name Apple or Google shared. */
    data class Name(val suggestedName: String) : AuthStep
    data object Mobility : AuthStep
    data class VerifyEmail(val email: String) : AuthStep
    data object Done : AuthStep
}

/** An auth failure with a message ready to show the user. */
class AuthException(override val message: String, val code: String? = null, cause: Throwable? = null) :
    Exception(message, cause)

/**
 * Sign-in, sign-up and onboarding against Better Auth on the Worker. Views call
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

    // What the user has entered so far in a multi-step sign-up. Memory only, never persisted.
    private var email: String = ""
    private var password: String = ""
    private var displayName: String = ""
    private var mobilityAids: List<String> = emptyList()
    private var deferredIdToken: DeferredIdToken? = null

    private data class DeferredIdToken(val provider: String, val idToken: String, val nonce: String?)

    val isSignedIn: Boolean get() = _session.value is AuthSession.SignedIn

    /** Call at launch and when the app is opened from the verification link. */
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

    // ---- Email ----

    @Throws(Exception::class)
    suspend fun continueWithEmail(email: String): AuthStep = guarded {
        val normalized = AuthRules.normalizeEmail(email)
        if (!AuthRules.looksLikeEmail(normalized)) throw AuthException("Enter a valid email address.")
        resetDraft()
        this.email = normalized
        if (api.emailRegistered(normalized)) AuthStep.EmailFound(normalized) else AuthStep.CreatePassword(normalized)
    }

    @Throws(Exception::class)
    suspend fun signIn(email: String, password: String): AuthStep = guarded {
        val normalized = AuthRules.normalizeEmail(email)
        val user = api.signInWithEmail(normalized, password)
        accept(user)
        afterSignIn(suggestedName = user.name)
    }

    /** Validates locally; the account is only created once onboarding is answered. */
    @Throws(AuthException::class)
    fun choosePassword(password: String): AuthStep {
        if (!AuthRules.isValidPassword(password)) throw AuthException(AuthRules.PASSWORD_HINT)
        this.password = password
        return AuthStep.Name(suggestedName = displayName)
    }

    @Throws(AuthException::class)
    fun chooseName(name: String): AuthStep {
        val trimmed = name.trim()
        if (trimmed.isEmpty()) throw AuthException("Enter your name.")
        displayName = trimmed
        return AuthStep.Mobility
    }

    /**
     * Last onboarding answer. Depending on how the user arrived this creates the
     * email account (then asks them to verify), completes a deferred Apple/Google
     * sign-up, or saves the profile of an already signed-in user.
     */
    @Throws(Exception::class)
    suspend fun finishMobility(aids: List<String>): AuthStep = guarded {
        if (aids.isEmpty()) throw AuthException("Choose at least one option.")
        mobilityAids = aids.distinct()
        val deferred = deferredIdToken
        when {
            deferred != null -> {
                accept(api.signInWithIdToken(deferred.provider, deferred.idToken, deferred.nonce))
                saveOnboarding()
                AuthStep.Done
            }
            isSignedIn -> {
                saveOnboarding()
                AuthStep.Done
            }
            email.isNotEmpty() && password.isNotEmpty() -> {
                api.signUpWithEmail(displayName.ifEmpty { "You" }, email, password, RollspotSdk.AUTH_CALLBACK_URL)
                AuthStep.VerifyEmail(email)
            }
            else -> throw AuthException("Something went wrong. Start again.")
        }
    }

    /** "I've confirmed my email": signs in with the password from this sign-up and saves onboarding. */
    @Throws(Exception::class)
    suspend fun completeVerifiedSignUp(): AuthStep = guarded {
        if (!isSignedIn) {
            if (email.isEmpty() || password.isEmpty()) throw AuthException("Sign in with your email and password.")
            accept(api.signInWithEmail(email, password))
        }
        saveOnboarding()
        AuthStep.Done
    }

    @Throws(Exception::class)
    suspend fun resendVerificationEmail() = guarded {
        if (email.isEmpty()) throw AuthException("Start again with your email.")
        api.sendVerificationEmail(email, RollspotSdk.AUTH_CALLBACK_URL)
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

    // ---- Account ----

    @Throws(Exception::class)
    suspend fun changePassword(currentPassword: String, newPassword: String) = guarded {
        if (!AuthRules.isValidPassword(newPassword)) throw AuthException(AuthRules.PASSWORD_HINT)
        api.changePassword(currentPassword, newPassword)
    }

    @Throws(Exception::class)
    suspend fun signOut() {
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

    private suspend fun accept(user: AuthUser) {
        val providers = try {
            api.linkedProviders().toSet()
        } catch (error: ApiException) {
            emptySet()
        }
        _session.value = AuthSession.SignedIn(user, providers)
    }

    private fun resetDraft() {
        email = ""
        password = ""
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
            "EMAIL_NOT_VERIFIED" -> "Please tap the link in your email first, then try again."
            "INVALID_EMAIL_OR_PASSWORD", "INVALID_PASSWORD" -> "That email and password don't match."
            "PASSWORD_TOO_SHORT", "PASSWORD_TOO_LONG" -> AuthRules.PASSWORD_HINT
            "USER_ALREADY_EXISTS" -> "An account with this email already exists. Sign in instead."
            "INVALID_TOKEN", "ID_TOKEN_NOT_SUPPORTED", "PROVIDER_NOT_FOUND" ->
                "That sign-in method isn't available right now. Try email instead."
            else -> error.message
        }
    }
}
