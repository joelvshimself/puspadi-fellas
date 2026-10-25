package app.rollspot.shared

import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.AuthModel
import app.rollspot.shared.auth.AuthSession
import app.rollspot.shared.auth.TokenStore
import app.rollspot.shared.drafts.ContributeDrafts
import app.rollspot.shared.drafts.DraftStorage
import app.rollspot.shared.drafts.InMemoryDraftStorage
import app.rollspot.shared.map.PlaceSearchProvider
import app.rollspot.shared.map.RepositoryPlaceSearchProvider
import app.rollspot.shared.place.PlaceDetailModel
import app.rollspot.shared.places.PlaceRepository
import app.rollspot.shared.profile.MyReviewsModel
import app.rollspot.shared.profile.ProfileModel
import app.rollspot.shared.reviews.ReviewEditModel
import app.rollspot.shared.reviews.ReviewModel
import app.rollspot.shared.saved.SavedPlacesModel
import io.ktor.client.engine.HttpClientEngine
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.distinctUntilChangedBy
import kotlinx.coroutines.launch

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
    /** Where unfinished contributions are kept: `FileDraftStorage(<app files dir>)` in the apps. */
    draftStorage: DraftStorage = InMemoryDraftStorage(),
) {
    val api = RollspotApi(baseUrl, tokenStore, engine)
    val places = PlaceRepository(api)
    val auth = AuthModel(api)

    /** What [app.rollspot.shared.map.MapModel] reads places from. */
    val placeSearch: PlaceSearchProvider = RepositoryPlaceSearchProvider(places)

    /** One per place page; call `close()` when the page goes away. */
    fun placeDetailModel(placeKey: String) = PlaceDetailModel(api, placeKey)
    val reviews = ReviewModel(api)
    /** Edit Response page for one of the signed-in user's reviews. */
    fun reviewEditModel(reviewId: String) = ReviewEditModel(api, reviewId)

    val profile = ProfileModel(api)
    val myReviews = MyReviewsModel(api)
    val saved = SavedPlacesModel(api) { auth.isSignedIn }
    /** Unfinished contributions and the Home "Continue Survey" banner. */
    val drafts = ContributeDrafts(draftStorage)

    /** Lives as long as the app: keeps per-user models in step with the session. */
    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    init {
        appScope.launch {
            auth.session.distinctUntilChangedBy { (it as? AuthSession.SignedIn)?.user?.id }.collect { session ->
                when (session) {
                    // Saved state drives the bookmark on every place page, so load it right away.
                    is AuthSession.SignedIn -> {
                        drafts.setUser(session.user.id)
                        runCatching { saved.load() }
                    }
                    else -> {
                        drafts.setUser(null)
                        saved.clear()
                        profile.clear()
                        myReviews.clear()
                    }
                }
            }
        }
    }

    companion object {
        const val PRODUCTION_URL = "https://rollspot-api.joecast208.workers.dev"
        /** Deep link the verification email opens; both apps register the `puspadi` scheme. */
        const val AUTH_CALLBACK_URL = "puspadi://auth/callback"
    }
}
