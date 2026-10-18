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
    data object CategoryPick : ContributeStep()
    data object EntrancePhotos : ContributeStep()
    data object EntranceLocationPick : ContributeStep()
    data class EntranceTags(val location: EntranceLocation) : ContributeStep()
    data class EntranceRamp(val location: EntranceLocation) : ContributeStep()
    data class EntranceHandrail(val location: EntranceLocation) : ContributeStep()
    data object EntranceAnother : ContributeStep()
    data object ElevatorPhotos : ContributeStep()
    data class Elevator(val question: ElevatorQuestion) : ContributeStep()
    data object ElevatorLocation : ContributeStep()
    data object ElevatorAnother : ContributeStep()
    data object ToiletPhotos : ContributeStep()
    data class Toilet(val question: ToiletSurveyQuestion) : ContributeStep()
    data object ToiletLocation : ContributeStep()
    data object ToiletAnother : ContributeStep()
    data class SupplementalNotes(val category: ContributeReviewCategory) : ContributeStep()
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

/** One entrance walk: the locations picked in that pass, plus their tags and notes. */
data class EntrancePass(
    val photos: List<LocalReviewPhoto> = emptyList(),
    val locations: Set<EntranceLocation> = emptySet(),
    val lobbyTags: Set<String> = emptySet(),
    val basementTags: Set<String> = emptySet(),
    val lobbyRampAnswer: String? = null,
    val basementRampAnswer: String? = null,
    val lobbyHandrailAnswer: String? = null,
    val basementHandrailAnswer: String? = null,
    val lobbyNotes: FacilityNotes = FacilityNotes(),
    val basementNotes: FacilityNotes = FacilityNotes(),
)

/** One elevator the contributor has finished, or the one still being answered. */
data class ElevatorPass(
    val answers: Map<ElevatorQuestion, String> = emptyMap(),
    val notes: FacilityNotes = FacilityNotes(),
)

/** One accessible toilet the contributor has finished, or the one still being answered. */
data class ToiletPass(
    val answers: Map<ToiletSurveyQuestion, String> = emptyMap(),
    val location: String = "",
    val photos: List<LocalReviewPhoto> = emptyList(),
)

data class ContributeFlowState(
    val placeId: String,
    val placeName: String,
    val submissionId: String,
    val stepIndex: Int = 0,
    val selectedCategories: Set<ContributeReviewCategory> = emptySet(),
    val supplementalNotes: Map<ContributeReviewCategory, FacilityNotes> = emptyMap(),
    val entrancePhotos: List<LocalReviewPhoto> = emptyList(),
    val entranceLocations: Set<EntranceLocation> = emptySet(),
    val lobbyTags: Set<String> = emptySet(),
    val basementTags: Set<String> = emptySet(),
    val lobbyRampAnswer: String? = null,
    val basementRampAnswer: String? = null,
    val lobbyHandrailAnswer: String? = null,
    val basementHandrailAnswer: String? = null,
    val completedEntrancePasses: List<EntrancePass> = emptyList(),
    val elevatorAnswers: Map<ElevatorQuestion, String> = emptyMap(),
    val completedElevatorPasses: List<ElevatorPass> = emptyList(),
    val toiletAnswers: Map<ToiletSurveyQuestion, String> = emptyMap(),
    val completedToiletPasses: List<ToiletPass> = emptyList(),
    val toiletLocationNote: String = "",
    val toiletPhotos: List<LocalReviewPhoto> = emptyList(),
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
    val elevatorOptions = listOf("Yes", "No", "Not Sure")
    val elevatorAnotherOptions = listOf("Yes", "No")
    val entranceAnotherOptions = listOf("Yes", "No")
    val toiletAnotherOptions = listOf("Yes", "No")
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

    // Primary-user (wheelchair) contribute flow. The secondary-user flow is not built yet.
    fun steps(): List<ContributeStep> {
        val s = state
        val list = mutableListOf<ContributeStep>()
        list += ContributeStep.CategoryPick
        if (ContributeReviewCategory.Entrance in s.selectedCategories) {
            list += ContributeStep.EntrancePhotos
            list += ContributeStep.EntranceLocationPick
            for (location in EntranceLocation.entries) {
                if (!s.entranceLocations.contains(location)) continue
                list += ContributeStep.EntranceTags(location)
                val tags = tagsFor(location)
                // Notes to DEV: Ramp and/or Handrail have a follow-up question.
                // Every other tag only records whether it is present. Do not add extra screens for those yet.
                if (tags.contains(ContributeCatalog.TAG_RAMP)) list += ContributeStep.EntranceRamp(location)
                if (tags.contains(ContributeCatalog.TAG_HANDRAIL)) list += ContributeStep.EntranceHandrail(location)
            }
            list += ContributeStep.EntranceAnother
        }
        if (ContributeReviewCategory.Elevator in s.selectedCategories) {
            list += ContributeStep.ElevatorPhotos
            list += ContributeStep.Elevator(ElevatorQuestion.WideEntrance)
            if (s.elevatorAnswers[ElevatorQuestion.WideEntrance] != "No") {
                list += ContributeStep.Elevator(ElevatorQuestion.SpaceToManeuver)
                list += ContributeStep.Elevator(ElevatorQuestion.ReachableButtons)
            }
            list += ContributeStep.ElevatorLocation
            list += ContributeStep.ElevatorAnother
        }
        if (ContributeReviewCategory.Toilet in s.selectedCategories) {
            list += ContributeStep.ToiletPhotos
            ToiletSurveyQuestion.entries.forEach { list += ContributeStep.Toilet(it) }
            list += ContributeStep.ToiletLocation
            list += ContributeStep.ToiletAnother
        }
        for (category in ContributeReviewCategory.supplemental) {
            if (category in s.selectedCategories) {
                list += ContributeStep.SupplementalNotes(category)
            }
        }
        list += ContributeStep.FinalReview
        return list
    }

    fun toggleCategory(category: ContributeReviewCategory) {
        val next = state.selectedCategories.toMutableSet()
        if (category in next) next.remove(category) else next.add(category)
        state = state.copy(selectedCategories = next)
    }

    fun currentStep(): ContributeStep? = steps().getOrNull(state.stepIndex)

    fun canContinue(step: ContributeStep): Boolean = when (step) {
        ContributeStep.CategoryPick -> state.selectedCategories.isNotEmpty()
        ContributeStep.EntrancePhotos -> true
        ContributeStep.EntranceLocationPick -> state.entranceLocations.isNotEmpty()
        is ContributeStep.EntranceTags -> tagsFor(step.location).isNotEmpty()
        is ContributeStep.EntranceRamp -> rampAnswer(step.location) != null
        is ContributeStep.EntranceHandrail -> handrailAnswer(step.location) != null
        ContributeStep.EntranceAnother -> false
        ContributeStep.ElevatorPhotos -> true
        is ContributeStep.Elevator -> state.elevatorAnswers[step.question] != null
        ContributeStep.ElevatorLocation -> true
        ContributeStep.ElevatorAnother -> false
        ContributeStep.ToiletPhotos -> true
        is ContributeStep.Toilet -> state.toiletAnswers[step.question] != null
        ContributeStep.ToiletLocation -> true
        ContributeStep.ToiletAnother -> false
        is ContributeStep.SupplementalNotes -> true
        ContributeStep.FinalReview -> true
        ContributeStep.Submitted -> true
    }

    fun goNext() {
        clampIndex(state.stepIndex + 1)
    }

    fun goBack() {
        if (state.stepIndex == 0) {
            state = state.copy(showExitConfirmation = hasProgress())
            return
        }
        val step = currentStep()
        val previous = steps().getOrNull(state.stepIndex - 1)
        val restartingElevator = step == ContributeStep.ElevatorPhotos &&
            state.completedElevatorPasses.isNotEmpty() &&
            currentElevatorPassIsEmpty()
        val returningToElevator = previous == ContributeStep.ElevatorAnother &&
            currentElevatorPassIsEmpty() &&
            state.completedElevatorPasses.isNotEmpty()
        val restartingEntrance = step == ContributeStep.EntrancePhotos &&
            state.completedEntrancePasses.isNotEmpty() &&
            currentEntrancePassIsEmpty()
        val returningToEntrance = previous == ContributeStep.EntranceAnother &&
            currentEntrancePassIsEmpty() &&
            state.completedEntrancePasses.isNotEmpty()
        val restartingToilet = step == ContributeStep.ToiletPhotos &&
            state.completedToiletPasses.isNotEmpty() &&
            currentToiletPassIsEmpty()
        val returningToToilet = previous == ContributeStep.ToiletAnother &&
            currentToiletPassIsEmpty() &&
            state.completedToiletPasses.isNotEmpty()
        when {
            restartingElevator || returningToElevator -> restoreLastElevatorPass()
            restartingEntrance || returningToEntrance -> restoreLastEntrancePass()
            restartingToilet || returningToToilet -> restoreLastToiletPass()
            else -> clampIndex(state.stepIndex - 1)
        }
    }

    /** Yes restarts the entrance section. No leaves it. Either choice saves the pass just finished. */
    fun chooseAnotherEntrance(answer: String) {
        val completed = state.completedEntrancePasses + currentEntrancePass()
        state = state.copy(
            completedEntrancePasses = completed,
            entrancePhotos = emptyList(),
            entranceLocations = emptySet(),
            lobbyTags = emptySet(),
            basementTags = emptySet(),
            lobbyRampAnswer = null,
            basementRampAnswer = null,
            lobbyHandrailAnswer = null,
            basementHandrailAnswer = null,
            lobbyNotes = FacilityNotes(),
            basementNotes = FacilityNotes(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.EntrancePhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            val another = steps().indexOf(ContributeStep.EntranceAnother)
            clampIndex(if (another >= 0) another + 1 else state.stepIndex + 1)
        }
    }

    /** Yes restarts the elevator section. No leaves it. Either choice saves the pass just finished. */
    fun chooseAnotherElevator(answer: String) {
        val completed = state.completedElevatorPasses + currentElevatorPass()
        state = state.copy(
            completedElevatorPasses = completed,
            elevatorAnswers = emptyMap(),
            elevatorNotes = FacilityNotes(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.ElevatorPhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            val another = steps().indexOf(ContributeStep.ElevatorAnother)
            clampIndex(if (another >= 0) another + 1 else state.stepIndex + 1)
        }
    }

    /** Yes restarts the toilet section. No leaves it. Either choice saves the pass just finished. */
    fun chooseAnotherToilet(answer: String) {
        val completed = state.completedToiletPasses + currentToiletPass()
        state = state.copy(
            completedToiletPasses = completed,
            toiletAnswers = emptyMap(),
            toiletLocationNote = "",
            toiletPhotos = emptyList(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.ToiletPhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            val another = steps().indexOf(ContributeStep.ToiletAnother)
            clampIndex(if (another >= 0) another + 1 else state.stepIndex + 1)
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
            s.selectedCategories.isNotEmpty() ||
            s.supplementalNotes.values.any { it.text.isNotBlank() || it.photos.isNotEmpty() } ||
            s.entranceLocations.isNotEmpty() ||
            s.completedEntrancePasses.isNotEmpty() ||
            s.lobbyTags.isNotEmpty() ||
            s.basementTags.isNotEmpty() ||
            s.elevatorAnswers.isNotEmpty() ||
            s.completedElevatorPasses.isNotEmpty() ||
            s.toiletAnswers.isNotEmpty() ||
            s.completedToiletPasses.isNotEmpty() ||
            s.toiletPhotos.isNotEmpty() ||
            s.toiletLocationNote.isNotBlank() ||
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

    fun supplementalNotesFor(category: ContributeReviewCategory): FacilityNotes =
        state.supplementalNotes[category] ?: FacilityNotes()

    fun allPhotos(): List<LocalReviewPhoto> =
        entrancePassesForReport().flatMap { it.photos + it.lobbyNotes.photos + it.basementNotes.photos } +
            elevatorNotesForReport().photos +
            toiletPassesForReport().flatMap { it.photos } + state.toiletNotes.photos +
            state.supplementalNotes.values.flatMap { it.photos }

    /** Section-level entrance photos attach to Lobby when selected, otherwise Basement. */
    fun primaryEntranceForSectionPhotos(): EntranceLocation? = when {
        EntranceLocation.Lobby in state.entranceLocations -> EntranceLocation.Lobby
        EntranceLocation.Basement in state.entranceLocations -> EntranceLocation.Basement
        else -> null
    }

    fun entranceNotesForReport(location: EntranceLocation): FacilityNotes {
        val base = notesFor(location)
        if (location != primaryEntranceForSectionPhotos() || state.entrancePhotos.isEmpty()) {
            return base
        }
        return base.copy(photos = state.entrancePhotos + base.photos)
    }

    fun toSubmission(): ReviewSubmission {
        val entrances = entrancePassesForReport().flatMap { reportsFor(it) }
        val elevator = elevatorReport()
        val toilet = toiletReport()
        return ReviewSubmission(
            submissionId = state.submissionId,
            placeId = state.placeId,
            entrances = entrances.ifEmpty { null },
            elevator = elevator,
            toilet = toilet,
        )
    }

    fun pendingPhotos(): List<PendingReviewPhoto> {
        fun map(slot: ReviewPhotoSlot, notes: FacilityNotes) =
            notes.photos.map { PendingReviewPhoto(slot, it.fileId, it.jpeg, it.caption) }
        val supplemental = ContributeReviewCategory.supplemental.flatMap { category ->
            map(ReviewPhotoSlot.Toilet, supplementalNotesFor(category))
        }
        return map(ReviewPhotoSlot.Lobby, FacilityNotes(photos = photosForSlot(EntranceLocation.Lobby))) +
            map(ReviewPhotoSlot.Basement, FacilityNotes(photos = photosForSlot(EntranceLocation.Basement))) +
            map(ReviewPhotoSlot.Elevator, elevatorNotesForReport()) +
            map(ReviewPhotoSlot.Toilet, FacilityNotes(photos = toiletPassesForReport().flatMap { it.photos })) +
            map(ReviewPhotoSlot.Toilet, state.toiletNotes) +
            supplemental
    }

    private fun entrancePassesForReport(): List<EntrancePass> {
        val current = currentEntrancePass()
        val includeCurrent = !currentEntrancePassIsEmpty()
        return state.completedEntrancePasses + if (includeCurrent) listOf(current) else emptyList()
    }

    private fun currentEntrancePass(): EntrancePass = EntrancePass(
        photos = state.entrancePhotos,
        locations = state.entranceLocations,
        lobbyTags = state.lobbyTags,
        basementTags = state.basementTags,
        lobbyRampAnswer = state.lobbyRampAnswer,
        basementRampAnswer = state.basementRampAnswer,
        lobbyHandrailAnswer = state.lobbyHandrailAnswer,
        basementHandrailAnswer = state.basementHandrailAnswer,
        lobbyNotes = state.lobbyNotes,
        basementNotes = state.basementNotes,
    )

    private fun currentEntrancePassIsEmpty(): Boolean {
        val pass = currentEntrancePass()
        return pass.photos.isEmpty() &&
            pass.locations.isEmpty() &&
            pass.lobbyTags.isEmpty() &&
            pass.basementTags.isEmpty() &&
            pass.lobbyRampAnswer == null &&
            pass.basementRampAnswer == null &&
            pass.lobbyHandrailAnswer == null &&
            pass.basementHandrailAnswer == null &&
            pass.lobbyNotes.text.isBlank() &&
            pass.lobbyNotes.photos.isEmpty() &&
            pass.basementNotes.text.isBlank() &&
            pass.basementNotes.photos.isEmpty()
    }

    private fun restoreLastEntrancePass() {
        val last = state.completedEntrancePasses.lastOrNull() ?: return
        state = state.copy(
            completedEntrancePasses = state.completedEntrancePasses.dropLast(1),
            entrancePhotos = last.photos,
            entranceLocations = last.locations,
            lobbyTags = last.lobbyTags,
            basementTags = last.basementTags,
            lobbyRampAnswer = last.lobbyRampAnswer,
            basementRampAnswer = last.basementRampAnswer,
            lobbyHandrailAnswer = last.lobbyHandrailAnswer,
            basementHandrailAnswer = last.basementHandrailAnswer,
            lobbyNotes = last.lobbyNotes,
            basementNotes = last.basementNotes,
        )
        val index = steps().indexOf(ContributeStep.EntranceAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun reportsFor(pass: EntrancePass): List<EntranceReport> {
        val primary = when {
            EntranceLocation.Lobby in pass.locations -> EntranceLocation.Lobby
            EntranceLocation.Basement in pass.locations -> EntranceLocation.Basement
            else -> null
        }
        return EntranceLocation.entries.mapNotNull { location ->
            if (location !in pass.locations) return@mapNotNull null
            val base = when (location) {
                EntranceLocation.Lobby -> pass.lobbyNotes
                EntranceLocation.Basement -> pass.basementNotes
            }
            val notes = if (location == primary && pass.photos.isNotEmpty()) {
                base.copy(photos = pass.photos + base.photos)
            } else {
                base
            }
            val tags = when (location) {
                EntranceLocation.Lobby -> pass.lobbyTags
                EntranceLocation.Basement -> pass.basementTags
            }
            entranceReport(location, tags, notes)
        }.filter { it.hasContent() }
    }

    private fun photosForSlot(location: EntranceLocation): List<LocalReviewPhoto> =
        entrancePassesForReport().flatMap { pass ->
            val primary = when {
                EntranceLocation.Lobby in pass.locations -> EntranceLocation.Lobby
                EntranceLocation.Basement in pass.locations -> EntranceLocation.Basement
                else -> null
            }
            val notes = when (location) {
                EntranceLocation.Lobby -> pass.lobbyNotes
                EntranceLocation.Basement -> pass.basementNotes
            }
            if (location == primary) pass.photos + notes.photos else notes.photos
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

    fun elevatorNotesForReport(): FacilityNotes {
        val passes = elevatorPassesForReport()
        val text = buildString {
            passes.forEachIndexed { index, pass ->
                val lines = mutableListOf<String>()
                val location = pass.notes.text.trim()
                if (location.isNotEmpty()) lines += "Location: $location"
                for (question in ElevatorQuestion.entries) {
                    val answer = pass.answers[question] ?: continue
                    lines += "${elevatorQuestionLabel(question)}: $answer"
                }
                if (lines.isEmpty()) return@forEachIndexed
                if (isNotEmpty()) append("\n\n")
                if (passes.size > 1) append("[Elevator ${index + 1}]\n")
                append(lines.joinToString("\n"))
            }
        }.trim()
        val photos = passes.flatMap { it.notes.photos }
        return FacilityNotes(text = text, photos = photos)
    }

    private fun elevatorReport(): ElevatorReport {
        val passes = elevatorPassesForReport()
        val anyAnswers = passes.any { it.answers.isNotEmpty() }
        val anyNo = passes.any { pass -> pass.answers.values.any { it == "No" } }
        val fullyAccessible = passes.isNotEmpty() && passes.all { pass ->
            val answered = ElevatorQuestion.entries.mapNotNull { pass.answers[it] }
            answered.size == ElevatorQuestion.entries.size && !answered.contains("No")
        }
        val wheelchairAccessible = when {
            !anyAnswers -> null
            anyNo -> false
            fullyAccessible -> true
            else -> null
        }
        val failedFit = passes.any { pass ->
            pass.answers[ElevatorQuestion.WideEntrance] == "No" ||
                pass.answers[ElevatorQuestion.SpaceToManeuver] == "No"
        }
        val blockers = if (wheelchairAccessible == false && failedFit) {
            listOf("too_small")
        } else {
            emptyList()
        }
        return ElevatorReport(
            exists = if (anyAnswers) true else null,
            wheelchairAccessible = wheelchairAccessible,
            blockers = if (wheelchairAccessible == false) blockers else emptyList(),
            review = noteOrNull(elevatorNotesForReport()),
        )
    }

    private fun elevatorPassesForReport(): List<ElevatorPass> {
        val current = currentElevatorPass()
        val includeCurrent = current.answers.isNotEmpty() ||
            current.notes.text.isNotBlank() ||
            current.notes.photos.isNotEmpty()
        return state.completedElevatorPasses + if (includeCurrent) listOf(current) else emptyList()
    }

    private fun currentElevatorPass(): ElevatorPass =
        ElevatorPass(state.elevatorAnswers, state.elevatorNotes)

    private fun currentElevatorPassIsEmpty(): Boolean {
        val pass = currentElevatorPass()
        return pass.answers.isEmpty() && pass.notes.text.isBlank() && pass.notes.photos.isEmpty()
    }

    private fun restoreLastElevatorPass() {
        val last = state.completedElevatorPasses.lastOrNull() ?: return
        state = state.copy(
            completedElevatorPasses = state.completedElevatorPasses.dropLast(1),
            elevatorAnswers = last.answers,
            elevatorNotes = last.notes,
        )
        val index = steps().indexOf(ContributeStep.ElevatorAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun elevatorQuestionLabel(question: ElevatorQuestion): String = when (question) {
        ElevatorQuestion.WideEntrance -> "Entrance Width"
        ElevatorQuestion.SpaceToManeuver -> "Space to Maneuver"
        ElevatorQuestion.ReachableButtons -> "Reachable Buttons"
    }

    private fun toiletPassesForReport(): List<ToiletPass> {
        val current = currentToiletPass()
        val includeCurrent = current.answers.isNotEmpty() ||
            current.location.isNotBlank() ||
            current.photos.isNotEmpty()
        return state.completedToiletPasses + if (includeCurrent) listOf(current) else emptyList()
    }

    private fun currentToiletPass(): ToiletPass = ToiletPass(
        answers = state.toiletAnswers,
        location = state.toiletLocationNote,
        photos = state.toiletPhotos,
    )

    private fun currentToiletPassIsEmpty(): Boolean {
        val pass = currentToiletPass()
        return pass.answers.isEmpty() && pass.location.isBlank() && pass.photos.isEmpty()
    }

    private fun restoreLastToiletPass() {
        val last = state.completedToiletPasses.lastOrNull() ?: return
        state = state.copy(
            completedToiletPasses = state.completedToiletPasses.dropLast(1),
            toiletAnswers = last.answers,
            toiletLocationNote = last.location,
            toiletPhotos = last.photos,
        )
        val index = steps().indexOf(ContributeStep.ToiletAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun toiletQuestionLabel(question: ToiletSurveyQuestion): String = when (question) {
        ToiletSurveyQuestion.DoorKind -> "Doors"
        ToiletSurveyQuestion.Seat -> "Toilet Seat"
        ToiletSurveyQuestion.GrabBars -> "Grab Bars"
        ToiletSurveyQuestion.Space -> "Space to Maneuver"
        ToiletSurveyQuestion.Sink -> "Sink"
        ToiletSurveyQuestion.Emergency -> "Emergency Aid"
    }

    /** Interim: fold supplemental category notes into toilet review until API has dedicated fields. */
    private fun supplementalTextBlock(): String = buildString {
        for (category in ContributeReviewCategory.supplemental) {
            val notes = supplementalNotesFor(category)
            if (notes.text.isBlank()) continue
            if (isNotEmpty()) append("\n\n")
            append("[${ContributeCategoryLabels.supplementalSectionTitle(category)}]\n")
            append(notes.text.trim())
        }
    }

    private fun toiletReport(): ToiletReport {
        val passes = toiletPassesForReport()
        val hasContent = passes.any { pass ->
            pass.answers.isNotEmpty() || pass.location.isNotBlank() || pass.photos.isNotEmpty()
        }
        val passText = buildString {
            passes.forEachIndexed { index, pass ->
                val lines = mutableListOf<String>()
                val location = pass.location.trim()
                if (location.isNotEmpty()) lines += "Location: $location"
                for (question in ToiletSurveyQuestion.entries) {
                    val answer = pass.answers[question] ?: continue
                    lines += "${toiletQuestionLabel(question)}: $answer"
                }
                if (lines.isEmpty()) return@forEachIndexed
                if (isNotEmpty()) append("\n\n")
                if (passes.size > 1) append("[Toilet ${index + 1}]\n")
                append(lines.joinToString("\n"))
            }
        }.trim()
        val noteText = buildString {
            val supplemental = supplementalTextBlock()
            if (supplemental.isNotBlank()) append(supplemental)
            if (passText.isNotBlank()) {
                if (isNotEmpty()) append("\n\n")
                append(passText)
            }
            if (state.toiletNotes.text.isNotBlank()) {
                if (isNotEmpty()) append("\n\n")
                append(state.toiletNotes.text)
            }
        }
        val supplementalPhotos = ContributeReviewCategory.supplemental.flatMap { supplementalNotesFor(it).photos }
        val allToiletPhotos = passes.flatMap { it.photos } + state.toiletNotes.photos + supplementalPhotos
        val notes = if (noteText.isBlank() && allToiletPhotos.isEmpty()) {
            FacilityNotes()
        } else {
            state.toiletNotes.copy(text = noteText, photos = allToiletPhotos)
        }
        return ToiletReport(
            hasDisabledToilet = if (hasContent) true else null,
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
