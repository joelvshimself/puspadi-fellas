package app.rollspot.shared.reviews

enum class ContributeHeroAsset {
    EntranceMall,
    Lobby,
    Basement,
    ElevatorQuestion,
    ToiletSurvey,
    None,
}

object ContributeStepPresentation {
    val progressStepTitles = listOf("Entrance", "Elevator", "Toilets", "Review")

    fun navTitle(step: ContributeStep): String = when (step) {
        is ContributeStep.EntranceLocationPick,
        is ContributeStep.EntranceTags,
        is ContributeStep.EntranceRamp,
        is ContributeStep.EntranceHandrail,
        -> "Entrances"
        is ContributeStep.Elevator -> "Elevators"
        ContributeStep.ToiletInitial,
        is ContributeStep.Toilet,
        ContributeStep.ToiletLocation,
        -> "Accessible Toilets"
        ContributeStep.FinalReview -> "Final Review"
        ContributeStep.Submitted -> ""
    }

    fun progressStep(step: ContributeStep): Int = when (step) {
        is ContributeStep.EntranceLocationPick,
        is ContributeStep.EntranceTags,
        is ContributeStep.EntranceRamp,
        is ContributeStep.EntranceHandrail,
        -> 1
        is ContributeStep.Elevator -> 2
        ContributeStep.ToiletInitial,
        is ContributeStep.Toilet,
        ContributeStep.ToiletLocation,
        -> 3
        ContributeStep.FinalReview,
        ContributeStep.Submitted,
        -> 4
    }

    fun subStepProgress(flow: ContributeFlow, step: ContributeStep): Float {
        val stepNumber = progressStep(step)
        val section = flow.steps().filter { progressStep(it) == stepNumber }
        val index = section.indexOf(step)
        if (index < 0 || section.isEmpty()) return 0.35f
        return (index + 1).toFloat() / section.size.toFloat()
    }

    fun heroAsset(step: ContributeStep): ContributeHeroAsset = when (step) {
        ContributeStep.EntranceLocationPick -> ContributeHeroAsset.EntranceMall
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
        is ContributeStep.Elevator -> ContributeHeroAsset.ElevatorQuestion
        ContributeStep.ToiletInitial,
        is ContributeStep.Toilet,
        ContributeStep.ToiletLocation,
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
            ToiletSurveyQuestion.Sink -> "Sink Height"
            ToiletSurveyQuestion.Emergency -> "Emergency Button"
        }
        else -> null
    }

    fun questionTitle(step: ContributeStep): String = when (step) {
        ContributeStep.EntranceLocationPick -> "Which entrances did you use?"
        is ContributeStep.EntranceTags -> when (step.location) {
            EntranceLocation.Lobby -> "What does the lobby have?"
            EntranceLocation.Basement -> "What does the basement have?"
        }
        is ContributeStep.EntranceRamp ->
            "Could you push your wheelchair up the ramp without help?"
        is ContributeStep.EntranceHandrail ->
            "Could you reach and grip the handrail from your wheelchair?"
        is ContributeStep.Elevator -> when (step.question) {
            ElevatorQuestion.WideEntrance -> "Could you enter the elevator?"
            ElevatorQuestion.SpaceToManeuver -> "Could you turn your wheelchair freely inside?"
            ElevatorQuestion.ReachableButtons -> "Could you reach the buttons from your wheelchair?"
        }
        ContributeStep.ToiletInitial -> "Does the mall have accessible toilets?"
        is ContributeStep.Toilet -> when (step.question) {
            ToiletSurveyQuestion.DoorKind -> "What kind of door does the toilet have?"
            ToiletSurveyQuestion.Seat -> "Is the toilet seat easy to transfer to from your wheelchair?"
            ToiletSurveyQuestion.GrabBars -> "Are the grab bars within reach of the toilet?"
            ToiletSurveyQuestion.Space -> "Could you turn your wheelchair freely inside?"
            ToiletSurveyQuestion.Sink -> "Could you reach the sink?"
            ToiletSurveyQuestion.Emergency ->
                "Could you reach the emergency button from your wheelchair or fallen position?"
        }
        ContributeStep.ToiletLocation -> "Where is the accessible toilet?"
        ContributeStep.FinalReview -> "Add notes and photos to support your review."
        ContributeStep.Submitted -> ""
    }

    fun questionSubtitle(step: ContributeStep): String? = when (step) {
        ContributeStep.EntranceLocationPick -> "You can select multiple answers"
        else -> null
    }

    fun optionsFor(step: ContributeStep): List<String> = when (step) {
        is ContributeStep.EntranceRamp -> ContributeCatalog.rampOptions
        is ContributeStep.EntranceHandrail -> ContributeCatalog.handrailOptions
        is ContributeStep.Elevator -> ContributeCatalog.elevatorOptions
        ContributeStep.ToiletInitial -> ContributeCatalog.toiletInitialOptions
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
        ToiletSurveyQuestion.Seat -> listOf("Yes", "No", "Not sure")
        ToiletSurveyQuestion.GrabBars -> listOf("Yes", "Positioned awkwardly", "No")
        ToiletSurveyQuestion.Space,
        ToiletSurveyQuestion.Sink,
        -> listOf("Yes", "No", "Not sure")
        ToiletSurveyQuestion.Emergency ->
            listOf("Yes", "No", "Not sure", "There is no emergency button")
    }
}
