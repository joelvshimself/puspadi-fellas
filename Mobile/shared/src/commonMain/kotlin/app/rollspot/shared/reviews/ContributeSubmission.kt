package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionAnswerArea
import app.rollspot.shared.api.ContributionElevator
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionEntrance
import app.rollspot.shared.api.ContributionEntrancePass
import app.rollspot.shared.api.ContributionEntrancePoint
import app.rollspot.shared.api.ContributionPathways
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.ContributionToilet
import app.rollspot.shared.api.ContributionToiletPass

/** Sections still in progress stay on the device. Only completed sections are posted. */
internal fun buildContribution(state: ContributeFlowState): ContributionSubmission {
    val entrancePasses = includedEntrancePasses(state).mapNotNull { it.toWire() }
    val elevatorPasses = includedElevatorPasses(state).mapNotNull { it.toWire() }
    val toiletPasses = includedToiletPasses(state).mapNotNull { it.toWire() }
    val pathways = pathwaysWire(state)
    val seating = answerArea(state, ContributeReviewCategory.Seating, state.seatingAnswer, state.seatingPhotos)
    val parking = answerArea(state, ContributeReviewCategory.Parking, state.parkingAnswer, state.parkingPhotos)
    return ContributionSubmission(
        submissionId = state.submissionId,
        placeId = state.placeId,
        persona = if (state.persona == ContributePersona.Wheelchair) "wheelchair" else "secondary",
        entrance = entrancePasses.takeIf { it.isNotEmpty() }?.let {
            ContributionEntrance(it, categoryNote(state, ContributeReviewCategory.Entrance))
        },
        elevator = elevatorPasses.takeIf { it.isNotEmpty() }?.let {
            ContributionElevator(it, categoryNote(state, ContributeReviewCategory.Elevator))
        },
        toilet = toiletPasses.takeIf { it.isNotEmpty() }?.let {
            ContributionToilet(it, categoryNote(state, ContributeReviewCategory.Toilet))
        },
        pathways = pathways,
        seating = seating,
        parking = parking,
    )
}

private fun categoryNote(state: ContributeFlowState, category: ContributeReviewCategory): String? =
    state.supplementalNotes[category]?.text?.trim()?.ifBlank { null }

internal fun pendingContributionPhotos(state: ContributeFlowState): List<PendingContributionPhoto> {
    val byId = localPhotos(state).associateBy { it.fileId }
    return buildContribution(state).localFileIds().mapNotNull { fileId ->
        byId[fileId]?.let { PendingContributionPhoto(it.fileId, it.jpeg, it.caption) }
    }
}

private fun includedEntrancePasses(state: ContributeFlowState): List<EntrancePass> {
    val current = EntrancePass(
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
    val includeCurrent = state.sectionStatus[ContributeReviewCategory.Entrance] == CategorySectionStatus.Complete &&
        (current.locations.isNotEmpty() || current.photos.isNotEmpty())
    return state.completedEntrancePasses + if (includeCurrent) listOf(current) else emptyList()
}

private fun includedElevatorPasses(state: ContributeFlowState): List<ElevatorPass> {
    val current = ElevatorPass(state.elevatorAnswers, state.elevatorPhotos, state.elevatorLocation, state.elevatorEvidence)
    val includeCurrent = state.sectionStatus[ContributeReviewCategory.Elevator] == CategorySectionStatus.Complete &&
        (current.answers.isNotEmpty() || current.photos.isNotEmpty() || current.location.isNotBlank())
    return state.completedElevatorPasses + if (includeCurrent) listOf(current) else emptyList()
}

private fun includedToiletPasses(state: ContributeFlowState): List<ToiletPass> {
    val current = ToiletPass(state.toiletAnswers, state.toiletLocationNote, state.toiletPhotos, state.toiletEvidence)
    val includeCurrent = state.sectionStatus[ContributeReviewCategory.Toilet] == CategorySectionStatus.Complete &&
        (current.answers.isNotEmpty() || current.location.isNotBlank() || current.photos.isNotEmpty())
    return state.completedToiletPasses + if (includeCurrent) listOf(current) else emptyList()
}

private fun EntrancePass.toWire(): ContributionEntrancePass? {
    val points = EntranceLocation.entries.mapNotNull { location ->
        if (location !in locations) return@mapNotNull null
        val tags = when (location) {
            EntranceLocation.Lobby -> lobbyTags
            EntranceLocation.Basement -> basementTags
        }.mapNotNull(ContributeCodes::tag)
        if (tags.isEmpty()) return@mapNotNull null
        val rampLabel = when (location) {
            EntranceLocation.Lobby -> lobbyRampAnswer
            EntranceLocation.Basement -> basementRampAnswer
        }
        val handrailLabel = when (location) {
            EntranceLocation.Lobby -> lobbyHandrailAnswer
            EntranceLocation.Basement -> basementHandrailAnswer
        }
        val ramp = if (ContributeCodes.RAMP in tags) rampLabel?.let(ContributeCodes::ramp) else null
        val handrail = if (ContributeCodes.HANDRAIL in tags) handrailLabel?.let(ContributeCodes::handrail) else null
        if (ContributeCodes.RAMP in tags && ramp == null) return@mapNotNull null
        if (ContributeCodes.HANDRAIL in tags && handrail == null) return@mapNotNull null
        val evidence = when (location) {
            EntranceLocation.Lobby -> lobbyEvidence
            EntranceLocation.Basement -> basementEvidence
        }
        ContributionEntrancePoint(
            location = location.name.lowercase(),
            tags = tags,
            ramp = ramp,
            handrail = handrail,
            evidence = wireEvidence(
                evidence.filterKeys { question ->
                    (question == ContributeCodes.RAMP && ramp == "not_sure") ||
                        (question == ContributeCodes.HANDRAIL && handrail == "not_sure")
                },
            ),
        )
    }
    if (points.isEmpty()) return null
    return ContributionEntrancePass(photos = photos.map { it.toWire() }, points = points)
}

private fun ElevatorPass.toWire(): ContributionElevatorPass? {
    val wide = answers[ElevatorQuestion.WideEntrance]?.let(ContributeCodes::tri) ?: return null
    val skipped = wide == "no"
    val space = if (skipped) null else answers[ElevatorQuestion.SpaceToManeuver]?.let(ContributeCodes::tri)
    val buttons = if (skipped) null else answers[ElevatorQuestion.ReachableButtons]?.let(ContributeCodes::tri)
    if (!skipped && (space == null || buttons == null)) return null
    return ContributionElevatorPass(
        photos = photos.map { it.toWire() },
        wideEntrance = wide,
        spaceToManeuver = space,
        reachableButtons = buttons,
        location = location.trim().ifBlank { null },
        evidence = wireEvidence(
            evidence.filterKeys { question ->
                (question == ContributeCodes.WIDE_ENTRANCE && wide == "not_sure") ||
                    (question == ContributeCodes.SPACE && space == "not_sure") ||
                    (question == ContributeCodes.BUTTONS && buttons == "not_sure")
            },
        ),
    )
}

private fun ToiletPass.toWire(): ContributionToiletPass? {
    val door = answers[ToiletSurveyQuestion.DoorKind]?.let(ContributeCodes::door) ?: return null
    val seat = answers[ToiletSurveyQuestion.Seat]?.let(ContributeCodes::seat) ?: return null
    val grabBars = answers[ToiletSurveyQuestion.GrabBars]?.let(ContributeCodes::grabBars) ?: return null
    val space = answers[ToiletSurveyQuestion.Space]?.let(ContributeCodes::tri) ?: return null
    val sink = answers[ToiletSurveyQuestion.Sink]?.let(ContributeCodes::tri) ?: return null
    val emergency = answers[ToiletSurveyQuestion.Emergency]?.let(ContributeCodes::emergency) ?: return null
    return ContributionToiletPass(
        photos = photos.map { it.toWire() },
        door = door,
        seat = seat,
        grabBars = grabBars,
        space = space,
        sink = sink,
        emergency = emergency,
        location = location.trim().ifBlank { null },
        evidence = wireEvidence(
            evidence.filterKeys { question ->
                (question == ContributeCodes.SEAT && seat == "not_sure") ||
                    (question == ContributeCodes.GRAB_BARS && grabBars == "not_sure") ||
                    (question == ContributeCodes.TOILET_SPACE && space == "not_sure") ||
                    (question == ContributeCodes.SINK && sink == "not_sure") ||
                    (question == ContributeCodes.EMERGENCY && emergency == "not_sure")
            },
        ),
    )
}

private fun localPhotos(state: ContributeFlowState): List<LocalReviewPhoto> =
    state.completedEntrancePasses.flatMap { it.photos + it.lobbyEvidence.values.flatten() + it.basementEvidence.values.flatten() } +
        state.entrancePhotos + state.lobbyEvidence.values.flatten() + state.basementEvidence.values.flatten() +
        state.completedElevatorPasses.flatMap { it.photos + it.evidence.values.flatten() } +
        state.elevatorPhotos + state.elevatorEvidence.values.flatten() +
        state.completedToiletPasses.flatMap { it.photos + it.evidence.values.flatten() } +
        state.toiletPhotos + state.toiletEvidence.values.flatten() +
        state.supplementalNotes.values.flatMap { it.photos } +
        state.seatingPhotos + state.parkingPhotos

private fun ContributionSubmission.localFileIds(): List<String> {
    fun ids(photos: List<ContributionPhoto>) = photos.mapNotNull { photo ->
        photo.url.takeIf { it.startsWith("local:") }?.removePrefix("local:")
    }
    fun maps(evidence: Map<String, List<ContributionPhoto>>) = evidence.values.flatMap(::ids)
    return buildList {
        entrance?.passes?.forEach { pass ->
            addAll(ids(pass.photos))
            pass.points.forEach { addAll(maps(it.evidence)) }
        }
        elevator?.passes?.forEach { pass ->
            addAll(ids(pass.photos))
            addAll(maps(pass.evidence))
        }
        toilet?.passes?.forEach { pass ->
            addAll(ids(pass.photos))
            addAll(maps(pass.evidence))
        }
        addAll(ids(pathways?.photos.orEmpty()))
        addAll(ids(seating?.photos.orEmpty()))
        addAll(ids(parking?.photos.orEmpty()))
    }
}

private fun pathwaysWire(state: ContributeFlowState): ContributionPathways? {
    if (state.sectionStatus[ContributeReviewCategory.OutdoorPathways] != CategorySectionStatus.Complete) return null
    val notices = ContributeCatalog.pathwayNoticeOptions.mapNotNull { label ->
        if (label in state.pathwayNotices) ContributeCodes.notice(label) else null
    }
    if (notices.isEmpty()) return null
    val photos = state.supplementalNotes[ContributeReviewCategory.OutdoorPathways]?.photos.orEmpty()
    return ContributionPathways(
        photos.map { it.toWire() },
        notices,
        categoryNote(state, ContributeReviewCategory.OutdoorPathways),
    )
}

private fun answerArea(
    state: ContributeFlowState,
    category: ContributeReviewCategory,
    answer: String?,
    photos: List<LocalReviewPhoto>,
): ContributionAnswerArea? {
    if (state.sectionStatus[category] != CategorySectionStatus.Complete) return null
    val code = answer?.let(ContributeCodes::tri) ?: return null
    return ContributionAnswerArea(photos.map { it.toWire() }, code, categoryNote(state, category))
}

private fun wireEvidence(photos: Map<String, List<LocalReviewPhoto>>): Map<String, List<ContributionPhoto>> =
    photos.mapNotNull { (question, list) ->
        if (list.isEmpty()) null else question to list.map { it.toWire() }
    }.toMap()

private fun LocalReviewPhoto.toWire(): ContributionPhoto =
    ContributionPhoto(url = "local:$fileId", caption = caption)

/** iOS builds one of these from its screen state and posts [build]. */
class ContributionBuilder(
    private val placeId: String,
    private val submissionId: String,
) {
    private var persona = ContributePersona.Secondary
    private val entrances = mutableListOf<EntrancePass>()
    private val elevators = mutableListOf<ElevatorPass>()
    private val toilets = mutableListOf<ToiletPass>()
    private var pathwayNotices = emptySet<String>()
    private var pathwayPhotos = emptyList<LocalReviewPhoto>()
    private var includePathways = false
    private var seatingAnswer: String? = null
    private var seatingPhotos = emptyList<LocalReviewPhoto>()
    private var includeSeating = false
    private var parkingAnswer: String? = null
    private var parkingPhotos = emptyList<LocalReviewPhoto>()
    private var includeParking = false
    private val categoryNotes = mutableMapOf<ContributeReviewCategory, String>()

    fun setPersona(wheelchair: Boolean) {
        persona = if (wheelchair) ContributePersona.Wheelchair else ContributePersona.Secondary
    }

    fun addEntrancePass(
        photos: List<LocalReviewPhoto>,
        lobby: Boolean,
        basement: Boolean,
        lobbyTags: List<String>,
        basementTags: List<String>,
        lobbyRamp: String?,
        basementRamp: String?,
        lobbyHandrail: String?,
        basementHandrail: String?,
        lobbyRampPhotos: List<LocalReviewPhoto>,
        lobbyHandrailPhotos: List<LocalReviewPhoto>,
        basementRampPhotos: List<LocalReviewPhoto>,
        basementHandrailPhotos: List<LocalReviewPhoto>,
    ) {
        val locations = buildSet {
            if (lobby) add(EntranceLocation.Lobby)
            if (basement) add(EntranceLocation.Basement)
        }
        entrances += EntrancePass(
            photos = photos,
            locations = locations,
            lobbyTags = lobbyTags.toSet(),
            basementTags = basementTags.toSet(),
            lobbyRampAnswer = lobbyRamp,
            basementRampAnswer = basementRamp,
            lobbyHandrailAnswer = lobbyHandrail,
            basementHandrailAnswer = basementHandrail,
            lobbyEvidence = evidence(ContributeCodes.RAMP to lobbyRampPhotos, ContributeCodes.HANDRAIL to lobbyHandrailPhotos),
            basementEvidence = evidence(ContributeCodes.RAMP to basementRampPhotos, ContributeCodes.HANDRAIL to basementHandrailPhotos),
        )
    }

    fun addElevatorPass(
        answers: Map<String, String>,
        photos: List<LocalReviewPhoto>,
        location: String,
        widePhotos: List<LocalReviewPhoto>,
        spacePhotos: List<LocalReviewPhoto>,
        buttonPhotos: List<LocalReviewPhoto>,
    ) {
        val mapped = answers.mapNotNull { (key, value) ->
            val question = when (key) {
                "wideEntrance" -> ElevatorQuestion.WideEntrance
                "spaceToManeuver" -> ElevatorQuestion.SpaceToManeuver
                "reachableButtons" -> ElevatorQuestion.ReachableButtons
                else -> null
            }
            question?.let { it to value }
        }.toMap()
        elevators += ElevatorPass(
            answers = mapped,
            photos = photos,
            location = location,
            evidence = evidence(
                ContributeCodes.WIDE_ENTRANCE to widePhotos,
                ContributeCodes.SPACE to spacePhotos,
                ContributeCodes.BUTTONS to buttonPhotos,
            ),
        )
    }

    fun addToiletPass(
        answers: Map<String, String>,
        photos: List<LocalReviewPhoto>,
        location: String,
        seatPhotos: List<LocalReviewPhoto>,
        grabPhotos: List<LocalReviewPhoto>,
        spacePhotos: List<LocalReviewPhoto>,
        sinkPhotos: List<LocalReviewPhoto>,
        emergencyPhotos: List<LocalReviewPhoto>,
    ) {
        val mapped = answers.mapNotNull { (key, value) ->
            val question = when (key) {
                "doorKind" -> ToiletSurveyQuestion.DoorKind
                "seat" -> ToiletSurveyQuestion.Seat
                "grabBars" -> ToiletSurveyQuestion.GrabBars
                "space" -> ToiletSurveyQuestion.Space
                "sink" -> ToiletSurveyQuestion.Sink
                "emergency" -> ToiletSurveyQuestion.Emergency
                else -> null
            }
            question?.let { it to value }
        }.toMap()
        toilets += ToiletPass(
            answers = mapped,
            photos = photos,
            location = location,
            evidence = evidence(
                ContributeCodes.SEAT to seatPhotos,
                ContributeCodes.GRAB_BARS to grabPhotos,
                ContributeCodes.TOILET_SPACE to spacePhotos,
                ContributeCodes.SINK to sinkPhotos,
                ContributeCodes.EMERGENCY to emergencyPhotos,
            ),
        )
    }

    fun setPathways(notices: List<String>, photos: List<LocalReviewPhoto>) {
        includePathways = true
        pathwayNotices = notices.toSet()
        pathwayPhotos = photos
    }

    fun setSeating(answer: String, photos: List<LocalReviewPhoto>) {
        includeSeating = true
        seatingAnswer = answer
        seatingPhotos = photos
    }

    fun setParking(answer: String, photos: List<LocalReviewPhoto>) {
        includeParking = true
        parkingAnswer = answer
        parkingPhotos = photos
    }

    fun setCategoryNote(category: ContributeReviewCategory, text: String) {
        categoryNotes[category] = text
    }

    fun build(): AssembledContribution {
        val status = buildMap {
            if (entrances.isNotEmpty()) put(ContributeReviewCategory.Entrance, CategorySectionStatus.Complete)
            if (elevators.isNotEmpty()) put(ContributeReviewCategory.Elevator, CategorySectionStatus.Complete)
            if (toilets.isNotEmpty()) put(ContributeReviewCategory.Toilet, CategorySectionStatus.Complete)
            if (includePathways) put(ContributeReviewCategory.OutdoorPathways, CategorySectionStatus.Complete)
            if (includeSeating) put(ContributeReviewCategory.Seating, CategorySectionStatus.Complete)
            if (includeParking) put(ContributeReviewCategory.Parking, CategorySectionStatus.Complete)
        }
        val state = ContributeFlowState(
            placeId = placeId,
            placeName = "",
            submissionId = submissionId,
            persona = persona,
            sectionStatus = status,
            completedEntrancePasses = entrances,
            completedElevatorPasses = elevators,
            completedToiletPasses = toilets,
            supplementalNotes = categoryNotesMap(),
            pathwayNotices = pathwayNotices,
            seatingAnswer = seatingAnswer,
            seatingPhotos = seatingPhotos,
            parkingAnswer = parkingAnswer,
            parkingPhotos = parkingPhotos,
        )
        return AssembledContribution(buildContribution(state), pendingContributionPhotos(state))
    }

    private fun categoryNotesMap(): Map<ContributeReviewCategory, FacilityNotes> {
        val notes = mutableMapOf<ContributeReviewCategory, FacilityNotes>()
        val pathwayText = categoryNotes[ContributeReviewCategory.OutdoorPathways].orEmpty()
        if (pathwayPhotos.isNotEmpty() || pathwayText.isNotBlank()) {
            notes[ContributeReviewCategory.OutdoorPathways] = FacilityNotes(pathwayText, pathwayPhotos)
        }
        for ((category, text) in categoryNotes) {
            if (category == ContributeReviewCategory.OutdoorPathways || text.isBlank()) continue
            notes[category] = FacilityNotes(text)
        }
        return notes
    }
}

data class AssembledContribution(
    val submission: ContributionSubmission,
    val photos: List<PendingContributionPhoto>,
)

private fun evidence(vararg groups: Pair<String, List<LocalReviewPhoto>>): Map<String, List<LocalReviewPhoto>> =
    groups.mapNotNull { (question, photos) -> if (photos.isEmpty()) null else question to photos }.toMap()
