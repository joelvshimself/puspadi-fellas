package app.rollspot.shared.reviews

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ContributeFlowTest {
    private fun flowWith(
        entranceLocations: Set<EntranceLocation> = setOf(EntranceLocation.Lobby),
        lobbyTags: Set<String> = setOf(ContributeCatalog.TAG_RAMP),
        elevatorWide: String = "Yes",
        toiletInitial: String = "No",
    ): ContributeFlow {
        val flow = ContributeFlow("place-1", "Test Mall", submissionId = "sub-1")
        flow.state = flow.state.copy(
            entranceLocations = entranceLocations,
            lobbyTags = lobbyTags,
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to elevatorWide),
            toiletInitialAnswer = toiletInitial,
        )
        return flow
    }

    @Test
    fun rampFollowupOnlyWhenRampTagSelected() {
        val withRamp = flowWith(lobbyTags = setOf(ContributeCatalog.TAG_RAMP))
        assertTrue(withRamp.steps().any { it is ContributeStep.EntranceRamp })

        val noRamp = flowWith(lobbyTags = setOf(ContributeCatalog.TAG_AUTO_DOORS))
        assertFalse(noRamp.steps().any { it is ContributeStep.EntranceRamp })
    }

    @Test
    fun elevatorNoSkipsRemainingElevatorQuestions() {
        val flow = flowWith(elevatorWide = "No")
        val elevatorSteps = flow.steps().filterIsInstance<ContributeStep.Elevator>()
        assertEquals(1, elevatorSteps.size)
        assertEquals(ElevatorQuestion.WideEntrance, elevatorSteps.single().question)
    }

    @Test
    fun toiletNoSkipsToiletSurvey() {
        val flow = flowWith(toiletInitial = "No")
        assertFalse(flow.steps().any { it is ContributeStep.Toilet })
        assertFalse(flow.steps().any { it is ContributeStep.ToiletLocation })
    }

    @Test
    fun submissionOmitsEmptyEntrances() {
        val flow = ContributeFlow("p1", "Mall", "sub-1")
        flow.state = flow.state.copy(
            entranceLocations = setOf(EntranceLocation.Lobby, EntranceLocation.Basement),
            lobbyTags = setOf(ContributeCatalog.TAG_RAMP),
            toiletInitialAnswer = "No",
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "No"),
        )
        val body = flow.toSubmission()
        assertEquals(1, body.entrances?.size)
        assertEquals("lobby", body.entrances?.single()?.location)
        assertEquals(false, body.elevator?.wheelchairAccessible)
        assertEquals("too_small", body.elevator?.blockers?.single())
        assertEquals(false, body.toilet?.hasDisabledToilet)
    }

    @Test
    fun presentationMapsElevatorToStep2AndHero() {
        val step = ContributeStep.Elevator(ElevatorQuestion.WideEntrance)
        assertEquals(2, ContributeStepPresentation.progressStep(step))
        assertEquals(ContributeHeroAsset.ElevatorQuestion, ContributeStepPresentation.heroAsset(step))
        assertEquals("Elevators", ContributeStepPresentation.navTitle(step))
    }

    @Test
    fun subStepProgressWithinEntranceSection() {
        val flow = ContributeFlow("p", "Mall")
        flow.state = flow.state.copy(entranceLocations = setOf(EntranceLocation.Lobby))
        val pick = ContributeStep.EntranceLocationPick
        val tags = ContributeStep.EntranceTags(EntranceLocation.Lobby)
        assertEquals(0.5f, ContributeStepPresentation.subStepProgress(flow, pick))
        assertEquals(1f, ContributeStepPresentation.subStepProgress(flow, tags))
    }
}
