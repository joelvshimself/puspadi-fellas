package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionSubmission
import kotlinx.serialization.Serializable
import kotlinx.serialization.Transient
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

enum class CategorySectionStatus { InProgress, Complete }

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
    data object PathwayPhotos : ContributeStep()
    data object PathwayNotice : ContributeStep()
    data object SeatingPhotos : ContributeStep()
    data object SeatingQuestion : ContributeStep()
    data object ParkingPhotos : ContributeStep()
    data object ParkingQuestion : ContributeStep()
    data object Submitted : ContributeStep()
}

/** A picked photo. [jpeg] isn't serialized: saved drafts keep the bytes in their own files (ContributeDrafts). */
@Serializable
data class LocalReviewPhoto(
    val fileId: String,
    @Transient val jpeg: ByteArray = ByteArray(0),
    val caption: String = "",
)

@Serializable
data class FacilityNotes(
    val text: String = "",
    val photos: List<LocalReviewPhoto> = emptyList(),
)

/** One entrance walk: the locations picked in that pass, plus their tags and evidence photos. */
@Serializable
data class EntrancePass(
    val photos: List<LocalReviewPhoto> = emptyList(),
    val locations: Set<EntranceLocation> = emptySet(),
    val lobbyTags: Set<String> = emptySet(),
    val basementTags: Set<String> = emptySet(),
    val lobbyRampAnswer: String? = null,
    val basementRampAnswer: String? = null,
    val lobbyHandrailAnswer: String? = null,
    val basementHandrailAnswer: String? = null,
    val lobbyEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
    val basementEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
)

/** One elevator the contributor has finished, or the one still being answered. */
@Serializable
data class ElevatorPass(
    val answers: Map<ElevatorQuestion, String> = emptyMap(),
    val photos: List<LocalReviewPhoto> = emptyList(),
    val location: String = "",
    val evidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
)

/** One accessible toilet the contributor has finished, or the one still being answered. */
@Serializable
data class ToiletPass(
    val answers: Map<ToiletSurveyQuestion, String> = emptyMap(),
    val location: String = "",
    val photos: List<LocalReviewPhoto> = emptyList(),
    val evidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
)

@Serializable
data class ContributeFlowState(
    val placeId: String,
    val placeName: String,
    val submissionId: String,
    val persona: ContributePersona = ContributePersona.Wheelchair,
    val stepIndex: Int = 0,
    /** Section the contributor is filling in. Null while they are on the menu. */
    val activeCategory: ContributeReviewCategory? = null,
    val sectionStatus: Map<ContributeReviewCategory, CategorySectionStatus> = emptyMap(),
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
    val toiletEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
    val lobbyEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
    val basementEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
    val elevatorPhotos: List<LocalReviewPhoto> = emptyList(),
    val elevatorLocation: String = "",
    val elevatorEvidence: Map<String, List<LocalReviewPhoto>> = emptyMap(),
    val pathwayNotices: Set<String> = emptySet(),
    val seatingAnswer: String? = null,
    val seatingPhotos: List<LocalReviewPhoto> = emptyList(),
    val parkingAnswer: String? = null,
    val parkingPhotos: List<LocalReviewPhoto> = emptyList(),
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
    val seatingOptions = listOf("Yes", "No", "Not sure")
    val parkingOptions = listOf("Yes", "No", "Not sure")

    const val NOTICE_NOTHING = "Nothing notable"
    val pathwayNoticeOptions = listOf(
        "Loose gravel or sand",
        "Rough or uneven surface",
        "Tight gap",
        "Narrow pathway",
        "Steep section",
        "Curb or step with no ramp",
        NOTICE_NOTHING,
    )
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

    // Menu, one open section, or final review. Categories are not chained together.
    fun steps(): List<ContributeStep> {
        val list = mutableListOf<ContributeStep>()
        list += ContributeStep.CategoryPick
        val category = state.activeCategory
        when (category) {
            ContributeReviewCategory.Entrance -> appendEntrance(list)
            ContributeReviewCategory.Elevator -> appendElevator(list)
            ContributeReviewCategory.Toilet -> appendToilet(list)
            ContributeReviewCategory.OutdoorPathways -> {
                list += ContributeStep.PathwayPhotos
                list += ContributeStep.PathwayNotice
            }
            ContributeReviewCategory.Seating -> {
                list += ContributeStep.SeatingPhotos
                list += ContributeStep.SeatingQuestion
            }
            ContributeReviewCategory.Parking -> {
                list += ContributeStep.ParkingPhotos
                list += ContributeStep.ParkingQuestion
            }
            null -> Unit
        }
        if (category != null) list += ContributeStep.SupplementalNotes(category)
        return list
    }

    private fun appendEntrance(list: MutableList<ContributeStep>) {
        list += ContributeStep.EntrancePhotos
        list += ContributeStep.EntranceLocationPick
        for (location in EntranceLocation.entries) {
            if (!state.entranceLocations.contains(location)) continue
            list += ContributeStep.EntranceTags(location)
            val tags = tagsFor(location)
            // Notes to DEV: Ramp and/or Handrail have a follow-up question.
            // Every other tag only records whether it is present. Do not add extra screens for those yet.
            if (tags.contains(ContributeCatalog.TAG_RAMP)) list += ContributeStep.EntranceRamp(location)
            if (tags.contains(ContributeCatalog.TAG_HANDRAIL)) list += ContributeStep.EntranceHandrail(location)
        }
        list += ContributeStep.EntranceAnother
    }

    private fun appendElevator(list: MutableList<ContributeStep>) {
        list += ContributeStep.ElevatorPhotos
        list += ContributeStep.Elevator(ElevatorQuestion.WideEntrance)
        if (state.elevatorAnswers[ElevatorQuestion.WideEntrance] != "No") {
            list += ContributeStep.Elevator(ElevatorQuestion.SpaceToManeuver)
            list += ContributeStep.Elevator(ElevatorQuestion.ReachableButtons)
        }
        list += ContributeStep.ElevatorLocation
        list += ContributeStep.ElevatorAnother
    }

    private fun appendToilet(list: MutableList<ContributeStep>) {
        list += ContributeStep.ToiletPhotos
        ToiletSurveyQuestion.entries.forEach { list += ContributeStep.Toilet(it) }
        list += ContributeStep.ToiletLocation
        list += ContributeStep.ToiletAnother
    }

    fun openCategory(category: ContributeReviewCategory) {
        state = state.copy(
            activeCategory = category,
            stepIndex = 1,
            showExitConfirmation = false,
        )
    }

    fun finishActiveSection() {
        val category = state.activeCategory ?: return
        state = state.copy(
            sectionStatus = state.sectionStatus + (category to CategorySectionStatus.Complete),
            activeCategory = null,
            stepIndex = 0,
            showExitConfirmation = false,
        )
    }

    /**
     * Back out of the open section to the menu. If the section already has finished passes
     * (e.g. the user answered one elevator, tapped "review another" and then backed out), those
     * still count: the unfinished pass is dropped and the section stays Complete. Otherwise
     * the section is InProgress. Without this, one stray "Yes" made Submit impossible.
     */
    fun leaveActiveSection() {
        val category = state.activeCategory ?: return
        val keepsFinishedPasses = when (category) {
            ContributeReviewCategory.Entrance -> state.completedEntrancePasses.isNotEmpty()
            ContributeReviewCategory.Elevator -> state.completedElevatorPasses.isNotEmpty()
            ContributeReviewCategory.Toilet -> state.completedToiletPasses.isNotEmpty()
            else -> false
        }
        if (keepsFinishedPasses) discardCurrentPass(category)
        state = state.copy(
            sectionStatus = state.sectionStatus + (
                category to if (keepsFinishedPasses) CategorySectionStatus.Complete else CategorySectionStatus.InProgress
            ),
            activeCategory = null,
            stepIndex = 0,
            showExitConfirmation = false,
        )
    }

    private fun discardCurrentPass(category: ContributeReviewCategory) {
        state = when (category) {
            ContributeReviewCategory.Entrance -> state.copy(
                entrancePhotos = emptyList(),
                entranceLocations = emptySet(),
                lobbyTags = emptySet(),
                basementTags = emptySet(),
                lobbyRampAnswer = null,
                basementRampAnswer = null,
                lobbyHandrailAnswer = null,
                basementHandrailAnswer = null,
                lobbyEvidence = emptyMap(),
                basementEvidence = emptyMap(),
            )
            ContributeReviewCategory.Elevator -> state.copy(
                elevatorAnswers = emptyMap(),
                elevatorPhotos = emptyList(),
                elevatorLocation = "",
                elevatorEvidence = emptyMap(),
            )
            ContributeReviewCategory.Toilet -> state.copy(
                toiletAnswers = emptyMap(),
                toiletLocationNote = "",
                toiletPhotos = emptyList(),
                toiletEvidence = emptyMap(),
            )
            else -> state
        }
    }

    fun setCategoryNote(category: ContributeReviewCategory, text: String) {
        val existing = state.supplementalNotes[category] ?: FacilityNotes()
        state = state.copy(supplementalNotes = state.supplementalNotes + (category to existing.copy(text = text)))
    }

    fun currentStep(): ContributeStep? = steps().getOrNull(state.stepIndex)

    fun canContinue(step: ContributeStep): Boolean = when (step) {
        ContributeStep.CategoryPick ->
            state.sectionStatus.values.any { it == CategorySectionStatus.Complete }
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
        ContributeStep.PathwayPhotos -> true
        ContributeStep.PathwayNotice -> state.pathwayNotices.isNotEmpty()
        ContributeStep.SeatingPhotos -> true
        ContributeStep.SeatingQuestion -> state.seatingAnswer != null
        ContributeStep.ParkingPhotos -> true
        ContributeStep.ParkingQuestion -> state.parkingAnswer != null
        ContributeStep.Submitted -> true
    }

    fun goNext() {
        when (currentStep()) {
            ContributeStep.CategoryPick -> Unit
            is ContributeStep.SupplementalNotes -> finishActiveSection()
            else -> clampIndex(state.stepIndex + 1)
        }
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
            previous == ContributeStep.CategoryPick -> leaveActiveSection()
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
            lobbyEvidence = emptyMap(),
            basementEvidence = emptyMap(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.EntrancePhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            openCategoryNotes()
        }
    }

    /** Yes restarts the elevator section. No leaves it. Either choice saves the pass just finished. */
    fun chooseAnotherElevator(answer: String) {
        val completed = state.completedElevatorPasses + currentElevatorPass()
        state = state.copy(
            completedElevatorPasses = completed,
            elevatorAnswers = emptyMap(),
            elevatorPhotos = emptyList(),
            elevatorLocation = "",
            elevatorEvidence = emptyMap(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.ElevatorPhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            openCategoryNotes()
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
            toiletEvidence = emptyMap(),
        )
        if (answer == "Yes") {
            val index = steps().indexOf(ContributeStep.ToiletPhotos)
            clampIndex(if (index >= 0) index else state.stepIndex)
        } else {
            openCategoryNotes()
        }
    }

    /** "Nothing notable" clears every other row, and any other row clears it. */
    fun togglePathwayNotice(option: String) {
        val next = state.pathwayNotices.toMutableSet()
        if (option == ContributeCatalog.NOTICE_NOTHING) {
            if (option in next) next.remove(option) else {
                next.clear()
                next.add(option)
            }
        } else {
            next.remove(ContributeCatalog.NOTICE_NOTHING)
            if (option in next) next.remove(option) else next.add(option)
        }
        state = state.copy(pathwayNotices = next)
    }

    fun dismissExitConfirmation() {
        state = state.copy(showExitConfirmation = false)
    }

    fun confirmExit(): Boolean = hasProgress()

    fun markSubmitted() {
        state = state.copy(stepIndex = steps().size)
    }

    private fun openCategoryNotes() {
        val category = state.activeCategory ?: return
        val index = steps().indexOf(ContributeStep.SupplementalNotes(category))
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun clampIndex(index: Int) {
        val max = maxOf(steps().size - 1, 0)
        state = state.copy(stepIndex = index.coerceIn(0, max), showExitConfirmation = false)
    }

    fun hasProgress(): Boolean {
        val s = state
        return s.stepIndex > 0 ||
            s.sectionStatus.isNotEmpty() ||
            s.activeCategory != null ||
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
            s.toiletEvidence.values.any { it.isNotEmpty() } ||
            s.toiletLocationNote.isNotBlank() ||
            s.pathwayNotices.isNotEmpty() ||
            s.seatingAnswer != null ||
            s.seatingPhotos.isNotEmpty() ||
            s.parkingAnswer != null ||
            s.parkingPhotos.isNotEmpty() ||
            s.lobbyEvidence.values.any { it.isNotEmpty() } ||
            s.basementEvidence.values.any { it.isNotEmpty() } ||
            s.elevatorPhotos.isNotEmpty() ||
            s.elevatorLocation.isNotBlank() ||
            s.elevatorEvidence.values.any { it.isNotEmpty() } ||
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

    fun evidenceFor(location: EntranceLocation): Map<String, List<LocalReviewPhoto>> = when (location) {
        EntranceLocation.Lobby -> state.lobbyEvidence
        EntranceLocation.Basement -> state.basementEvidence
    }

    fun supplementalNotesFor(category: ContributeReviewCategory): FacilityNotes =
        state.supplementalNotes[category] ?: FacilityNotes()

    fun setRampAnswer(location: EntranceLocation, answer: String) {
        state = when (location) {
            EntranceLocation.Lobby -> state.copy(
                lobbyRampAnswer = answer,
                lobbyEvidence = clearEvidence(state.lobbyEvidence, ContributeCodes.RAMP, answer),
            )
            EntranceLocation.Basement -> state.copy(
                basementRampAnswer = answer,
                basementEvidence = clearEvidence(state.basementEvidence, ContributeCodes.RAMP, answer),
            )
        }
    }

    fun setHandrailAnswer(location: EntranceLocation, answer: String) {
        state = when (location) {
            EntranceLocation.Lobby -> state.copy(
                lobbyHandrailAnswer = answer,
                lobbyEvidence = clearEvidence(state.lobbyEvidence, ContributeCodes.HANDRAIL, answer),
            )
            EntranceLocation.Basement -> state.copy(
                basementHandrailAnswer = answer,
                basementEvidence = clearEvidence(state.basementEvidence, ContributeCodes.HANDRAIL, answer),
            )
        }
    }

    fun setElevatorAnswer(question: ElevatorQuestion, answer: String) {
        var answers = state.elevatorAnswers + (question to answer)
        var evidence = clearEvidence(state.elevatorEvidence, ContributeCodes.elevatorQuestion(question), answer)
        if (question == ElevatorQuestion.WideEntrance && answer == "No") {
            answers = answers - ElevatorQuestion.SpaceToManeuver - ElevatorQuestion.ReachableButtons
            evidence = evidence - ContributeCodes.SPACE - ContributeCodes.BUTTONS
        }
        state = state.copy(elevatorAnswers = answers, elevatorEvidence = evidence)
    }

    fun setToiletAnswer(question: ToiletSurveyQuestion, answer: String) {
        val code = ContributeCodes.toiletQuestion(question)
        state = state.copy(
            toiletAnswers = state.toiletAnswers + (question to answer),
            toiletEvidence = if (code == null) state.toiletEvidence else clearEvidence(state.toiletEvidence, code, answer),
        )
    }

    fun canAddPhoto(): Boolean {
        val target = currentPhotoTarget() ?: return false
        return roomFor(target)
    }

    /** Adds a photo to the screen the contributor is on. Returns false when that screen is full. */
    fun addPhoto(photo: LocalReviewPhoto): Boolean {
        val target = currentPhotoTarget() ?: return false
        if (!roomFor(target)) return false
        when (target) {
            PhotoTarget.EntranceSection -> state = state.copy(entrancePhotos = state.entrancePhotos + photo)
            is PhotoTarget.EntranceEvidence -> putEntranceEvidence(target.location, target.question, photo)
            PhotoTarget.ElevatorSection -> state = state.copy(elevatorPhotos = state.elevatorPhotos + photo)
            is PhotoTarget.ElevatorEvidence -> state = state.copy(
                elevatorEvidence = state.elevatorEvidence + (target.question to evidenceList(state.elevatorEvidence, target.question) + photo),
            )
            PhotoTarget.ToiletSection -> state = state.copy(toiletPhotos = state.toiletPhotos + photo)
            is PhotoTarget.ToiletEvidence -> state = state.copy(
                toiletEvidence = state.toiletEvidence + (target.question to evidenceList(state.toiletEvidence, target.question) + photo),
            )
            PhotoTarget.PathwaySection -> appendSupplementalPhoto(ContributeReviewCategory.OutdoorPathways, photo)
            PhotoTarget.SeatingSection -> state = state.copy(seatingPhotos = state.seatingPhotos + photo)
            PhotoTarget.ParkingSection -> state = state.copy(parkingPhotos = state.parkingPhotos + photo)
        }
        return true
    }

    fun removePhoto(fileId: String) {
        fun strip(photos: List<LocalReviewPhoto>) = photos.filter { it.fileId != fileId }
        fun stripMap(photos: Map<String, List<LocalReviewPhoto>>) = photos.mapValues { (_, list) -> strip(list) }
        state = state.copy(
            entrancePhotos = strip(state.entrancePhotos),
            elevatorPhotos = strip(state.elevatorPhotos),
            toiletPhotos = strip(state.toiletPhotos),
            seatingPhotos = strip(state.seatingPhotos),
            parkingPhotos = strip(state.parkingPhotos),
            lobbyEvidence = stripMap(state.lobbyEvidence),
            basementEvidence = stripMap(state.basementEvidence),
            elevatorEvidence = stripMap(state.elevatorEvidence),
            toiletEvidence = stripMap(state.toiletEvidence),
            supplementalNotes = state.supplementalNotes.mapValues { (_, notes) -> notes.copy(photos = strip(notes.photos)) },
            completedEntrancePasses = state.completedEntrancePasses.map { pass ->
                pass.copy(
                    photos = strip(pass.photos),
                    lobbyEvidence = stripMap(pass.lobbyEvidence),
                    basementEvidence = stripMap(pass.basementEvidence),
                )
            },
            completedElevatorPasses = state.completedElevatorPasses.map { pass ->
                pass.copy(photos = strip(pass.photos), evidence = stripMap(pass.evidence))
            },
            completedToiletPasses = state.completedToiletPasses.map { pass ->
                pass.copy(photos = strip(pass.photos), evidence = stripMap(pass.evidence))
            },
        )
    }

    fun allPhotos(): List<LocalReviewPhoto> {
        fun maps(vararg groups: Map<String, List<LocalReviewPhoto>>) = groups.flatMap { it.values.flatten() }
        return entrancePassesForReport().flatMap { pass ->
            pass.photos + maps(pass.lobbyEvidence, pass.basementEvidence)
        } + elevatorPassesForReport().flatMap { it.photos + it.evidence.values.flatten() } +
            toiletPassesForReport().flatMap { it.photos + it.evidence.values.flatten() } +
            state.supplementalNotes.values.flatMap { it.photos } +
            state.seatingPhotos +
            state.parkingPhotos
    }

    fun toSubmission(): ContributionSubmission = buildContribution(state)

    fun pendingPhotos(): List<PendingContributionPhoto> = pendingContributionPhotos(state)

    private fun currentPhotoTarget(): PhotoTarget? = when (val step = currentStep()) {
        ContributeStep.EntrancePhotos -> PhotoTarget.EntranceSection
        is ContributeStep.EntranceRamp ->
            if (ContributeCodes.isNotSure(rampAnswer(step.location))) PhotoTarget.EntranceEvidence(step.location, ContributeCodes.RAMP) else null
        is ContributeStep.EntranceHandrail ->
            if (ContributeCodes.isNotSure(handrailAnswer(step.location))) PhotoTarget.EntranceEvidence(step.location, ContributeCodes.HANDRAIL) else null
        ContributeStep.ElevatorPhotos -> PhotoTarget.ElevatorSection
        is ContributeStep.Elevator -> {
            val code = ContributeCodes.elevatorQuestion(step.question)
            if (ContributeCodes.isNotSure(state.elevatorAnswers[step.question])) PhotoTarget.ElevatorEvidence(code) else null
        }
        ContributeStep.ToiletPhotos -> PhotoTarget.ToiletSection
        is ContributeStep.Toilet -> {
            val code = ContributeCodes.toiletQuestion(step.question)
            if (code != null && ContributeCodes.isNotSure(state.toiletAnswers[step.question])) PhotoTarget.ToiletEvidence(code) else null
        }
        ContributeStep.PathwayPhotos -> PhotoTarget.PathwaySection
        ContributeStep.SeatingPhotos -> PhotoTarget.SeatingSection
        ContributeStep.ParkingPhotos -> PhotoTarget.ParkingSection
        else -> null
    }

    private fun roomFor(target: PhotoTarget): Boolean = when (target) {
        PhotoTarget.EntranceSection -> state.entrancePhotos.size < ContributePhotoLimits.SECTION
        is PhotoTarget.EntranceEvidence -> evidenceCount(evidenceFor(target.location)) < ContributePhotoLimits.EVIDENCE_PER_PASS
        PhotoTarget.ElevatorSection -> state.elevatorPhotos.size < ContributePhotoLimits.SECTION
        is PhotoTarget.ElevatorEvidence -> evidenceCount(state.elevatorEvidence) < ContributePhotoLimits.EVIDENCE_PER_PASS
        PhotoTarget.ToiletSection -> state.toiletPhotos.size < ContributePhotoLimits.SECTION
        is PhotoTarget.ToiletEvidence -> evidenceCount(state.toiletEvidence) < ContributePhotoLimits.EVIDENCE_PER_PASS
        PhotoTarget.PathwaySection -> supplementalNotesFor(ContributeReviewCategory.OutdoorPathways).photos.size < ContributePhotoLimits.SECTION
        PhotoTarget.SeatingSection -> state.seatingPhotos.size < ContributePhotoLimits.SECTION
        PhotoTarget.ParkingSection -> state.parkingPhotos.size < ContributePhotoLimits.SECTION
    }

    private fun putEntranceEvidence(location: EntranceLocation, question: String, photo: LocalReviewPhoto) {
        val current = evidenceFor(location)
        val updated = current + (question to evidenceList(current, question) + photo)
        state = when (location) {
            EntranceLocation.Lobby -> state.copy(lobbyEvidence = updated)
            EntranceLocation.Basement -> state.copy(basementEvidence = updated)
        }
    }

    private fun appendSupplementalPhoto(category: ContributeReviewCategory, photo: LocalReviewPhoto) {
        val next = state.supplementalNotes.toMutableMap()
        val existing = next[category] ?: FacilityNotes()
        next[category] = existing.copy(photos = existing.photos + photo)
        state = state.copy(supplementalNotes = next)
    }

    private fun entrancePassesForReport(): List<EntrancePass> {
        val includeCurrent = state.sectionStatus[ContributeReviewCategory.Entrance] == CategorySectionStatus.Complete &&
            !currentEntrancePassIsEmpty()
        return state.completedEntrancePasses + if (includeCurrent) listOf(currentEntrancePass()) else emptyList()
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
        lobbyEvidence = state.lobbyEvidence,
        basementEvidence = state.basementEvidence,
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
            evidenceCount(pass.lobbyEvidence) == 0 &&
            evidenceCount(pass.basementEvidence) == 0
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
            lobbyEvidence = last.lobbyEvidence,
            basementEvidence = last.basementEvidence,
        )
        val index = steps().indexOf(ContributeStep.EntranceAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun elevatorPassesForReport(): List<ElevatorPass> {
        val includeCurrent = state.sectionStatus[ContributeReviewCategory.Elevator] == CategorySectionStatus.Complete &&
            !currentElevatorPassIsEmpty()
        return state.completedElevatorPasses + if (includeCurrent) listOf(currentElevatorPass()) else emptyList()
    }

    private fun currentElevatorPass(): ElevatorPass = ElevatorPass(
        answers = state.elevatorAnswers,
        photos = state.elevatorPhotos,
        location = state.elevatorLocation,
        evidence = state.elevatorEvidence,
    )

    private fun currentElevatorPassIsEmpty(): Boolean {
        val pass = currentElevatorPass()
        return pass.answers.isEmpty() && pass.photos.isEmpty() && pass.location.isBlank() && evidenceCount(pass.evidence) == 0
    }

    private fun restoreLastElevatorPass() {
        val last = state.completedElevatorPasses.lastOrNull() ?: return
        state = state.copy(
            completedElevatorPasses = state.completedElevatorPasses.dropLast(1),
            elevatorAnswers = last.answers,
            elevatorPhotos = last.photos,
            elevatorLocation = last.location,
            elevatorEvidence = last.evidence,
        )
        val index = steps().indexOf(ContributeStep.ElevatorAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }

    private fun toiletPassesForReport(): List<ToiletPass> {
        val includeCurrent = state.sectionStatus[ContributeReviewCategory.Toilet] == CategorySectionStatus.Complete &&
            !currentToiletPassIsEmpty()
        return state.completedToiletPasses + if (includeCurrent) listOf(currentToiletPass()) else emptyList()
    }

    private fun currentToiletPass(): ToiletPass = ToiletPass(
        answers = state.toiletAnswers,
        location = state.toiletLocationNote,
        photos = state.toiletPhotos,
        evidence = state.toiletEvidence,
    )

    private fun currentToiletPassIsEmpty(): Boolean {
        val pass = currentToiletPass()
        return pass.answers.isEmpty() && pass.location.isBlank() && pass.photos.isEmpty() && evidenceCount(pass.evidence) == 0
    }

    private fun restoreLastToiletPass() {
        val last = state.completedToiletPasses.lastOrNull() ?: return
        state = state.copy(
            completedToiletPasses = state.completedToiletPasses.dropLast(1),
            toiletAnswers = last.answers,
            toiletLocationNote = last.location,
            toiletPhotos = last.photos,
            toiletEvidence = last.evidence,
        )
        val index = steps().indexOf(ContributeStep.ToiletAnother)
        clampIndex(if (index >= 0) index else state.stepIndex)
    }
}

private fun clearEvidence(
    photos: Map<String, List<LocalReviewPhoto>>,
    question: String,
    answer: String,
): Map<String, List<LocalReviewPhoto>> =
    if (ContributeCodes.isNotSure(answer)) photos else photos - question

private fun evidenceList(photos: Map<String, List<LocalReviewPhoto>>, question: String): List<LocalReviewPhoto> =
    photos[question] ?: emptyList()

private fun evidenceCount(photos: Map<String, List<LocalReviewPhoto>>): Int = photos.values.sumOf { it.size }

/** Where the photo on the current screen is stored. Evidence is capped across the whole pass. */
sealed class PhotoTarget {
    data object EntranceSection : PhotoTarget()
    data class EntranceEvidence(val location: EntranceLocation, val question: String) : PhotoTarget()
    data object ElevatorSection : PhotoTarget()
    data class ElevatorEvidence(val question: String) : PhotoTarget()
    data object ToiletSection : PhotoTarget()
    data class ToiletEvidence(val question: String) : PhotoTarget()
    data object PathwaySection : PhotoTarget()
    data object SeatingSection : PhotoTarget()
    data object ParkingSection : PhotoTarget()
}

fun newPhotoFileId(): String = buildString {
    repeat(32) { append(Random.nextInt(16).toString(16)) }
}
