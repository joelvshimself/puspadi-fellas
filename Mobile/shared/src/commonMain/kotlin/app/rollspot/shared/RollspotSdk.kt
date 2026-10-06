package app.rollspot.shared

import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.AuthModel
import app.rollspot.shared.auth.TokenStore
import app.rollspot.shared.places.PlaceRepository
import io.ktor.client.engine.HttpClientEngine

/**
 * The one object each app creates at launch (manual DI). Feature models take
 * what they need from here.
 *
 * Android: `RollspotSdk(BuildConfig.API_BASE_URL, AndroidTokenStore(context))`
 * iOS:     `RollspotSdk(baseUrl: ..., tokenStore: KeychainTokenStore())`
 */
class RollspotSdk(
    val baseUrl: String,
    val tokenStore: TokenStore,
    engine: HttpClientEngine? = null,
) {
    val api = RollspotApi(baseUrl, tokenStore, engine)
    val places = PlaceRepository(api)
    val auth = AuthModel(api)

    companion object {
        const val PRODUCTION_URL = "https://api.rollspot.app"
        /** Deep link the verification email opens; both apps register the `puspadi` scheme. */
        const val AUTH_CALLBACK_URL = "puspadi://auth/callback"
    }
}
