package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionAnswerArea
import app.rollspot.shared.api.ContributionElevator
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpStatusCode
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith

/** What actually goes over the wire for a v2 contribution, checked against backend/src/reviews.ts. */
class ContributionSubmitTest {
    private val json = headersOf(HttpHeaders.ContentType, "application/json")
    private val posted = mutableListOf<String>()
    private val uploads = mutableListOf<String>()
    private var failNextPost = false

    private val model = ReviewModel(
        RollspotApi(
            "https://api.test",
            InMemoryTokenStore("session"),
            MockEngine { request ->
                val path = request.url.encodedPath
                if (path.startsWith("/v1/media/review-photos/")) {
                    uploads += path
                    respond("""{"url":"https://api.test/v1/media/${path.substringAfterLast('/')}.jpg"}""", headers = json)
                } else {
                    posted += (request.body as OutgoingContent.ByteArrayContent).bytes().decodeToString()
                    if (failNextPost) {
                        failNextPost = false
                        respond("""{"error":"internal_error","message":"boom"}""", HttpStatusCode.InternalServerError, json)
                    } else {
                        respond("""{"status":"ok","reviewId":"r1","placeId":"p1","grade":[]}""", HttpStatusCode.Created, json)
                    }
                }
            },
        ),
    )

    private val submission = ContributionSubmission(
        submissionId = "sub-1",
        placeId = "p1",
        persona = "wheelchair",
        elevator = ContributionElevator(
            passes = listOf(ContributionElevatorPass(photos = listOf(ContributionPhoto("local:f1")), wideEntrance = "yes")),
            notes = "Lift is behind the food court",
        ),
        parking = ContributionAnswerArea(answer = "yes", notes = "Basement P1"),
    )
    private val photos = listOf(PendingContributionPhoto("f1", byteArrayOf(1, 2, 3)))

    @Test
    fun bodyCarriesVersionTwoNotesAndUploadedUrls() = runTest {
        model.submitContribution(submission, photos)
        val body = Json.parseToJsonElement(posted.single()).jsonObject
        // Without version == 2 the backend takes the legacy path and stores an empty review.
        assertEquals(2, body["version"]!!.jsonPrimitive.int)
        val elevator = body["elevator"]!!.jsonObject
        assertEquals("Lift is behind the food court", elevator["notes"]!!.jsonPrimitive.content)
        assertEquals("Basement P1", body["parking"]!!.jsonObject["notes"]!!.jsonPrimitive.content)
        val photoUrl = elevator["passes"]!!.jsonArray[0].jsonObject["photos"]!!.jsonArray[0].jsonObject["url"]!!.jsonPrimitive.content
        assertEquals("https://api.test/v1/media/f1.jpg", photoUrl)
        assertEquals(listOf("/v1/media/review-photos/p1/sub-1/f1"), uploads)
    }

    @Test
    fun retryAfterAFailedPostReusesTheSameSubmissionAndPhotoIds() = runTest {
        failNextPost = true
        assertFailsWith<Exception> { model.submitContribution(submission, photos) }
        val failed = model.state.value.outcome as ReviewOutcome.Failed
        assertEquals(true, failed.retryable)

        model.submitContribution(submission, photos)
        // Same submissionId both times: the server stores at most one review.
        assertEquals(2, posted.size)
        posted.forEach { assertEquals("sub-1", Json.parseToJsonElement(it).jsonObject["submissionId"]!!.jsonPrimitive.content) }
        // Re-uploads overwrite the same objects instead of creating duplicates.
        assertEquals(listOf("/v1/media/review-photos/p1/sub-1/f1", "/v1/media/review-photos/p1/sub-1/f1"), uploads)
        assertEquals(ReviewOutcome.Submitted(reviewId = "r1", placeId = "p1"), model.state.value.outcome)
    }
}
