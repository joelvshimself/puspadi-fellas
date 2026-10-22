package app.rollspot.shared.place

import app.rollspot.shared.api.PlaceReview
import app.rollspot.shared.api.PlaceReviewEntrance
import app.rollspot.shared.api.ReviewPhoto
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import app.rollspot.shared.places.OverallAccessibility
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertTrue

private fun review(
    id: String,
    createdAt: String = "2026-08-12T21:51:39.123Z",
    reviewer: String? = null,
    notes: String? = null,
    entrances: List<PlaceReviewEntrance> = emptyList(),
    elevatorExists: Boolean? = null,
    elevatorAccessible: Boolean? = null,
    elevatorBlockers: List<String> = emptyList(),
    elevatorText: String? = null,
    hasToilet: Boolean? = null,
    toiletText: String? = null,
) = PlaceReview(
    id = id,
    createdAt = createdAt,
    notes = notes,
    elevatorExists = elevatorExists,
    elevatorWheelchairAccessible = elevatorAccessible,
    elevatorBlockers = elevatorBlockers,
    elevatorReviewText = elevatorText,
    hasDisabledToilet = hasToilet,
    toiletReviewText = toiletText,
    reviewEntrances = entrances,
    reviewerName = reviewer,
)

private fun entrance(
    location: String = "lobby",
    ramp: Boolean? = null,
    rails: Boolean? = null,
    door: String? = null,
    wide: Boolean? = null,
    text: String? = null,
    photos: List<String> = emptyList(),
) = PlaceReviewEntrance(
    location = location,
    hasDropoffRamp = ramp,
    hasRails = rails,
    doorType = door,
    isWideEnough = wide,
    reviewText = text,
    photoUrls = photos,
)

class FacilityReviewMappingTest {
    @Test
    fun oneStoredReviewFansOutPerFacility() {
        val mapped = mapPlaceReviews(
            listOf(
                review(
                    "r1",
                    entrances = listOf(entrance(ramp = true, rails = true, door = "automatic", wide = true)),
                    elevatorExists = true,
                    elevatorAccessible = true,
                    hasToilet = true,
                ),
            ),
        )
        assertEquals(setOf(FacilityKind.ENTRANCE, FacilityKind.ELEVATOR, FacilityKind.TOILET), mapped.map { it.kind }.toSet())
        assertEquals(
            listOf("RAMP", "HANDRAIL", "AUTOMATIC DOORS", "WIDE ENTRANCE"),
            mapped.single { it.kind == FacilityKind.ENTRANCE }.providedTags,
        )
        assertEquals(listOf("WHEELCHAIR ACCESSIBLE"), mapped.single { it.kind == FacilityKind.ELEVATOR }.providedTags)
        assertEquals(listOf("ACCESSIBLE TOILET"), mapped.single { it.kind == FacilityKind.TOILET }.providedTags)
    }

    @Test
    fun entranceWithNothingToSayIsDropped() {
        val mapped = mapPlaceReviews(listOf(review("r1", entrances = listOf(entrance(text = "  ")))))
        assertTrue(mapped.isEmpty())
    }

    @Test
    fun aggregateNotesNeverBecomeAFacilityBody() {
        val mapped = mapPlaceReviews(
            listOf(review("r1", notes = "[entrance:lobby] steep", entrances = listOf(entrance(ramp = true)))),
        )
        assertFalse(mapped.single().hasBodyText)
    }

    @Test
    fun unavailableFacilitiesAreTaggedNotAvailable() {
        val mapped = mapPlaceReviews(listOf(review("r1", elevatorExists = false, hasToilet = false)))
        assertEquals(listOf(TAG_NOT_AVAILABLE), mapped.single { it.kind == FacilityKind.ELEVATOR }.providedTags)
        assertEquals(listOf(TAG_NOT_AVAILABLE), mapped.single { it.kind == FacilityKind.TOILET }.providedTags)
    }

    @Test
    fun elevatorBlockersBecomeTags() {
        val mapped = mapPlaceReviews(
            listOf(review("r1", elevatorExists = true, elevatorAccessible = false, elevatorBlockers = listOf("no_ramp", "too_small"))),
        )
        assertEquals(listOf("LIMITED ACCESS", "NO RAMP", "TOO SMALL"), mapped.single().providedTags)
    }

    @Test
    fun elevatorThatExistsButHasNoDetailGetsPlainTag() {
        val mapped = mapPlaceReviews(listOf(review("r1", elevatorExists = true)))
        assertEquals(listOf("ELEVATOR"), mapped.single().providedTags)
    }

    @Test
    fun repeatVisitsCollapseToTheNewestPerPersonPerFacility() {
        val mapped = mapPlaceReviews(
            listOf(
                review("old", createdAt = "2026-01-01T00:00:00.000Z", reviewer = "Aarief", elevatorExists = true, elevatorAccessible = false),
                review("new", createdAt = "2026-06-01T00:00:00.000Z", reviewer = "Aarief", elevatorExists = true, elevatorAccessible = true),
            ),
        )
        assertEquals("new", mapped.single().reviewId)
    }

    @Test
    fun collapsingIsPerFacilityNotPerReview() {
        val mapped = mapPlaceReviews(
            listOf(
                review("old", createdAt = "2026-01-01T00:00:00.000Z", reviewer = "Aarief", entrances = listOf(entrance(ramp = true))),
                review("new", createdAt = "2026-06-01T00:00:00.000Z", reviewer = "Aarief", hasToilet = true),
            ),
        )
        assertEquals(setOf("old", "new"), mapped.map { it.reviewId }.toSet())
    }

    @Test
    fun anonymousReviewsAreNeverCollapsed() {
        val mapped = mapPlaceReviews(
            listOf(
                review("a", createdAt = "2026-01-01T00:00:00.000Z", elevatorExists = true),
                review("b", createdAt = "2026-02-01T00:00:00.000Z", elevatorExists = true),
            ),
        )
        assertEquals(2, mapped.size)
    }

    @Test
    fun differentEntrancesFromOneReviewStaySeparate() {
        val mapped = mapPlaceReviews(
            listOf(
                review(
                    "r1",
                    reviewer = "Aarief",
                    entrances = listOf(entrance("lobby", ramp = true), entrance("basement", door = "manual")),
                ),
            ),
        )
        assertEquals(2, mapped.size)
    }

    @Test
    fun newestFirstAndSharedTimestampsListToiletBeforeElevatorBeforeEntrance() {
        val mapped = mapPlaceReviews(
            listOf(
                review("older", createdAt = "2026-01-01T00:00:00.000Z", elevatorExists = true),
                review("same", entrances = listOf(entrance(ramp = true)), elevatorExists = true, hasToilet = true),
            ),
        )
        assertEquals(
            listOf(FacilityKind.TOILET, FacilityKind.ELEVATOR, FacilityKind.ENTRANCE, FacilityKind.ELEVATOR),
            mapped.map { it.kind },
        )
        assertEquals("older", mapped.last().reviewId)
    }

    @Test
    fun dateLabelAndFirstSentence() {
        val mapped = mapPlaceReviews(
            listOf(review("r1", createdAt = "2026-08-02T21:51:39.123Z", elevatorExists = true, elevatorText = "  Hard to find. Buttons high.  ")),
        ).single()
        assertEquals("2 Aug 2026", mapped.dateLabel)
        assertEquals("Hard to find.", mapped.firstSentence)
        assertEquals("", dateLabelOf("garbage"))
        assertEquals("no punctuation", firstSentenceOf(" no punctuation "))
    }
}

class PlaceDetailTest {
    private val json = headersOf(HttpHeaders.ContentType, "application/json")

    private val placeJson = """{"status":"ok","place":{"id":"p1","osm_ref":"way/1","name":"Park23 Mall","lat":-8.7,"lng":115.1,
        "grade":[{"feature":"entrance","best_value":"yes","confidence":1.0},{"feature":"elevator","best_value":"limited","confidence":0.5}]}}"""

    private fun reviewsJson(vararg reviews: String) = """{"status":"ok","reviews":[${reviews.joinToString(",")}]}"""

    private val oneReview = """{"id":"r1","created_at":"2026-08-12T21:51:39.123Z","elevator_exists":true,
        "elevator_wheelchair_accessible":true,"elevator_review_text":"Hard to find. Wide door.","reviewer_name":"Aarief"}"""

    private fun model(
        scope: kotlinx.coroutines.CoroutineScope,
        reviews: () -> Pair<HttpStatusCode, String> = { HttpStatusCode.OK to reviewsJson(oneReview) },
        reviewPhotos: () -> Pair<HttpStatusCode, String> = {
            HttpStatusCode.OK to """{"placeId":"p1","photos":[{"url":"https://x/e.jpg","facility":"elevator","label":"Elevator","caption":""}]}"""
        },
    ): PlaceDetailModel {
        val engine = MockEngine { request ->
            val path = request.url.encodedPath
            val (status, body) = when {
                path.endsWith("/reviews") -> reviews()
                path.endsWith("/review-photos") -> reviewPhotos()
                path.endsWith("/photos") -> HttpStatusCode.OK to """[{"id":"ph1","url":"https://x/v.jpg","source":"venue","sort_order":0}]"""
                else -> HttpStatusCode.OK to placeJson
            }
            respond(body, status, json)
        }
        return PlaceDetailModel(RollspotApi("https://api.test", InMemoryTokenStore(), engine), "p1", scope)
    }

    private suspend fun PlaceDetailModel.settled() = state.first { it !is PlaceDetailState.Loading }

    @Test
    fun loadsGradeReviewsAndPhotosTogether() = runTest {
        val model = model(this).also { it.load() }
        val loaded = assertIs<PlaceDetailState.Loaded>(model.settled())
        val detail = loaded.detail
        assertEquals("Park23 Mall", detail.place.name)
        assertEquals(OverallAccessibility.PARTIALLY_ACCESSIBLE, detail.overall)
        assertEquals(1, detail.reviewCount)
        assertEquals(listOf("Hard to find."), detail.noteSnippets(FacilityKind.ELEVATOR))
        assertEquals(1, detail.photosFor(FacilityKind.ELEVATOR).size)
        assertEquals(1, detail.photos.size)
        model.close()
    }

    @Test
    fun reloadReturnsTheNewStateAndKeepsContentThroughAFailedRefresh() = runTest {
        var fail = false
        val model = model(this, reviews = {
            if (fail) HttpStatusCode.InternalServerError to """{"error":"boom"}""" else HttpStatusCode.OK to reviewsJson(oneReview)
        })
        assertIs<PlaceDetailState.Loaded>(model.reload())
        fail = true
        // A failed refresh must not replace real content with an error.
        assertIs<PlaceDetailState.Loaded>(model.reload())
        assertIs<PlaceDetailState.Loaded>(model.state.value)
        model.close()
    }

    @Test
    fun noReviewsAndNoPhotosIsEmptyNotLoaded() = runTest {
        val model = model(
            this,
            reviews = { HttpStatusCode.OK to reviewsJson() },
            reviewPhotos = { HttpStatusCode.OK to """{"placeId":"p1","photos":[]}""" },
        ).also { it.load() }
        val empty = assertIs<PlaceDetailState.Empty>(model.settled())
        assertEquals(0, empty.detail.reviewCount)
        model.close()
    }

    @Test
    fun failedReviewsFetchIsAnErrorNeverEmpty() = runTest {
        val model = model(this, reviews = { HttpStatusCode.InternalServerError to """{"error":"boom"}""" }).also { it.load() }
        assertIs<PlaceDetailState.Error>(model.settled())
        model.close()
    }

    @Test
    fun failedCommunityPhotosDegradeInsteadOfFailingThePage() = runTest {
        val model = model(
            this,
            reviews = { HttpStatusCode.OK to reviewsJson() },
            reviewPhotos = { HttpStatusCode.InternalServerError to """{"error":"boom"}""" },
        ).also { it.load() }
        // Not Empty either: we can't claim "nobody contributed" when the photo call failed.
        val loaded = assertIs<PlaceDetailState.Loaded>(model.settled())
        assertTrue(loaded.detail.reviewPhotosLoadFailed)
        model.close()
    }

    @Test
    fun providedTagsAreTheDistinctUnionAcrossReviewsWithoutNotAvailable() {
        val reviews = mapPlaceReviews(
            listOf(
                review("a", createdAt = "2026-01-01T00:00:00.000Z", entrances = listOf(entrance(ramp = true, rails = true))),
                review("b", createdAt = "2026-02-01T00:00:00.000Z", entrances = listOf(entrance(rails = true, door = "manual"))),
                review("c", createdAt = "2026-03-01T00:00:00.000Z", elevatorExists = false),
            ),
        )
        val detail = PlaceDetail(
            place = app.rollspot.shared.api.Place(id = "p", osmRef = "way/1", name = "n", lat = 0.0, lng = 0.0),
            grades = emptyList(), overall = OverallAccessibility.NO_DATA, reviews = reviews,
            photos = emptyList(), reviewPhotos = emptyList(), reviewPhotosLoadFailed = false,
        )
        // Newest review first (b), then what only the older one added (a).
        assertEquals(listOf("HANDRAIL", "MANUAL DOORS", "RAMP"), detail.providedTagsFor(FacilityKind.ENTRANCE))
        assertEquals(emptyList(), detail.providedTagsFor(FacilityKind.ELEVATOR))
    }

    @Test
    fun isUnavailableOnlyForElevatorAndToilet() {
        val unavailable = mapPlaceReviews(listOf(review("r1", elevatorExists = false, entrances = listOf(entrance(ramp = true)))))
        val detail = PlaceDetail(
            place = app.rollspot.shared.api.Place(id = "p", osmRef = "way/1", name = "n", lat = 0.0, lng = 0.0),
            grades = emptyList(),
            overall = OverallAccessibility.NO_DATA,
            reviews = unavailable,
            photos = emptyList(),
            reviewPhotos = listOf(ReviewPhoto("u", "lobby", "Lobby")),
            reviewPhotosLoadFailed = false,
        )
        assertTrue(detail.isUnavailable(FacilityKind.ELEVATOR))
        assertFalse(detail.isUnavailable(FacilityKind.ENTRANCE))
        assertFalse(detail.isUnavailable(FacilityKind.TOILET))
        assertEquals(1, detail.photosFor(FacilityKind.ENTRANCE).size)
    }

    @Test
    fun galleryIsVenuePhotosThenCommunityPhotosEachUrlOnce() {
        val detail = PlaceDetail(
            place = app.rollspot.shared.api.Place(id = "p", osmRef = "way/1", name = "n", lat = 0.0, lng = 0.0),
            grades = emptyList(),
            overall = OverallAccessibility.NO_DATA,
            reviews = emptyList(),
            photos = listOf(app.rollspot.shared.api.PlacePhoto("v1", "https://x/venue.jpg", "community", credit = "Mall")),
            reviewPhotos = listOf(
                ReviewPhoto("https://x/lobby.jpg", "lobby", "Lobby", caption = " ramp at the door "),
                ReviewPhoto("https://x/venue.jpg", "lobby", "Lobby"),
            ),
            reviewPhotosLoadFailed = false,
        )
        assertEquals(listOf("https://x/venue.jpg", "https://x/lobby.jpg"), detail.gallery.map { it.url })
        assertEquals(PlaceDetail.VENUE_LABEL, detail.gallery[0].label)
        assertTrue(detail.gallery[0].isVenuePhoto)
        assertEquals("ramp at the door", detail.gallery[1].caption)
    }
}

class ReviewCountTest {
    @Test
    fun oneReviewCoveringSeveralFacilitiesCountsOnce() {
        fun review(id: String, kind: FacilityKind) = FacilityReview(
            id = "$id:$kind", reviewId = id, kind = kind, createdAt = "2026-10-22T00:00:00Z", bodyText = "",
            providedTags = emptyList(), photoUrls = emptyList(), photoCaptions = emptyList(),
            reviewerName = null, reviewerRole = null, reviewerAvatarUrl = null, reviewerIsPseudonym = false,
        )
        val detail = PlaceDetail(
            place = app.rollspot.shared.api.Place(id = "p1", osmRef = "way/1", name = "P", lat = 0.0, lng = 0.0),
            grades = emptyList(), overall = app.rollspot.shared.places.OverallAccessibility.NO_DATA,
            reviews = listOf(review("a", FacilityKind.ENTRANCE), review("a", FacilityKind.ELEVATOR), review("b", FacilityKind.TOILET)),
            photos = emptyList(), reviewPhotos = emptyList(), reviewPhotosLoadFailed = false,
        )
        kotlin.test.assertEquals(2, detail.reviewCount)
    }
}
