package app.rollspot.shared.api

/**
 * Every failure from [RollspotApi]. Views show [message]; logic branches on [status] and [code].
 *
 * [status] is 0 when the request never got an HTTP response (offline, timeout).
 * [code] is the server's machine-readable reason when it sends one, e.g. Better Auth's
 * `EMAIL_NOT_VERIFIED` or the Worker's `unauthorized`.
 */
class ApiException(
    val status: Int,
    val code: String?,
    override val message: String,
    cause: Throwable? = null,
) : Exception(message, cause) {
    val isNetwork: Boolean get() = status == 0
    val isUnauthorized: Boolean get() = status == 401

    companion object {
        fun network(cause: Throwable) =
            ApiException(0, "network", "You appear to be offline. Check your connection and try again.", cause)
    }
}
