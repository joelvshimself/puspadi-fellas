package app.rollspot.shared.reviews

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ContributeFlowTest {
    private val allCoreCategories = setOf(
        ContributeReviewCategory.Entrance,
        ContributeReviewCategory.Elevator,
        ContributeReviewCategory.Toilet,
    )

    private fun flowWith(
        entranceLocations: Set<EntranceLocation> = setOf(EntranceLocation.Lobby),
        lobbyTags: Set<String> = setOf(ContributeCatalog.TAG_RAMP),
        elevatorWide: String = "Yes",
        toiletInitial: String = "No",
        selectedCategories: Set<ContributeReviewCategory> = allCoreCategories,
    ): ContributeFlow {
        val flow = ContributeFlow("place-1", "Test Mall", submissionId = "sub-1")
        flow.state = flow.state.copy(
            selectedCategories = selectedCategories,
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
            selectedCategories = allCoreCategories,
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
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Entrance),
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = emptySet(),
        )
        val photos = ContributeStep.EntrancePhotos
        val pick = ContributeStep.EntranceLocationPick
        val tags = ContributeStep.EntranceTags(EntranceLocation.Lobby)
        assertEquals(1f / 3f, ContributeStepPresentation.subStepProgress(flow, photos))
        assertEquals(2f / 3f, ContributeStepPresentation.subStepProgress(flow, pick))
        assertEquals(1f, ContributeStepPresentation.subStepProgress(flow, tags))
    }

    @Test
    fun entranceSectionStartsWithPhotosThenLocation() {
        val flow = flowWith(selectedCategories = setOf(ContributeReviewCategory.Entrance))
        val entranceSteps = flow.steps().dropWhile { it != ContributeStep.EntrancePhotos }
        assertEquals(ContributeStep.EntrancePhotos, entranceSteps.first())
        assertEquals(ContributeStep.EntranceLocationPick, entranceSteps[1])
    }

    @Test
    fun entranceSectionPhotosFoldIntoLobbyOnSubmit() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        val photo = LocalReviewPhoto("f1", byteArrayOf(1, 2, 3))
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Entrance),
            entrancePhotos = listOf(photo),
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = setOf(ContributeCatalog.TAG_AUTO_DOORS),
        )
        assertEquals(1, flow.pendingPhotos().size)
        assertTrue(flow.toSubmission().entrances?.single()?.review != null)
    }

    @Test
    fun categoryPickIsFirstAndRequiresSelection() {
        val flow = ContributeFlow("p", "Mall")
        assertEquals(ContributeStep.CategoryPick, flow.steps().first())
        assertFalse(flow.canContinue(ContributeStep.CategoryPick))
        flow.toggleCategory(ContributeReviewCategory.Parking)
        assertTrue(flow.canContinue(ContributeStep.CategoryPick))
    }

    @Test
    fun elevatorOmittedWhenCategoryNotSelected() {
        val flow = flowWith(selectedCategories = setOf(ContributeReviewCategory.Entrance))
        assertFalse(flow.steps().any { it is ContributeStep.Elevator })
    }

    @Test
    fun supplementalStepWhenParkingSelected() {
        val flow = ContributeFlow("p", "Mall")
        flow.toggleCategory(ContributeReviewCategory.Parking)
        assertTrue(flow.steps().any { it is ContributeStep.SupplementalNotes })
    }

    @Test
    fun supplementalTextFoldedIntoSubmission() {
        val flow = ContributeFlow("p", "Mall")
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Parking),
            supplementalNotes = mapOf(
                ContributeReviewCategory.Parking to FacilityNotes(text = "Wide bays near entrance"),
            ),
        )
        val reviewText = flow.toSubmission().toilet?.review?.text
        assertTrue(reviewText?.contains("[Parking]") == true)
        assertTrue(reviewText?.contains("Wide bays") == true)
    }
}
