package app.rollspot.shared.reviews

enum class ContributeHeroAsset {
    EntranceMall,
    Lobby,
    Basement,
    Elevator,
    ElevatorQuestion,
    ToiletSurvey,
    None,
}

object ContributeStepPresentation {
    val progressStepTitles = listOf("Entrance", "Elevator", "Toilets", "Review")

    fun showsFacilityProgressBar(step: ContributeStep): Boolean = step !is ContributeStep.CategoryPick

    fun navTitle(step: ContributeStep): String = when (step) {
        ContributeStep.CategoryPick -> ""
        is ContributeStep.SupplementalNotes ->
            ContributeCategoryLabels.supplementalSectionTitle(step.category)
        ContributeStep.EntrancePhotos,
        ContributeStep.EntranceLocationPick,
        is ContributeStep.EntranceTags,
        is ContributeStep.EntranceRamp,
        is ContributeStep.EntranceHandrail,
        ContributeStep.EntranceAnother,
        -> "Entrances"
        ContributeStep.ElevatorPhotos,
        ContributeStep.ElevatorAnother,
        -> "Elevator"
        ContributeStep.ElevatorLocation,
        is ContributeStep.Elevator,
        -> "Elevators"
        ContributeStep.ToiletPhotos,
        is ContributeStep.Toilet,
        ContributeStep.ToiletLocation,
        ContributeStep.ToiletAnother,
        -> "Accessible Toilets"
        ContributeStep.FinalReview -> "Final Review"
        ContributeStep.Submitted -> ""
    }

    fun progressStep(step: ContributeStep): Int = when (step) {
        ContributeStep.CategoryPick -> 0
        is ContributeStep.SupplementalNotes -> 4
        ContributeStep.EntrancePhotos,
        ContributeStep.EntranceLocationPick,
        is ContributeStep.EntranceTags,
        is ContributeStep.EntranceRamp,
        is ContributeStep.EntranceHandrail,
        ContributeStep.EntranceAnother,
        -> 1
        ContributeStep.ElevatorPhotos,
        ContributeStep.ElevatorLocation,
        ContributeStep.ElevatorAnother,
        is ContributeStep.Elevator,
        -> 2
        ContributeStep.ToiletPhotos,
        is ContributeStep.Toilet,
        ContributeStep.ToiletLocation,
        ContributeStep.ToiletAnother,
        -> 3
        ContributeStep.FinalReview,
        ContributeStep.Submitted,
        -> 4
    }

    fun subStepProgress(flow: ContributeFlow, step: ContributeStep): Float {
        if (step is ContributeStep.CategoryPick) return 0.1f
        val stepNumber = progressStep(step)
        if (stepNumber == 0) return 0.1f
        val section = flow.steps().filter { progressStep(it) == stepNumber }
        val index = section.indexOf(step)
        if (index < 0 || section.isEmpty()) return 0.35f
        return (index + 1).toFloat() / section.size.toFloat()
    }

    fun heroAsset(step: ContributeStep): ContributeHeroAsset = when (step) {
        ContributeStep.CategoryPick,
        is ContributeStep.SupplementalNotes,
        -> ContributeHeroAsset.None
        ContributeStep.EntrancePhotos,
        ContributeStep.EntranceLocationPick,
        -> ContributeHeroAsset.Lobby
        is ContributeStep.EntranceTags -> when (step.location) {
            EntranceLocation.Lobby -> ContributeHeroAsset.Lobby
            EntranceLocation.Basement -> ContributeHeroAsset.Basement
        }
        is ContributeStep.EntranceRamp -> when (step.location) {
            EntranceLocation.Lobby -> ContributeHeroAsset.Lobby
            EntranceLocation.Basement -> ContributeHeroAsset.Basement
        }
        is ContributeStep.EntranceHandrail -> when (step.location) {
            EntranceLocation.Lobby -> ContributeHeroAsset.Lobby
            EntranceLocation.Basement -> ContributeHeroAsset.Basement
        }
        ContributeStep.EntranceAnother -> ContributeHeroAsset.Lobby
        ContributeStep.ElevatorPhotos,
        ContributeStep.ElevatorLocation,
        ContributeStep.ElevatorAnother,
        -> ContributeHeroAsset.Elevator
        is ContributeStep.Elevator -> ContributeHeroAsset.ElevatorQuestion
        ContributeStep.ToiletPhotos,
        ContributeStep.ToiletLocation,
        ContributeStep.ToiletAnother,
        is ContributeStep.Toilet,
        -> ContributeHeroAsset.ToiletSurvey
        ContributeStep.FinalReview,
        ContributeStep.Submitted,
        -> ContributeHeroAsset.None
    }

    fun eyebrow(step: ContributeStep): String? = when (step) {
        is ContributeStep.EntranceRamp -> "Ramps"
        is ContributeStep.EntranceHandrail -> "Hand Rails"
        is ContributeStep.Elevator -> when (step.question) {
            ElevatorQuestion.WideEntrance -> "Entrance Width"
            ElevatorQuestion.SpaceToManeuver -> "Space to Maneuver"
            ElevatorQuestion.ReachableButtons -> "Reachable Buttons"
        }
        is ContributeStep.Toilet -> when (step.question) {
            ToiletSurveyQuestion.DoorKind -> "Doors"
            ToiletSurveyQuestion.Seat -> "Toilet Seat"
            ToiletSurveyQuestion.GrabBars -> "Grab Bars"
            ToiletSurveyQuestion.Space -> "Space to Maneuver"
            ToiletSurveyQuestion.Sink -> "Sink"
            ToiletSurveyQuestion.Emergency -> "Emergency Aid"
        }
        else -> null
    }

    fun questionTitle(step: ContributeStep): String = when (step) {
        ContributeStep.CategoryPick -> "Help make every visit easier"
        is ContributeStep.SupplementalNotes ->
            "Tell us about ${ContributeCategoryLabels.supplementalSectionTitle(step.category).lowercase()}"
        ContributeStep.EntrancePhotos -> "Take or upload a photo"
        ContributeStep.EntranceLocationPick -> "Where can you find the accessible entrances?"
        is ContributeStep.EntranceTags -> when (step.location) {
            EntranceLocation.Lobby -> "What does the lobby have?"
            EntranceLocation.Basement -> "What does the basement have?"
        }
        is ContributeStep.EntranceRamp ->
            "Could you push your wheelchair up the ramp without help?"
        is ContributeStep.EntranceHandrail ->
            "Could you reach and grip the handrail from your wheelchair?"
        ContributeStep.EntranceAnother -> "Review another entrance?"
        is ContributeStep.Elevator -> when (step.question) {
            ElevatorQuestion.WideEntrance -> "Could you enter the elevator?"
            ElevatorQuestion.SpaceToManeuver -> "Could you turn your wheelchair freely inside?"
            ElevatorQuestion.ReachableButtons -> "Could you reach the control buttons from your wheelchair?"
        }
        ContributeStep.ElevatorPhotos,
        ContributeStep.ToiletPhotos,
        -> "Take or upload a photo"
        ContributeStep.ElevatorLocation -> "Where is the elevator located?"
        ContributeStep.ElevatorAnother -> "Review another elevator?"
        is ContributeStep.Toilet -> when (step.question) {
            ToiletSurveyQuestion.DoorKind -> "What kind of door does the toilet have?"
            ToiletSurveyQuestion.Seat -> "Is the toilet seat easy to transfer to from your wheelchair?"
            ToiletSurveyQuestion.GrabBars -> "Are the grab bars within reach of the toilet?"
            ToiletSurveyQuestion.Space -> "Could you turn your wheelchair freely inside?"
            ToiletSurveyQuestion.Sink -> "Could you reach the sink?"
            ToiletSurveyQuestion.Emergency ->
                "Could you reach the emergency aid from your wheelchair or fallen position?"
        }
        ContributeStep.ToiletAnother -> "Review another accessible toilet?"
        ContributeStep.ToiletLocation -> "Where is the accessible toilet?"
        ContributeStep.FinalReview -> "Add notes and photos to support your review."
        ContributeStep.Submitted -> ""
    }

    fun questionSubtitle(step: ContributeStep): String? = when (step) {
        ContributeStep.CategoryPick ->
            "Fill in at least one facility to help others know what to expect."
        ContributeStep.EntrancePhotos,
        ContributeStep.ElevatorPhotos,
        ContributeStep.ElevatorLocation,
        ContributeStep.ToiletPhotos,
        ContributeStep.ToiletLocation,
        -> "(Optional)"
        ContributeStep.EntranceLocationPick -> "You can select multiple places"
        is ContributeStep.EntranceTags -> "You can select multiple answers"
        is ContributeStep.SupplementalNotes -> "Add notes and photos for this area."
        else -> null
    }

    fun optionsFor(step: ContributeStep): List<String> = when (step) {
        is ContributeStep.EntranceRamp -> ContributeCatalog.rampOptions
        is ContributeStep.EntranceHandrail -> ContributeCatalog.handrailOptions
        ContributeStep.EntranceAnother -> ContributeCatalog.entranceAnotherOptions
        is ContributeStep.Elevator -> ContributeCatalog.elevatorOptions
        ContributeStep.ElevatorAnother -> ContributeCatalog.elevatorAnotherOptions
        ContributeStep.ToiletAnother -> ContributeCatalog.toiletAnotherOptions
        is ContributeStep.Toilet -> toiletOptions(step.question)
        else -> emptyList()
    }

    fun tagOptions(step: ContributeStep): List<String> = when (step) {
        is ContributeStep.EntranceTags -> when (step.location) {
            EntranceLocation.Lobby -> ContributeCatalog.lobbyEntranceTags()
            EntranceLocation.Basement -> ContributeCatalog.basementEntranceTags()
        }
        else -> emptyList()
    }

    private fun toiletOptions(question: ToiletSurveyQuestion): List<String> = when (question) {
        ToiletSurveyQuestion.DoorKind -> listOf("Manual", "Sliding", "Automatic")
        ToiletSurveyQuestion.Seat -> listOf("Yes", "Too low", "Too high", "Not sure")
        ToiletSurveyQuestion.GrabBars -> listOf("Yes", "Positioned awkwardly", "No", "Not sure")
        ToiletSurveyQuestion.Space,
        ToiletSurveyQuestion.Sink,
        -> listOf("Yes", "No", "Not sure")
        ToiletSurveyQuestion.Emergency ->
            listOf("Yes", "No", "Not sure", "There is no emergency button")
    }
}
