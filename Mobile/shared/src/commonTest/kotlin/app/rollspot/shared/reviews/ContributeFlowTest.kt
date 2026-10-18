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
        selectedCategories: Set<ContributeReviewCategory> = allCoreCategories,
    ): ContributeFlow {
        val flow = ContributeFlow("place-1", "Test Mall", submissionId = "sub-1")
        flow.state = flow.state.copy(
            selectedCategories = selectedCategories,
            entranceLocations = entranceLocations,
            lobbyTags = lobbyTags,
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to elevatorWide),
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
        assertTrue(flow.steps().contains(ContributeStep.ElevatorPhotos))
        assertTrue(flow.steps().contains(ContributeStep.ElevatorLocation))
        assertTrue(flow.steps().contains(ContributeStep.ElevatorAnother))
    }

    @Test
    fun reviewingAnotherElevatorRestartsThenSubmitsEveryPass() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Elevator),
            elevatorAnswers = mapOf(
                ElevatorQuestion.WideEntrance to "Yes",
                ElevatorQuestion.SpaceToManeuver to "Yes",
                ElevatorQuestion.ReachableButtons to "Yes",
            ),
            elevatorNotes = FacilityNotes(text = "Near food court"),
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ElevatorAnother))
        flow.chooseAnotherElevator("Yes")
        assertEquals(ContributeStep.ElevatorPhotos, flow.currentStep())
        assertEquals(1, flow.state.completedElevatorPasses.size)
        assertTrue(flow.state.elevatorAnswers.isEmpty())

        flow.goBack()
        assertEquals(ContributeStep.ElevatorAnother, flow.currentStep())
        assertEquals("Near food court", flow.state.elevatorNotes.text)
        assertTrue(flow.state.completedElevatorPasses.isEmpty())

        flow.chooseAnotherElevator("Yes")
        flow.state = flow.state.copy(
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "No"),
            elevatorNotes = FacilityNotes(text = "Parking level"),
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ElevatorAnother))
        flow.chooseAnotherElevator("No")
        assertEquals(ContributeStep.FinalReview, flow.currentStep())

        val body = flow.toSubmission()
        assertEquals(false, body.elevator?.wheelchairAccessible)
        assertEquals("too_small", body.elevator?.blockers?.single())
        val text = body.elevator?.review?.text.orEmpty()
        assertTrue(text.contains("Near food court"))
        assertTrue(text.contains("Parking level"))
        assertTrue(text.contains("Entrance Width: No"))
    }

    @Test
    fun toiletSectionAsksEveryQuestionThenAnother() {
        val flow = flowWith(selectedCategories = setOf(ContributeReviewCategory.Toilet))
        val toiletSteps = flow.steps().dropWhile { it != ContributeStep.ToiletPhotos }
            .takeWhile { it != ContributeStep.FinalReview }
        assertEquals(ContributeStep.ToiletPhotos, toiletSteps.first())
        assertEquals(
            ToiletSurveyQuestion.entries.map { ContributeStep.Toilet(it) },
            toiletSteps.drop(1).take(ToiletSurveyQuestion.entries.size),
        )
        assertEquals(ContributeStep.ToiletLocation, toiletSteps[toiletSteps.lastIndex - 1])
        assertEquals(ContributeStep.ToiletAnother, toiletSteps.last())
    }

    @Test
    fun reviewingAnotherToiletRestartsThenSubmitsEveryPass() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        val firstPhoto = LocalReviewPhoto("toilet-1", byteArrayOf(1))
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Toilet),
            toiletPhotos = listOf(firstPhoto),
            toiletAnswers = mapOf(
                ToiletSurveyQuestion.DoorKind to "Sliding",
                ToiletSurveyQuestion.Seat to "Yes",
                ToiletSurveyQuestion.GrabBars to "Yes",
                ToiletSurveyQuestion.Space to "Yes",
                ToiletSurveyQuestion.Sink to "Yes",
                ToiletSurveyQuestion.Emergency to "Not sure",
            ),
            toiletLocationNote = "Level 2, near food court",
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ToiletAnother))
        flow.chooseAnotherToilet("Yes")
        assertEquals(ContributeStep.ToiletPhotos, flow.currentStep())
        assertEquals(1, flow.state.completedToiletPasses.size)
        assertTrue(flow.state.toiletAnswers.isEmpty())
        assertTrue(flow.state.toiletPhotos.isEmpty())

        flow.goBack()
        assertEquals(ContributeStep.ToiletAnother, flow.currentStep())
        assertEquals("Level 2, near food court", flow.state.toiletLocationNote)
        assertEquals("Sliding", flow.state.toiletAnswers[ToiletSurveyQuestion.DoorKind])
        assertTrue(flow.state.completedToiletPasses.isEmpty())

        flow.chooseAnotherToilet("Yes")
        val secondPhoto = LocalReviewPhoto("toilet-2", byteArrayOf(2))
        flow.state = flow.state.copy(
            toiletPhotos = listOf(secondPhoto),
            toiletAnswers = mapOf(ToiletSurveyQuestion.DoorKind to "Manual"),
            toiletLocationNote = "Basement",
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ToiletAnother))
        flow.chooseAnotherToilet("No")
        assertEquals(ContributeStep.FinalReview, flow.currentStep())

        val body = flow.toSubmission()
        assertEquals(true, body.toilet?.hasDisabledToilet)
        val text = body.toilet?.review?.text.orEmpty()
        assertTrue(text.contains("[Toilet 1]"))
        assertTrue(text.contains("Level 2, near food court"))
        assertTrue(text.contains("Doors: Sliding"))
        assertTrue(text.contains("[Toilet 2]"))
        assertTrue(text.contains("Doors: Manual"))
        assertEquals(2, flow.pendingPhotos().size)
    }

    @Test
    fun submissionOmitsEmptyEntrances() {
        val flow = ContributeFlow("p1", "Mall", "sub-1")
        flow.state = flow.state.copy(
            selectedCategories = allCoreCategories,
            entranceLocations = setOf(EntranceLocation.Lobby, EntranceLocation.Basement),
            lobbyTags = setOf(ContributeCatalog.TAG_RAMP),
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "No"),
        )
        val body = flow.toSubmission()
        assertEquals(1, body.entrances?.size)
        assertEquals("lobby", body.entrances?.single()?.location)
        assertEquals(false, body.elevator?.wheelchairAccessible)
        assertEquals("too_small", body.elevator?.blockers?.single())
        assertEquals(null, body.toilet?.hasDisabledToilet)
    }

    @Test
    fun presentationMapsElevatorToStep2AndHero() {
        val step = ContributeStep.Elevator(ElevatorQuestion.WideEntrance)
        assertEquals(2, ContributeStepPresentation.progressStep(step))
        assertEquals(ContributeHeroAsset.ElevatorQuestion, ContributeStepPresentation.heroAsset(step))
        assertEquals("Elevators", ContributeStepPresentation.navTitle(step))
        assertEquals("Elevator", ContributeStepPresentation.navTitle(ContributeStep.ElevatorPhotos))
        assertEquals(ContributeHeroAsset.Elevator, ContributeStepPresentation.heroAsset(ContributeStep.ElevatorLocation))
        assertEquals(
            "Could you reach the control buttons from your wheelchair?",
            ContributeStepPresentation.questionTitle(
                ContributeStep.Elevator(ElevatorQuestion.ReachableButtons),
            ),
        )
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
        assertEquals(1f / 4f, ContributeStepPresentation.subStepProgress(flow, photos))
        assertEquals(2f / 4f, ContributeStepPresentation.subStepProgress(flow, pick))
        assertEquals(3f / 4f, ContributeStepPresentation.subStepProgress(flow, tags))
    }

    @Test
    fun entranceSectionStartsWithPhotosThenLocation() {
        val flow = flowWith(selectedCategories = setOf(ContributeReviewCategory.Entrance))
        val entranceSteps = flow.steps().dropWhile { it != ContributeStep.EntrancePhotos }
        assertEquals(ContributeStep.EntrancePhotos, entranceSteps.first())
        assertEquals(ContributeStep.EntranceLocationPick, entranceSteps[1])
    }

    @Test
    fun reviewingAnotherEntranceRestartsThenSubmitsEveryPass() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Entrance),
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = setOf(ContributeCatalog.TAG_AUTO_DOORS),
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.EntranceAnother))
        flow.chooseAnotherEntrance("Yes")
        assertEquals(ContributeStep.EntrancePhotos, flow.currentStep())
        assertEquals(1, flow.state.completedEntrancePasses.size)
        assertTrue(flow.state.entranceLocations.isEmpty())

        flow.goBack()
        assertEquals(ContributeStep.EntranceAnother, flow.currentStep())
        assertTrue(EntranceLocation.Lobby in flow.state.entranceLocations)
        assertTrue(flow.state.completedEntrancePasses.isEmpty())

        flow.chooseAnotherEntrance("Yes")
        flow.state = flow.state.copy(
            entranceLocations = setOf(EntranceLocation.Basement),
            basementTags = setOf(ContributeCatalog.TAG_RAMP),
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.EntranceAnother))
        flow.chooseAnotherEntrance("No")
        assertEquals(ContributeStep.FinalReview, flow.currentStep())

        val entrances = flow.toSubmission().entrances
        assertEquals(2, entrances?.size)
        assertEquals("lobby", entrances?.get(0)?.location)
        assertEquals("automatic", entrances?.get(0)?.doorType)
        assertEquals("basement", entrances?.get(1)?.location)
        assertEquals(true, entrances?.get(1)?.hasDropoffRamp)
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
    fun parkingStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.toggleCategory(ContributeReviewCategory.Parking)
        val steps = flow.steps()
        assertTrue(steps.contains(ContributeStep.ParkingPhotos))
        assertTrue(steps.contains(ContributeStep.ParkingQuestion))
        assertTrue(steps.indexOf(ContributeStep.ParkingPhotos) < steps.indexOf(ContributeStep.ParkingQuestion))
        assertFalse(
            steps.any {
                it is ContributeStep.SupplementalNotes && it.category == ContributeReviewCategory.Parking
            },
        )
        assertTrue(flow.canContinue(ContributeStep.ParkingPhotos))
        assertFalse(flow.canContinue(ContributeStep.ParkingQuestion))
        flow.state = flow.state.copy(parkingAnswer = "Yes")
        assertTrue(flow.canContinue(ContributeStep.ParkingQuestion))
    }

    @Test
    fun pathwayStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.toggleCategory(ContributeReviewCategory.OutdoorPathways)
        assertTrue(flow.steps().contains(ContributeStep.PathwayPhotos))
        assertTrue(flow.steps().contains(ContributeStep.PathwayNotice))
        assertFalse(
            flow.steps().any {
                it is ContributeStep.SupplementalNotes &&
                    it.category == ContributeReviewCategory.OutdoorPathways
            },
        )
        assertFalse(flow.canContinue(ContributeStep.PathwayNotice))
        assertTrue(flow.canContinue(ContributeStep.PathwayPhotos))
    }

    @Test
    fun nothingNotableClearsOtherPathwayNotices() {
        val flow = ContributeFlow("p", "Mall")
        flow.togglePathwayNotice("Tight gap")
        flow.togglePathwayNotice("Narrow pathway")
        assertEquals(setOf("Tight gap", "Narrow pathway"), flow.state.pathwayNotices)
        flow.togglePathwayNotice(ContributeCatalog.NOTICE_NOTHING)
        assertEquals(setOf(ContributeCatalog.NOTICE_NOTHING), flow.state.pathwayNotices)
        flow.togglePathwayNotice("Steep section")
        assertEquals(setOf("Steep section"), flow.state.pathwayNotices)
        assertTrue(flow.canContinue(ContributeStep.PathwayNotice))
    }

    @Test
    fun pathwayNoticesFoldedIntoSubmission() {
        val flow = ContributeFlow("p", "Mall")
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.OutdoorPathways),
            pathwayNotices = setOf("Narrow pathway", "Tight gap"),
        )
        val reviewText = flow.toSubmission().toilet?.review?.text
        assertTrue(reviewText?.contains("[Outdoor Pathways]") == true)
        assertTrue(reviewText?.contains("Noticed: Tight gap, Narrow pathway") == true)
    }

    @Test
    fun seatingStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.toggleCategory(ContributeReviewCategory.Seating)
        flow.toggleCategory(ContributeReviewCategory.Parking)
        val steps = flow.steps()
        assertTrue(steps.contains(ContributeStep.SeatingPhotos))
        assertTrue(steps.contains(ContributeStep.SeatingQuestion))
        val seatingPhotos = steps.indexOf(ContributeStep.SeatingPhotos)
        val seatingQuestion = steps.indexOf(ContributeStep.SeatingQuestion)
        val parking = steps.indexOf(ContributeStep.ParkingPhotos)
        assertTrue(seatingPhotos < seatingQuestion)
        assertTrue(seatingQuestion < parking)
        assertFalse(
            steps.any {
                it is ContributeStep.SupplementalNotes && it.category == ContributeReviewCategory.Seating
            },
        )
        assertTrue(flow.canContinue(ContributeStep.SeatingPhotos))
        assertFalse(flow.canContinue(ContributeStep.SeatingQuestion))
        flow.state = flow.state.copy(seatingAnswer = "Yes")
        assertTrue(flow.canContinue(ContributeStep.SeatingQuestion))
    }

    @Test
    fun seatingAnswerAndPhotosFoldIntoSubmission() {
        val flow = ContributeFlow("p", "Mall")
        val photo = LocalReviewPhoto("seat-1", byteArrayOf(9))
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Seating),
            seatingAnswer = "No",
            seatingPhotos = listOf(photo),
        )
        val reviewText = flow.toSubmission().toilet?.review?.text
        assertTrue(reviewText?.contains("[Seating]") == true)
        assertTrue(reviewText?.contains("Wheelchair friendly seating: No") == true)
        assertEquals(1, flow.pendingPhotos().size)
    }

    @Test
    fun parkingAnswerAndPhotosFoldIntoSubmission() {
        val flow = ContributeFlow("p", "Mall")
        val photo = LocalReviewPhoto("park-1", byteArrayOf(7))
        flow.state = flow.state.copy(
            selectedCategories = setOf(ContributeReviewCategory.Parking),
            parkingAnswer = "Not sure",
            parkingPhotos = listOf(photo),
        )
        val reviewText = flow.toSubmission().toilet?.review?.text
        assertTrue(reviewText?.contains("[Parking]") == true)
        assertTrue(reviewText?.contains("Accessible parking: Not sure") == true)
        assertEquals(1, flow.pendingPhotos().size)
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
