package app.rollspot.shared.drafts

import app.rollspot.shared.reviews.ContributeFlow
import app.rollspot.shared.reviews.ElevatorQuestion
import app.rollspot.shared.reviews.LocalReviewPhoto
import kotlin.test.Test
import kotlin.test.assertContentEquals
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNotNull
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ContributeDraftsTest {
    private var clock = 1_000_000L
    private val storage = InMemoryDraftStorage()
    private fun drafts() = ContributeDrafts(storage) { clock }

    @Test
    fun bannerShowsTheNewestDraftOfTheSignedInUserOnly() {
        val drafts = drafts()
        drafts.remember("p1", "Park 23")
        assertNull(drafts.waiting.value, "nobody signed in: nothing is remembered")

        drafts.setUser("u1")
        drafts.remember("p1", "Park 23")
        clock += 10
        drafts.remember("p2", "Beachwalk")
        assertEquals("Beachwalk", drafts.waiting.value?.placeName)

        drafts.setUser("u2")
        assertNull(drafts.waiting.value)
        drafts.setUser("u1")
        assertEquals("p2", drafts.waiting.value?.placeId)

        drafts.forget("p2")
        assertEquals("p1", drafts.waiting.value?.placeId)
    }

    @Test
    fun staleDraftsLeaveTheBanner() {
        val drafts = drafts()
        drafts.setUser("u1")
        drafts.remember("p1", "Park 23")
        clock += ContributeDrafts.MAX_AGE_MILLIS + 1
        drafts.setUser("u1")
        assertNull(drafts.waiting.value)
        assertTrue(drafts.isWaiting("p1"), "still resumable from the place page")
    }

    @Test
    fun aSavedFlowComesBackWithItsAnswersAndPhotos() {
        val flow = ContributeFlow("p1", "Park 23")
        flow.state = flow.state.copy(
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "Yes"),
            elevatorPhotos = listOf(LocalReviewPhoto("f1", byteArrayOf(1, 2, 3), "Lift")),
            stepIndex = 3,
        )
        val drafts = drafts()
        drafts.setUser("u1")
        drafts.saveFlow(flow.state, hasProgress = true)

        // A new app launch reads it back from storage.
        val relaunched = drafts()
        relaunched.setUser("u1")
        assertEquals("Park 23", relaunched.waiting.value?.placeName)
        val restored = assertNotNull(relaunched.restoreFlow("p1"))
        assertEquals(3, restored.stepIndex)
        assertEquals(flow.state.submissionId, restored.submissionId, "same submission id, so a retry can't duplicate")
        assertEquals("Yes", restored.elevatorAnswers[ElevatorQuestion.WideEntrance])
        assertContentEquals(byteArrayOf(1, 2, 3), restored.elevatorPhotos.single().jpeg)
        assertEquals("Lift", restored.elevatorPhotos.single().caption)

        relaunched.forget("p1")
        assertNull(relaunched.restoreFlow("p1"))
        assertNull(storage.read("contributions/u1/p1/f1.jpg"))
    }

    @Test
    fun anEmptyFlowIsNotSaved() {
        val drafts = drafts()
        drafts.setUser("u1")
        drafts.saveFlow(ContributeFlow("p1", "Park 23").state, hasProgress = false)
        assertFalse(drafts.isWaiting("p1"))
    }
}
