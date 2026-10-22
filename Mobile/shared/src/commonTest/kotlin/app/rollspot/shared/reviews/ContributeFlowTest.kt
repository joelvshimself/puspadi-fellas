package app.rollspot.shared.reviews

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ContributeFlowTest {
    private fun flowWith(
        category: ContributeReviewCategory = ContributeReviewCategory.Entrance,
        entranceLocations: Set<EntranceLocation> = setOf(EntranceLocation.Lobby),
        lobbyTags: Set<String> = setOf(ContributeCatalog.TAG_RAMP),
        elevatorWide: String = "Yes",
    ): ContributeFlow {
        val flow = ContributeFlow("place-1", "Test Mall", submissionId = "sub-1")
        flow.state = flow.state.copy(
            entranceLocations = entranceLocations,
            lobbyTags = lobbyTags,
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to elevatorWide),
        )
        flow.openCategory(category)
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
        val flow = flowWith(category = ContributeReviewCategory.Elevator, elevatorWide = "No")
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
        flow.openCategory(ContributeReviewCategory.Elevator)
        flow.state = flow.state.copy(
            elevatorAnswers = mapOf(
                ElevatorQuestion.WideEntrance to "Yes",
                ElevatorQuestion.SpaceToManeuver to "Yes",
                ElevatorQuestion.ReachableButtons to "Yes",
            ),
            elevatorLocation = "Near food court",
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ElevatorAnother))
        flow.chooseAnotherElevator("Yes")
        assertEquals(ContributeStep.ElevatorPhotos, flow.currentStep())
        assertEquals(1, flow.state.completedElevatorPasses.size)
        assertTrue(flow.state.elevatorAnswers.isEmpty())

        flow.goBack()
        assertEquals(ContributeStep.ElevatorAnother, flow.currentStep())
        assertEquals("Near food court", flow.state.elevatorLocation)
        assertTrue(flow.state.completedElevatorPasses.isEmpty())

        flow.chooseAnotherElevator("Yes")
        flow.state = flow.state.copy(
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "No"),
            elevatorLocation = "Parking level",
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ElevatorAnother))
        flow.chooseAnotherElevator("No")
        assertTrue(flow.currentStep() is ContributeStep.SupplementalNotes)
        flow.goNext()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals(
            CategorySectionStatus.Complete,
            flow.state.sectionStatus[ContributeReviewCategory.Elevator],
        )

        val passes = flow.toSubmission().elevator?.passes.orEmpty()
        assertEquals(2, passes.size)
        assertEquals("yes", passes[0].wideEntrance)
        assertEquals("Near food court", passes[0].location)
        assertEquals("no", passes[1].wideEntrance)
        assertEquals(null, passes[1].spaceToManeuver)
        assertEquals("Parking level", passes[1].location)
    }

    @Test
    fun toiletSectionAsksEveryQuestionThenAnother() {
        val flow = flowWith(category = ContributeReviewCategory.Toilet)
        val toiletSteps = flow.steps().dropWhile { it != ContributeStep.ToiletPhotos }
            .takeWhile { it !is ContributeStep.SupplementalNotes }
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
        flow.openCategory(ContributeReviewCategory.Toilet)
        flow.state = flow.state.copy(
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
        assertEquals(
            ContributeStep.SupplementalNotes(ContributeReviewCategory.Toilet),
            flow.currentStep(),
        )
        flow.goNext()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals(
            CategorySectionStatus.Complete,
            flow.state.sectionStatus[ContributeReviewCategory.Toilet],
        )

        val passes = flow.toSubmission().toilet?.passes
        // The second pass only answered the door, so it is not a complete toilet.
        assertEquals(1, passes?.size)
        assertEquals("sliding", passes?.single()?.door)
        assertEquals("Level 2, near food court", passes?.single()?.location)
        assertEquals(1, flow.pendingPhotos().size)
    }

    @Test
    fun submissionSendsOnlyCompletedSections() {
        val flow = ContributeFlow("p1", "Mall", "sub-1")
        flow.openCategory(ContributeReviewCategory.Entrance)
        flow.state = flow.state.copy(
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = setOf(ContributeCatalog.TAG_RAMP),
            lobbyRampAnswer = "Yes",
            elevatorAnswers = mapOf(ElevatorQuestion.WideEntrance to "No"),
        )
        assertEquals(null, flow.toSubmission().entrance)
        assertEquals(null, flow.toSubmission().elevator)

        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.EntranceAnother))
        flow.chooseAnotherEntrance("No")
        flow.goNext()
        val points = flow.toSubmission().entrance?.passes?.single()?.points
        assertEquals("lobby", points?.single()?.location)
        assertEquals("yes", points?.single()?.ramp)
        assertEquals(null, flow.toSubmission().elevator)
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
    fun secondaryPersonaRewritesOnlyTheListedQuestionTitles() {
        val secondary = ContributePersona.Secondary
        fun title(step: ContributeStep) = ContributeStepPresentation.questionTitle(step, secondary)

        assertEquals(
            "Could someone on a wheelchair go up the ramp without help?",
            title(ContributeStep.EntranceRamp(EntranceLocation.Lobby)),
        )
        assertEquals(
            "Could someone on a wheelchair go up the ramp without help?",
            title(ContributeStep.EntranceRamp(EntranceLocation.Basement)),
        )
        assertEquals(
            "Could someone in a wheelchair reach and grip the handrail?",
            title(ContributeStep.EntranceHandrail(EntranceLocation.Lobby)),
        )
        assertEquals(
            "Could someone in a wheelchair enter the elevator?",
            title(ContributeStep.Elevator(ElevatorQuestion.WideEntrance)),
        )
        assertEquals(
            "Could someone in a wheelchair turn freely inside?",
            title(ContributeStep.Elevator(ElevatorQuestion.SpaceToManeuver)),
        )
        assertEquals(
            "Could you reach the control buttons from a seated position?",
            title(ContributeStep.Elevator(ElevatorQuestion.ReachableButtons)),
        )
        assertEquals(
            "Could someone in a wheelchair turn freely inside?",
            title(ContributeStep.Toilet(ToiletSurveyQuestion.Space)),
        )
        assertEquals(
            "Can someone in a wheelchair reach the sink faucet comfortably?",
            title(ContributeStep.Toilet(ToiletSurveyQuestion.Sink)),
        )
        assertEquals(
            "Could you reach the emergency aid from a seated or fallen position?",
            title(ContributeStep.Toilet(ToiletSurveyQuestion.Emergency)),
        )
        assertEquals(
            "Is the toilet seat easy to transfer to from your wheelchair?",
            title(ContributeStep.Toilet(ToiletSurveyQuestion.Seat)),
        )
        assertEquals(
            "Help make every visit easier",
            title(ContributeStep.CategoryPick),
        )
        assertEquals(
            "Could you push your wheelchair up the ramp without help?",
            ContributeStepPresentation.questionTitle(
                ContributeStep.EntranceRamp(EntranceLocation.Lobby),
                ContributePersona.Wheelchair,
            ),
        )
    }

    @Test
    fun subStepProgressWithinEntranceSection() {
        val flow = ContributeFlow("p", "Mall")
        flow.state = flow.state.copy(
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = emptySet(),
        )
        flow.openCategory(ContributeReviewCategory.Entrance)
        val photos = ContributeStep.EntrancePhotos
        val pick = ContributeStep.EntranceLocationPick
        val tags = ContributeStep.EntranceTags(EntranceLocation.Lobby)
        assertEquals(1f / 5f, ContributeStepPresentation.subStepProgress(flow, photos))
        assertEquals(2f / 5f, ContributeStepPresentation.subStepProgress(flow, pick))
        assertEquals(3f / 5f, ContributeStepPresentation.subStepProgress(flow, tags))
    }

    @Test
    fun entranceSectionStartsWithPhotosThenLocation() {
        val flow = flowWith(category = ContributeReviewCategory.Entrance)
        val entranceSteps = flow.steps().dropWhile { it != ContributeStep.EntrancePhotos }
        assertEquals(ContributeStep.EntrancePhotos, entranceSteps.first())
        assertEquals(ContributeStep.EntranceLocationPick, entranceSteps[1])
    }

    @Test
    fun reviewingAnotherEntranceRestartsThenSubmitsEveryPass() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        flow.openCategory(ContributeReviewCategory.Entrance)
        flow.state = flow.state.copy(
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
            basementRampAnswer = "Too steep",
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.EntranceAnother))
        flow.chooseAnotherEntrance("No")
        flow.goBack()
        assertEquals(ContributeStep.EntranceAnother, flow.currentStep())
        assertTrue(EntranceLocation.Basement in flow.state.entranceLocations)
        flow.chooseAnotherEntrance("No")
        flow.goNext()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals(
            CategorySectionStatus.Complete,
            flow.state.sectionStatus[ContributeReviewCategory.Entrance],
        )

        val passes = flow.toSubmission().entrance?.passes
        assertEquals(2, passes?.size)
        assertEquals(listOf("automatic_doors"), passes?.get(0)?.points?.single()?.tags)
        assertEquals("lobby", passes?.get(0)?.points?.single()?.location)
        assertEquals("basement", passes?.get(1)?.points?.single()?.location)
        assertEquals("too_steep", passes?.get(1)?.points?.single()?.ramp)
    }

    @Test
    fun entranceSectionPhotosStayOnThePass() {
        val flow = ContributeFlow("p", "Mall", "sub-1")
        val photo = LocalReviewPhoto("f1", byteArrayOf(1, 2, 3))
        flow.openCategory(ContributeReviewCategory.Entrance)
        flow.state = flow.state.copy(
            entrancePhotos = listOf(photo),
            entranceLocations = setOf(EntranceLocation.Lobby),
            lobbyTags = setOf(ContributeCatalog.TAG_AUTO_DOORS),
        )
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.EntranceAnother))
        flow.chooseAnotherEntrance("No")
        flow.goNext()
        val pass = flow.toSubmission().entrance?.passes?.single()
        assertEquals("local:f1", pass?.photos?.single()?.url)
        assertEquals(1, flow.pendingPhotos().size)
    }

    @Test
    fun categoryPickSubmitsAfterAFinishedSection() {
        val flow = ContributeFlow("p", "Mall")
        assertEquals(listOf(ContributeStep.CategoryPick), flow.steps())
        assertFalse(flow.canContinue(ContributeStep.CategoryPick))
        flow.openCategory(ContributeReviewCategory.Parking)
        flow.state = flow.state.copy(parkingAnswer = "Yes")
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.ParkingQuestion))
        flow.goNext()
        assertEquals(ContributeStep.SupplementalNotes(ContributeReviewCategory.Parking), flow.currentStep())
        flow.setCategoryNote(ContributeReviewCategory.Parking, "Two bays by the cinema")
        flow.goNext()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals(
            CategorySectionStatus.Complete,
            flow.state.sectionStatus[ContributeReviewCategory.Parking],
        )
        assertTrue(flow.canContinue(ContributeStep.CategoryPick))
        flow.goNext()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals("Two bays by the cinema", flow.toSubmission().parking?.notes)
    }

    @Test
    fun leavingASectionMarksItInProgress() {
        val flow = ContributeFlow("p", "Mall")
        flow.openCategory(ContributeReviewCategory.Entrance)
        flow.goBack()
        assertEquals(ContributeStep.CategoryPick, flow.currentStep())
        assertEquals(
            CategorySectionStatus.InProgress,
            flow.state.sectionStatus[ContributeReviewCategory.Entrance],
        )
        assertFalse(flow.canContinue(ContributeStep.CategoryPick))
    }

    @Test
    fun elevatorOmittedWhenEntranceIsOpen() {
        val flow = flowWith(category = ContributeReviewCategory.Entrance)
        assertFalse(flow.steps().any { it is ContributeStep.Elevator })
    }

    @Test
    fun parkingStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.openCategory(ContributeReviewCategory.Parking)
        val steps = flow.steps()
        assertTrue(steps.contains(ContributeStep.ParkingPhotos))
        assertTrue(steps.contains(ContributeStep.ParkingQuestion))
        assertTrue(steps.indexOf(ContributeStep.ParkingPhotos) < steps.indexOf(ContributeStep.ParkingQuestion))
        assertEquals(
            ContributeStep.SupplementalNotes(ContributeReviewCategory.Parking),
            steps.last(),
        )
        assertTrue(flow.canContinue(ContributeStep.ParkingPhotos))
        assertFalse(flow.canContinue(ContributeStep.ParkingQuestion))
        flow.state = flow.state.copy(parkingAnswer = "Yes")
        assertTrue(flow.canContinue(ContributeStep.ParkingQuestion))
    }

    @Test
    fun pathwayStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.openCategory(ContributeReviewCategory.OutdoorPathways)
        assertTrue(flow.steps().contains(ContributeStep.PathwayPhotos))
        assertTrue(flow.steps().contains(ContributeStep.PathwayNotice))
        assertEquals(
            ContributeStep.SupplementalNotes(ContributeReviewCategory.OutdoorPathways),
            flow.steps().last(),
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
            pathwayNotices = setOf("Narrow pathway", "Tight gap"),
            sectionStatus = mapOf(ContributeReviewCategory.OutdoorPathways to CategorySectionStatus.Complete),
        )
        assertEquals(listOf("tight_gap", "narrow_path"), flow.toSubmission().pathways?.notices)
    }

    @Test
    fun seatingStepsReplaceGenericNotes() {
        val flow = ContributeFlow("p", "Mall")
        flow.openCategory(ContributeReviewCategory.Seating)
        val steps = flow.steps()
        assertTrue(steps.contains(ContributeStep.SeatingPhotos))
        assertTrue(steps.contains(ContributeStep.SeatingQuestion))
        assertFalse(steps.contains(ContributeStep.ParkingPhotos))
        val seatingPhotos = steps.indexOf(ContributeStep.SeatingPhotos)
        val seatingQuestion = steps.indexOf(ContributeStep.SeatingQuestion)
        assertTrue(seatingPhotos < seatingQuestion)
        assertEquals(ContributeStep.SupplementalNotes(ContributeReviewCategory.Seating), steps.last())
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
            seatingAnswer = "No",
            seatingPhotos = listOf(photo),
            sectionStatus = mapOf(ContributeReviewCategory.Seating to CategorySectionStatus.Complete),
        )
        assertEquals("no", flow.toSubmission().seating?.answer)
        assertEquals(1, flow.pendingPhotos().size)
    }

    @Test
    fun parkingAnswerAndPhotosFoldIntoSubmission() {
        val flow = ContributeFlow("p", "Mall")
        val photo = LocalReviewPhoto("park-1", byteArrayOf(7))
        flow.state = flow.state.copy(
            parkingAnswer = "Not sure",
            parkingPhotos = listOf(photo),
            sectionStatus = mapOf(ContributeReviewCategory.Parking to CategorySectionStatus.Complete),
        )
        assertEquals("not_sure", flow.toSubmission().parking?.answer)
        assertEquals(1, flow.pendingPhotos().size)
    }

    @Test
    fun categoryNotesTravelWithCompletedSectionsOnly() {
        val flow = ContributeFlow("p", "Mall")
        flow.setCategoryNote(ContributeReviewCategory.Seating, "  Tables are high  ")
        flow.setCategoryNote(ContributeReviewCategory.Entrance, "Side door")
        flow.state = flow.state.copy(
            seatingAnswer = "Yes",
            sectionStatus = mapOf(ContributeReviewCategory.Seating to CategorySectionStatus.Complete),
        )
        val body = flow.toSubmission()
        assertEquals("Tables are high", body.seating?.notes)
        assertEquals(null, body.entrance)
        assertEquals(null, body.final)
    }

    @Test
    fun notSureEvidenceIsCappedAndClearedWhenTheAnswerChanges() {
        val flow = ContributeFlow("p", "Mall")
        flow.openCategory(ContributeReviewCategory.Elevator)
        flow.setElevatorAnswer(ElevatorQuestion.WideEntrance, "Not Sure")
        flow.state = flow.state.copy(stepIndex = flow.steps().indexOf(ContributeStep.Elevator(ElevatorQuestion.WideEntrance)))
        assertTrue(flow.addPhoto(LocalReviewPhoto("e1", byteArrayOf(1))))
        assertTrue(flow.addPhoto(LocalReviewPhoto("e2", byteArrayOf(2))))
        assertTrue(flow.addPhoto(LocalReviewPhoto("e3", byteArrayOf(3))))
        assertFalse(flow.addPhoto(LocalReviewPhoto("e4", byteArrayOf(4))))
        flow.setElevatorAnswer(ElevatorQuestion.WideEntrance, "Yes")
        assertTrue(flow.state.elevatorEvidence.isEmpty())
    }
}
