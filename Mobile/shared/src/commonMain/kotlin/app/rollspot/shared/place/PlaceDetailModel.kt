package app.rollspot.shared.place

import app.rollspot.shared.api.FeatureGrade
import app.rollspot.shared.api.Place
import app.rollspot.shared.api.PlacePhoto
import app.rollspot.shared.api.ReviewPhoto
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.places.OverallAccessibility
import app.rollspot.shared.places.collapseAccessibility
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.cancel
import kotlinx.coroutines.coroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** One tile in the place page's Photos tab. */
data class GalleryPhoto(
    val url: String,
    /** "Venue" for curated photos, otherwise the facility label (Lobby, Elevator, …). */
    val label: String,
    val caption: String,
    val isVenuePhoto: Boolean,
)

/** Everything the place page shows, loaded together so both apps render the same numbers. */
data class PlaceDetail(
    val place: Place,
    val grades: List<FeatureGrade>,
    val overall: OverallAccessibility,
    /** One entry per facility verdict, newest first. */
    val reviews: List<FacilityReview>,
    /** Curated photos of the venue itself. */
    val photos: List<PlacePhoto>,
    /** Community photos, labelled by facility. */
    val reviewPhotos: List<ReviewPhoto>,
    /** True when only the community photos failed to load; the rest of the page is still good. */
    val reviewPhotosLoadFailed: Boolean,
) {
    /** Reviews people wrote, not facility verdicts: one review covering three facilities counts once. */
    val reviewCount: Int get() = reviews.distinctBy { it.reviewId }.size

    /**
     * The Photos tab, identical on both apps: curated venue photos first, then community
     * photos, each URL once.
     */
    val gallery: List<GalleryPhoto>
        get() = (
            photos.map { GalleryPhoto(it.url, VENUE_LABEL, it.credit.orEmpty(), isVenuePhoto = true) } +
                reviewPhotos.map { GalleryPhoto(it.url, it.label, it.caption.trim(), isVenuePhoto = false) }
            ).distinctBy { it.url }

    companion object {
        const val VENUE_LABEL = "Venue"
    }

    fun reviewsFor(kind: FacilityKind): List<FacilityReview> = reviews.filter { it.kind == kind }

    fun hasReviews(kind: FacilityKind): Boolean = reviews.any { it.kind == kind }

    /**
     * Every tag the community confirmed for this facility, newest review first, each once.
     * Not just the latest review's: one thin review shouldn't hide what earlier reviewers
     * reported. "Not available" is a verdict, not a feature, so it never appears here.
     */
    fun providedTagsFor(kind: FacilityKind): List<String> =
        reviewsFor(kind).flatMap { it.providedTags }.filter { it != TAG_NOT_AVAILABLE }.distinct()

    /** Reviewers said this facility doesn't exist here. An entrance always exists. */
    fun isUnavailable(kind: FacilityKind): Boolean =
        kind != FacilityKind.ENTRANCE && reviews.any { it.kind == kind && TAG_NOT_AVAILABLE in it.providedTags }

    /**
     * Opening sentences of the newest reviews that actually say something. Filters BEFORE
     * taking [limit]: most reviews answer only the structured questions, so slicing first
     * left this empty while a real note sat fourth in the list. Nothing is invented to pad it.
     */
    fun noteSnippets(kind: FacilityKind, limit: Int = 3): List<String> =
        reviewsFor(kind).filter { it.hasBodyText }.map { it.firstSentence }.filter { it.isNotEmpty() }.take(limit)

    /** Community photos for one facility. Entrance covers lobby, basement and side exits. */
    fun photosFor(kind: FacilityKind): List<ReviewPhoto> = reviewPhotos.filter { photo ->
        val facility = photo.facility.lowercase()
        when (kind) {
            FacilityKind.ENTRANCE -> listOf("lobby", "basement", "entrance", "exit").any { it in facility }
            FacilityKind.ELEVATOR -> "elevator" in facility
            FacilityKind.TOILET -> "toilet" in facility
        }
    }
}

sealed interface PlaceDetailState {
    data object Loading : PlaceDetailState

    /** Has reviews or community photos. */
    data class Loaded(val detail: PlaceDetail) : PlaceDetailState

    /** "Not reviewed yet": no reviews and no community photos. [detail] still has the place and any grade. */
    data class Empty(val detail: PlaceDetail) : PlaceDetailState

    data class Error(val message: String) : PlaceDetailState
}

/**
 * Loads a place's accessibility grade, reviews and photos in parallel and exposes them as
 * one [state]. A failed reviews fetch is an [PlaceDetailState.Error], never `Empty`: an
 * outage must not read as "nobody has reviewed this place".
 */
class PlaceDetailModel(
    private val api: RollspotApi,
    placeKey: String,
    parentScope: CoroutineScope = CoroutineScope(Dispatchers.Default),
) {
    /** A child of [parentScope], so [close] stops this model without cancelling whoever owns the parent. */
    private val scope = CoroutineScope(parentScope.coroutineContext + SupervisorJob(parentScope.coroutineContext[Job]))

    private val mutableState = MutableStateFlow<PlaceDetailState>(PlaceDetailState.Loading)
    val state: StateFlow<PlaceDetailState> = mutableState.asStateFlow()

    var placeKey: String = placeKey
        private set

    private var job: Job? = null
    private var generation = 0

    /** Starts loading; call again (or [refresh]) after a review is submitted. */
    fun load() = refresh()

    /**
     * Latest call wins: a refresh cancels the one in flight, so a just-submitted review can't
     * be hidden by an older response landing after it. Content already on screen stays until
     * the new result arrives.
     */
    fun refresh() {
        job?.cancel()
        job = scope.launch { reload() }
    }

    /**
     * Same as [refresh], but suspends until this load finishes and returns the resulting
     * state, for callers that want to `await` it. Call from one thread (the UI thread):
     * the generation counter that makes the latest call win isn't synchronised.
     */
    @Throws(CancellationException::class)
    suspend fun reload(): PlaceDetailState {
        val mine = ++generation
        val result = try {
            fetch()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            // Keep showing what we have rather than replacing real content with an error.
            val current = mutableState.value
            if (current is PlaceDetailState.Loaded || current is PlaceDetailState.Empty) current
            else PlaceDetailState.Error(e.message ?: "Couldn't load this place.")
        }
        // A newer reload started while this one was in flight; its answer is the fresher one.
        if (mine == generation) mutableState.value = result
        return mutableState.value
    }

    /** After a submit the server may file the review under a canonical place ID; follow it. */
    fun adoptPlaceKey(canonical: String) {
        if (canonical.isNotEmpty()) placeKey = canonical
    }

    fun close() {
        scope.cancel()
    }

    private suspend fun fetch(): PlaceDetailState = coroutineScope {
        val key = placeKey
        val place = async { api.place(key) }
        val reviews = async { api.placeReviews(key) }
        val venuePhotos = async { optional { api.placePhotos(key) } }
        val reviewPhotos = async { optional { api.placeReviewPhotos(key) } }

        val loadedPlace = place.await()
        val facilityReviews = mapPlaceReviews(reviews.await())
        val community = reviewPhotos.await()
        val detail = PlaceDetail(
            place = loadedPlace,
            grades = loadedPlace.grade,
            overall = collapseAccessibility(loadedPlace.grade),
            reviews = facilityReviews,
            photos = venuePhotos.await()?.sortedBy { it.sortOrder }.orEmpty(),
            reviewPhotos = community?.photos.orEmpty(),
            reviewPhotosLoadFailed = community == null,
        )
        if (detail.reviews.isEmpty() && detail.reviewPhotos.isEmpty() && !detail.reviewPhotosLoadFailed) {
            PlaceDetailState.Empty(detail)
        } else {
            PlaceDetailState.Loaded(detail)
        }
    }

    /** Null on failure, for parts of the page that can degrade without failing the whole load. */
    private suspend fun <T> optional(block: suspend () -> T): T? =
        try {
            block()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            null
        }
}
