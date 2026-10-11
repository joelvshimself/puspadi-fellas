package app.rollspot.shared.reviews

import app.rollspot.shared.api.EntranceReport
import app.rollspot.shared.api.ElevatorReport
import app.rollspot.shared.api.ReviewNote
import app.rollspot.shared.api.ReviewSubmission
import app.rollspot.shared.api.ToiletReport
import kotlin.random.Random
import kotlin.uuid.ExperimentalUuidApi
import kotlin.uuid.Uuid

enum class EntranceLocation { Lobby, Basement }

enum class ElevatorQuestion {
    WideEntrance,
    SpaceToManeuver,
    ReachableButtons,
}

enum class ToiletSurveyQuestion {
    DoorKind,
    Seat,
    GrabBars,
    Space,
    Sink,
    Emergency,
}

sealed class ContributeStep {
    data object EntranceLocationPick : ContributeStep()
    data class EntranceTags(val location: EntranceLocation) : ContributeStep()
    data class EntranceRamp(val location: EntranceLocation) : ContributeStep()
    data class EntranceHandrail(val location: EntranceLocation) : ContributeStep()
    data class Elevator(val question: ElevatorQuestion) : ContributeStep()
    data object ToiletInitial : ContributeStep()
    data class Toilet(val question: ToiletSurveyQuestion) : ContributeStep()
    data object ToiletLocation : ContributeStep()
    data object FinalReview : ContributeStep()
    data object Submitted : ContributeStep()
}

data class LocalReviewPhoto(
    val fileId: String,
    val jpeg: ByteArray,
    val caption: String = "",
)

data class FacilityNotes(
    val text: String = "",
    val photos: List<LocalReviewPhoto> = emptyList(),
)

data class ContributeFlowState(
    val placeId: String,
    val placeName: String,
    val submissionId: String,
    val stepIndex: Int = 0,
    val entranceLocations: Set<EntranceLocation> = emptySet(),
    val lobbyTags: Set<String> = emptySet(),
    val basementTags: Set<String> = emptySet(),
    val lobbyRampAnswer: String? = null,
    val basementRampAnswer: String? = null,
    val lobbyHandrailAnswer: String? = null,
    val basementHandrailAnswer: String? = null,
    val elevatorAnswers: Map<ElevatorQuestion, String> = emptyMap(),
    val toiletInitialAnswer: String? = null,
    val toiletAnswers: Map<ToiletSurveyQuestion, String> = emptyMap(),
    val toiletLocationNote: String = "",
    val lobbyNotes: FacilityNotes = FacilityNotes(),
    val basementNotes: FacilityNotes = FacilityNotes(),
    val elevatorNotes: FacilityNotes = FacilityNotes(),
    val toiletNotes: FacilityNotes = FacilityNotes(),
    val showExitConfirmation: Boolean = false,
)

object ContributeCatalog {
    const val TAG_RAMP = "RAMP"
    const val TAG_HANDRAIL = "HANDRAIL"
    const val TAG_AUTO_DOORS = "AUTOMATIC DOORS"
    const val TAG_MANUAL_DOORS = "MANUAL DOORS"

    fun lobbyEntranceTags(): List<String> = listOf(
        TAG_RAMP,
        TAG_HANDRAIL,
        TAG_AUTO_DOORS,
        TAG_MANUAL_DOORS,
        "SECURITY ASSISTANCE",
        "WHEELCHAIRS AVAILABLE",
    )

    fun basementEntranceTags(): List<String> = listOf(
        "ELEVATOR",
        "DISABLED PARKING",
        TAG_RAMP,
        TAG_HANDRAIL,
        "SECURITY ASSISTANCE",
    )

    val rampOptions = listOf("Yes", "With a push", "Too steep", "Not sure")
    val handrailOptions = listOf("Yes", "With effort", "No", "Not sure")
    val elevatorOptions = listOf("Yes", "No", "Not sure")
    val toiletInitialOptions = listOf("Yes", "No", "Not sure")
}

@OptIn(ExperimentalUuidApi::class)
class ContributeFlow(
    placeId: String,
    placeName: String,
    submissionId: String = Uuid.random().toString(),
    initial: ContributeFlowState? = null,
) {
    var state: ContributeFlowState = initial ?: ContributeFlowState(
        placeId = placeId,
        placeName = placeName,
        submissionId = submissionId,
    )

    fun steps(): List<ContributeStep> {
        val s = state
        val list = mutableListOf<ContributeStep>()
        list += ContributeStep.EntranceLocationPick
        for (location in EntranceLocation.entries) {
            if (!s.entranceLocations.contains(location)) continue
            list += ContributeStep.EntranceTags(location)
            val tags = tagsFor(location)
            if (tags.contains(ContributeCatalog.TAG_RAMP)) list += ContributeStep.EntranceRamp(location)
            if (tags.contains(ContributeCatalog.TAG_HANDRAIL)) list += ContributeStep.EntranceHandrail(location)
        }
        list += ContributeStep.Elevator(ElevatorQuestion.WideEntrance)
        if (s.elevatorAnswers[ElevatorQuestion.WideEntrance] != "No") {
            list += ContributeStep.Elevator(ElevatorQuestion.SpaceToManeuver)
            list += ContributeStep.Elevator(ElevatorQuestion.ReachableButtons)
        }
        list += ContributeStep.ToiletInitial
        if (s.toiletInitialAnswer == "Yes") {
            ToiletSurveyQuestion.entries.forEach { list += ContributeStep.Toilet(it) }
            list += ContributeStep.ToiletLocation
        }
        list += ContributeStep.FinalReview
        return list
    }

    fun currentStep(): ContributeStep? = steps().getOrNull(state.stepIndex)

    fun canContinue(step: ContributeStep): Boolean = when (step) {
        is ContributeStep.EntranceLocationPick -> state.entranceLocations.isNotEmpty()
        is ContributeStep.EntranceTags -> tagsFor(step.location).isNotEmpty()
        is ContributeStep.EntranceRamp -> rampAnswer(step.location) != null
        is ContributeStep.EntranceHandrail -> handrailAnswer(step.location) != null
        is ContributeStep.Elevator -> state.elevatorAnswers[step.question] != null
        ContributeStep.ToiletInitial -> state.toiletInitialAnswer != null
        is ContributeStep.Toilet -> state.toiletAnswers[step.question] != null
        ContributeStep.ToiletLocation -> true
        ContributeStep.FinalReview -> true
        ContributeStep.Submitted -> true
    }

    fun goNext() {
        clampIndex(state.stepIndex + 1)
    }

    fun goBack() {
        if (state.stepIndex == 0) {
            state = state.copy(showExitConfirmation = hasProgress())
        } else {
            clampIndex(state.stepIndex - 1)
        }
    }

    fun dismissExitConfirmation() {
        state = state.copy(showExitConfirmation = false)
    }

    fun confirmExit(): Boolean = hasProgress()

    fun markSubmitted() {
        state = state.copy(stepIndex = steps().size)
    }

    private fun clampIndex(index: Int) {
        val max = maxOf(steps().size - 1, 0)
        state = state.copy(stepIndex = index.coerceIn(0, max), showExitConfirmation = false)
    }

    fun hasProgress(): Boolean {
        val s = state
        return s.stepIndex > 0 ||
            s.entranceLocations.isNotEmpty() ||
            s.lobbyTags.isNotEmpty() ||
            s.basementTags.isNotEmpty() ||
            s.elevatorAnswers.isNotEmpty() ||
            s.toiletInitialAnswer != null ||
            s.lobbyNotes.text.isNotBlank() ||
            s.basementNotes.text.isNotBlank() ||
            s.elevatorNotes.text.isNotBlank() ||
            s.toiletNotes.text.isNotBlank() ||
            allPhotos().isNotEmpty()
    }

    fun tagsFor(location: EntranceLocation): Set<String> = when (location) {
        EntranceLocation.Lobby -> state.lobbyTags
        EntranceLocation.Basement -> state.basementTags
    }

    fun rampAnswer(location: EntranceLocation): String? = when (location) {
        EntranceLocation.Lobby -> state.lobbyRampAnswer
        EntranceLocation.Basement -> state.basementRampAnswer
    }

    fun handrailAnswer(location: EntranceLocation): String? = when (location) {
        EntranceLocation.Lobby -> state.lobbyHandrailAnswer
        EntranceLocation.Basement -> state.basementHandrailAnswer
    }

    fun notesFor(location: EntranceLocation): FacilityNotes = when (location) {
        EntranceLocation.Lobby -> state.lobbyNotes
        EntranceLocation.Basement -> state.basementNotes
    }

    fun allPhotos(): List<LocalReviewPhoto> =
        state.lobbyNotes.photos + state.basementNotes.photos +
            state.elevatorNotes.photos + state.toiletNotes.photos

    fun toSubmission(): ReviewSubmission {
        val s = state
        val lobby = entranceReport(EntranceLocation.Lobby, s.lobbyTags, s.lobbyNotes)
        val basement = entranceReport(EntranceLocation.Basement, s.basementTags, s.basementNotes)
        val entrances = listOfNotNull(lobby, basement).filter { it.hasContent() }
        val elevator = elevatorReport()
        val toilet = toiletReport()
        return ReviewSubmission(
            submissionId = s.submissionId,
            placeId = s.placeId,
            entrances = entrances.ifEmpty { null },
            elevator = elevator,
            toilet = toilet,
        )
    }

    fun pendingPhotos(): List<PendingReviewPhoto> {
        fun map(slot: ReviewPhotoSlot, notes: FacilityNotes) =
            notes.photos.map { PendingReviewPhoto(slot, it.fileId, it.jpeg, it.caption) }
        return map(ReviewPhotoSlot.Lobby, state.lobbyNotes) +
            map(ReviewPhotoSlot.Basement, state.basementNotes) +
            map(ReviewPhotoSlot.Elevator, state.elevatorNotes) +
            map(ReviewPhotoSlot.Toilet, state.toiletNotes)
    }

    private fun entranceReport(location: EntranceLocation, tags: Set<String>, notes: FacilityNotes): EntranceReport {
        val door = when {
            tags.contains(ContributeCatalog.TAG_AUTO_DOORS) -> "automatic"
            tags.contains(ContributeCatalog.TAG_MANUAL_DOORS) -> "manual"
            else -> null
        }
        return EntranceReport(
            location = location.name.lowercase(),
            hasDropoffRamp = if (tags.contains(ContributeCatalog.TAG_RAMP)) true else null,
            hasRails = if (tags.contains(ContributeCatalog.TAG_HANDRAIL)) true else null,
            doorType = door,
            review = noteOrNull(notes),
        )
    }

    private fun elevatorReport(): ElevatorReport {
        val answers = state.elevatorAnswers
        val wideNo = answers[ElevatorQuestion.WideEntrance] == "No"
        val spaceNo = answers[ElevatorQuestion.SpaceToManeuver] == "No"
        val answered = ElevatorQuestion.entries.mapNotNull { answers[it] }
        val wheelchairAccessible = when {
            answered.contains("No") -> false
            answered.size == ElevatorQuestion.entries.size -> true
            else -> null
        }
        val blockers = if (wheelchairAccessible == false && (wideNo || spaceNo)) {
            listOf("too_small")
        } else {
            emptyList()
        }
        return ElevatorReport(
            exists = if (answers.isNotEmpty()) true else null,
            wheelchairAccessible = if (answers.isNotEmpty()) wheelchairAccessible else null,
            blockers = if (wheelchairAccessible == false) blockers else emptyList(),
            review = noteOrNull(state.elevatorNotes),
        )
    }

    private fun toiletReport(): ToiletReport {
        val has = when (state.toiletInitialAnswer) {
            "Yes" -> true
            "No" -> false
            else -> null
        }
        val noteText = buildString {
            if (state.toiletNotes.text.isNotBlank()) append(state.toiletNotes.text)
            if (state.toiletLocationNote.isNotBlank()) {
                if (isNotEmpty()) append("\n")
                append(state.toiletLocationNote)
            }
        }
        val notes = if (noteText.isBlank() && state.toiletNotes.photos.isEmpty()) {
            FacilityNotes()
        } else {
            state.toiletNotes.copy(text = noteText)
        }
        return ToiletReport(
            hasDisabledToilet = has,
            review = noteOrNull(notes),
        )
    }

    private fun noteOrNull(notes: FacilityNotes): ReviewNote? {
        val text = notes.text.trim().ifBlank { null }
        if (text == null && notes.photos.isEmpty()) return null
        return ReviewNote(text = text, photoUrls = emptyList(), photoCaptions = emptyList())
    }

    private fun EntranceReport.hasContent(): Boolean =
        hasDropoffRamp != null || hasRails != null || doorType != null || isWideEnough != null || review != null
}

fun newPhotoFileId(): String = buildString {
    repeat(32) { append(Random.nextInt(16).toString(16)) }
}
