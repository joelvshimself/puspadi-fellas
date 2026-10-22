package app.rollspot.shared.reviews

/** Stable wire codes for POST /v1/reviews version 2. The UI keeps its display labels. */
object ContributeCodes {
    const val RAMP = "ramp"
    const val HANDRAIL = "handrail"
    const val WIDE_ENTRANCE = "wideEntrance"
    const val SPACE = "spaceToManeuver"
    const val BUTTONS = "reachableButtons"
    const val SEAT = "seat"
    const val GRAB_BARS = "grabBars"
    const val TOILET_SPACE = "space"
    const val SINK = "sink"
    const val EMERGENCY = "emergency"

    fun isNotSure(answer: String?): Boolean = answer == "Not sure" || answer == "Not Sure"

    fun tag(label: String): String? = when (label) {
        ContributeCatalog.TAG_RAMP -> RAMP
        ContributeCatalog.TAG_HANDRAIL -> HANDRAIL
        ContributeCatalog.TAG_AUTO_DOORS -> "automatic_doors"
        ContributeCatalog.TAG_MANUAL_DOORS -> "manual_doors"
        "SECURITY ASSISTANCE" -> "security_assistance"
        "WHEELCHAIRS AVAILABLE" -> "wheelchairs_available"
        "ELEVATOR" -> "elevator"
        "DISABLED PARKING" -> "disabled_parking"
        else -> null
    }

    fun ramp(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "With a push" -> "with_push"
        "Too steep" -> "too_steep"
        "Not sure" -> "not_sure"
        else -> null
    }

    fun handrail(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "With effort" -> "with_effort"
        "No" -> "no"
        "Not sure" -> "not_sure"
        else -> null
    }

    fun tri(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "No" -> "no"
        "Not Sure", "Not sure" -> "not_sure"
        else -> null
    }

    fun door(answer: String): String? = when (answer) {
        "Manual" -> "manual"
        "Sliding" -> "sliding"
        "Automatic" -> "automatic"
        else -> null
    }

    fun seat(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "Too low" -> "too_low"
        "Too high" -> "too_high"
        "Not sure" -> "not_sure"
        else -> null
    }

    fun grabBars(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "Positioned awkwardly" -> "awkward"
        "No" -> "no"
        "Not sure" -> "not_sure"
        else -> null
    }

    fun emergency(answer: String): String? = when (answer) {
        "Yes" -> "yes"
        "No" -> "no"
        "Not sure" -> "not_sure"
        "There is no emergency button" -> "none"
        else -> null
    }

    fun notice(label: String): String? = when (label) {
        "Loose gravel or sand" -> "loose_surface"
        "Rough or uneven surface" -> "rough_surface"
        "Tight gap" -> "tight_gap"
        "Narrow pathway" -> "narrow_path"
        "Steep section" -> "steep_section"
        "Curb or step with no ramp" -> "curb_no_ramp"
        ContributeCatalog.NOTICE_NOTHING -> "nothing_notable"
        else -> null
    }

    fun elevatorQuestion(question: ElevatorQuestion): String = when (question) {
        ElevatorQuestion.WideEntrance -> WIDE_ENTRANCE
        ElevatorQuestion.SpaceToManeuver -> SPACE
        ElevatorQuestion.ReachableButtons -> BUTTONS
    }

    fun toiletQuestion(question: ToiletSurveyQuestion): String? = when (question) {
        ToiletSurveyQuestion.DoorKind -> null
        ToiletSurveyQuestion.Seat -> SEAT
        ToiletSurveyQuestion.GrabBars -> GRAB_BARS
        ToiletSurveyQuestion.Space -> TOILET_SPACE
        ToiletSurveyQuestion.Sink -> SINK
        ToiletSurveyQuestion.Emergency -> EMERGENCY
    }
}

object ContributePhotoLimits {
    const val SECTION = 5
    const val EVIDENCE_PER_PASS = 3
    const val FINAL = 5
}
