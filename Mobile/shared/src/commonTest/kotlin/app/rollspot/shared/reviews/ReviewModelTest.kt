package app.rollspot.shared.reviews

import app.rollspot.shared.api.ReviewSubmission
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.client.request.HttpRequestData
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class ReviewModelTest {
    private val jsonHeaders = headersOf(HttpHeaders.ContentType, "application/json")
    private val requests = mutableListOf<HttpRequestData>()

    private fun model(handler: suspend io.ktor.client.engine.mock.MockRequestHandleScope.(HttpRequestData) -> io.ktor.client.request.HttpResponseData): ReviewModel {
        val api = RollspotApi(
            "https://api.test",
            InMemoryTokenStore("session"),
            MockEngine { request ->
                requests += request
                handler(request)
            },
        )
        return ReviewModel(api)
    }

    @Test
    fun submitUploadsThenPostsReview() = runTest {
        val model = model { request ->
            when {
                request.url.encodedPath.contains("/media/review-photos/") -> {
                    respond("""{"url":"https://api.test/v1/media/reviews/u/p/sub/file1.jpg"}""", headers = jsonHeaders)
                }
                request.url.encodedPath == "/v1/reviews" -> {
                    respond(
                        """{"status":"ok","reviewId":"r1","placeId":"p1","grade":[]}""",
                        HttpStatusCode.Created,
                        jsonHeaders,
                    )
                }
                else -> error("unexpected ${request.url.encodedPath}")
            }
        }

        val submission = ReviewSubmission(submissionId = "sub-1", placeId = "p1")
        val photos = listOf(
            PendingReviewPhoto(ReviewPhotoSlot.Lobby, "file1", jpeg = byteArrayOf(0xFF, 0xD8, 0xFF)),
        )
        val submitted = model.submit(submission, photos)
        assertEquals("r1", submitted.reviewId)

        assertEquals(2, requests.size)
        val upload = requests.first()
        assertEquals("/v1/media/review-photos/p1/sub-1/file1", upload.url.encodedPath)
        assertEquals("POST", requests[1].method.value)
        val outcome = model.state.value.outcome as ReviewOutcome.Submitted
        assertEquals("r1", outcome.reviewId)
    }

    @Test
    fun loadAndDeleteHitReviewById() = runTest {
        val reviewJson = """{"id":"r1","created_at":"2026-01-01T00:00:00Z","elevator_blockers":[],
            "review_entrances":[],"reviewer_is_pseudonym":false}"""
        val model = model { request ->
            when (request.url.encodedPath) {
                "/v1/reviews/r1" -> when (request.method.value) {
                    "GET" -> respond("""{"status":"ok","placeId":"p1","review":$reviewJson}""", headers = jsonHeaders)
                    "DELETE" -> respond("", HttpStatusCode.NoContent)
                    else -> error(request.method.value)
                }
                else -> error(request.url.encodedPath)
            }
        }

        model.load("r1")
        assertTrue(model.state.value.outcome is ReviewOutcome.Loaded)

        model.delete("r1")
        assertTrue(model.state.value.outcome is ReviewOutcome.Deleted)
        assertEquals(2, requests.size)
    }
}
