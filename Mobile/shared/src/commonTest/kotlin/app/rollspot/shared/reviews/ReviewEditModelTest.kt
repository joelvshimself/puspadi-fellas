package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.RollspotApi
import app.rollspot.shared.auth.InMemoryTokenStore
import io.ktor.client.engine.mock.MockEngine
import io.ktor.client.engine.mock.respond
import io.ktor.http.HttpHeaders
import io.ktor.http.HttpMethod
import io.ktor.http.content.OutgoingContent
import io.ktor.http.headersOf
import kotlinx.coroutines.test.runTest
import kotlinx.serialization.json.Json
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertIs
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

private const val MEDIA = "https://api.test/v1/media/reviews/u1/p/sub-1"

/** What GET /v1/reviews/r1/edit returns for a review with every section. */
private val editJson = """
{"status":"ok","reviewId":"r1","placeId":"p1","placeName":"Park 23","submission":{
  "version":2,"submissionId":"sub-1","placeId":"p1","persona":"wheelchair",
  "entrance":{"notes":"Ramp available","passes":[{"photos":[{"url":"$MEDIA/a.jpg","caption":""}],
    "points":[{"location":"lobby","tags":["ramp","handrail","automatic_doors"],"ramp":"not_sure","handrail":"yes",
      "evidence":{"ramp":[{"url":"$MEDIA/e.jpg","caption":""}]}}]}]},
  "elevator":{"notes":null,"passes":[{"photos":[],"wideEntrance":"yes","spaceToManeuver":"yes","reachableButtons":"no","location":"GF","evidence":{}}]},
  "toilet":null,
  "pathways":{"notes":null,"notices":["loose_surface","narrow_path"],"photos":[]},
  "seating":{"notes":null,"answer":"yes","photos":[]},
  "parking":null,"final":null}}
""".trimIndent()

class ReviewEditModelTest {
    private val sent = mutableListOf<Pair<String, String>>()
    private val json = Json { ignoreUnknownKeys = true }
    private val model = ReviewEditModel(
        RollspotApi(
            "https://api.test",
            InMemoryTokenStore("session"),
            MockEngine { request ->
                val body = (request.body as? OutgoingContent.ByteArrayContent)?.bytes()?.decodeToString().orEmpty()
                sent += "${request.method.value} ${request.url.encodedPath}" to body
                val headers = headersOf(HttpHeaders.ContentType, "application/json")
                when {
                    request.method == HttpMethod.Get -> respond(editJson, headers = headers)
                    request.url.encodedPath.startsWith("/v1/media/") ->
                        respond("""{"url":"$MEDIA/${request.url.encodedPath.substringAfterLast('/')}.jpg"}""", headers = headers)
                    else -> respond("""{"status":"ok","reviewId":"r1","placeId":"p1","grade":[]}""", headers = headers)
                }
            },
        ),
        "r1",
    )

    private val ready get() = assertIs<ReviewEditState.Ready>(model.state.value)
    private fun row(id: String) = ready.sections.flatMap { it.rows }.first { it.id == id }
    private fun saved(): ContributionSubmission = json.decodeFromString(sent.last { it.first.startsWith("PUT /v1/reviews") }.second)

    @Test
    fun answersBecomeRowsInTheDesignsOrder() = runTest {
        model.load()
        assertEquals(listOf("Entrance", "Elevator", "Outdoor Pathways", "Seating"), ready.sections.map { it.title })
        assertEquals(
            listOf("Ramp", "Handrail", "Automatic door", "Manual door", "Security assistance", "Wheelchairs available"),
            ready.sections[0].rows.map { it.label },
        )
        assertEquals("Not sure", row("entrance/0/lobby/ramp").value)
        assertEquals("Good reach and grip", row("entrance/0/lobby/handrail").value)
        assertEquals("No", row("entrance/0/lobby/tag/manual_doors").value)
        assertEquals("GF", row("elevator/0/location").text)
        assertEquals("Ramp available", ready.sections[0].notes)
        assertFalse(ready.isDirty)
        assertFalse(ready.canSave)
    }

    @Test
    fun nothingNotableTurnsTheOtherNoticesOff() = runTest {
        model.load()
        model.choose("pathways/nothing_notable", "yes")
        assertEquals(listOf("no", "no", "no", "no", "no", "no", "yes"), ready.sections[2].rows.map { it.selected })
        model.choose("pathways/steep_section", "yes")
        assertEquals("no", row("pathways/nothing_notable").selected)
        // Turning the last notice off means there was nothing notable.
        model.choose("pathways/steep_section", "no")
        assertEquals("yes", row("pathways/nothing_notable").selected)
    }

    @Test
    fun changingANotSureAnswerDropsItsPhotos() = runTest {
        model.load()
        model.choose("entrance/0/lobby/ramp", "yes")
        model.save()
        val point = saved().entrance!!.passes[0].points[0]
        assertEquals("yes", point.ramp)
        assertTrue(point.evidence.isEmpty())
    }

    @Test
    fun noRampRemovesTheTagAndAnEntranceNeedsOneFeature() = runTest {
        model.load()
        model.choose("entrance/0/lobby/ramp", "none")
        model.choose("entrance/0/lobby/handrail", "none")
        assertNull(ready.problem)
        model.choose("entrance/0/lobby/tag/automatic_doors", "no")
        assertNotNull(ready.problem)
        assertFalse(ready.canSave)
    }

    @Test
    fun wideEntranceNoHidesTheFollowUpsAndYesAsksForThemAgain() = runTest {
        model.load()
        model.choose("elevator/0/wideEntrance", "no")
        assertEquals(listOf("Wide entrance", "Location"), ready.sections[1].rows.map { it.label })
        model.choose("elevator/0/wideEntrance", "yes")
        assertEquals("Choose", row("elevator/0/spaceToManeuver").value)
        assertNotNull(ready.problem)
        model.choose("elevator/0/spaceToManeuver", "yes")
        model.choose("elevator/0/reachableButtons", "yes")
        assertNull(ready.problem)
    }

    @Test
    fun saveUploadsOnlyPhotosStillOnThePageAndKeepsTheRest() = runTest {
        model.load()
        assertTrue(model.addPhoto("entrance/0", byteArrayOf(1, 2, 3)))
        assertTrue(model.addPhoto("seating", byteArrayOf(4)))
        val dropped = ready.sections.first { it.id == "seating" }.photos.single()
        model.removePhoto("seating", dropped.id)
        model.removePhoto("entrance/0", "$MEDIA/a.jpg")
        model.setNotes("elevator", "Lift by the food court")
        assertTrue(ready.canSave)
        model.save()

        val uploads = sent.filter { it.first.startsWith("PUT /v1/media/review-photos/p1/sub-1/") }
        assertEquals(1, uploads.size)
        val body = saved()
        val photos = body.entrance!!.passes[0].photos.map { it.url }
        assertEquals(1, photos.size)
        assertTrue(photos.single().startsWith(MEDIA) && !photos.single().endsWith("/a.jpg"))
        assertTrue(body.seating!!.photos.isEmpty())
        assertEquals("Lift by the food court", body.elevator!!.notes)
        assertIs<ReviewEditState.Saved>(model.state.value)
    }
}
