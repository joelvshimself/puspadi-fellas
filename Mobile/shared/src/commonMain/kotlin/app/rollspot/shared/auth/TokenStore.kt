package app.rollspot.shared.auth

/**
 * Where the Better Auth session token lives. Each platform supplies a secure
 * implementation: the Keychain on iOS (written in Swift, `KeychainTokenStore`),
 * the Android Keystore on Android ([AndroidTokenStore]).
 */
interface TokenStore {
    fun load(): String?
    fun save(token: String)
    fun clear()
}

/** For tests and previews. */
class InMemoryTokenStore(private var token: String? = null) : TokenStore {
    override fun load(): String? = token
    override fun save(token: String) { this.token = token }
    override fun clear() { token = null }
}
