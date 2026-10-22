package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionAnswerArea
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionEntrancePoint
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.ContributionToiletPass
import app.rollspot.shared.api.ReviewSubmitted
import app.rollspot.shared.api.RollspotApi
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/** One choice in a row's menu: [id] is the wire value, [label] what the menu shows. */
data class EditOption(val id: String, val label: String)

/**
 * One answer on the Edit Response page. A choice row shows [value] and opens a menu of [options];
 * a text row ([options] empty) edits [text] in place. [group] is set when one section holds two
 * entrance locations, so views can show "Lobby" / "Basement" above their rows.
 */
data class EditRow(
    val id: String,
    val label: String,
    val options: List<EditOption> = emptyList(),
    val selected: String? = null,
    val text: String = "",
    val placeholder: String = "",
    val group: String? = null,
) {
    val isText: Boolean get() = options.isEmpty()
    /** What the row shows on the right: the chosen option, or "Choose" when it still needs an answer. */
    val value: String get() = options.firstOrNull { it.id == selected }?.label ?: "Choose"
}

/** A photo on the page: already uploaded ([url]) or picked during this edit ([jpeg]). */
data class EditPhoto(val id: String, val url: String? = null, val jpeg: ByteArray? = null, val caption: String = "") {
    override fun equals(other: Any?): Boolean = other is EditPhoto && other.id == id && other.url == url && other.caption == caption
    override fun hashCode(): Int = id.hashCode()
}

/**
 * One block of the page ("Entrance", "Elevator", "Accessible Toilets", ...). Notes belong to the
 * whole facility, so only the last block of each facility carries [notesKey].
 */
data class EditSection(
    val id: String,
    val title: String,
    val rows: List<EditRow>,
    val photos: List<EditPhoto>,
    val canAddPhoto: Boolean,
    val notesKey: String? = null,
    val notes: String = "",
)

sealed interface ReviewEditState {
    data object Loading : ReviewEditState
    data class Failed(val message: String) : ReviewEditState
    data class Ready(
        val placeName: String,
        val sections: List<EditSection>,
        /** Something changed since loading: leaving asks "Leave editing?". */
        val isDirty: Boolean,
        val isSaving: Boolean = false,
        /** First answer that still needs fixing; save is off while set. */
        val problem: String? = null,
        val error: String? = null,
    ) : ReviewEditState {
        val canSave: Boolean get() = isDirty && !isSaving && problem == null
    }
    data class Saved(val result: ReviewSubmitted) : ReviewEditState
}

/**
 * The Edit Response page for one of the user's own reviews: every answer as a row, section photos
 * and notes, and save. Both apps render [state] and send row changes here; all rules live here.
 */
class ReviewEditModel(private val api: RollspotApi, private val reviewId: String) {
    private val _state = MutableStateFlow<ReviewEditState>(ReviewEditState.Loading)
    val state: StateFlow<ReviewEditState> = _state.asStateFlow()

    private var placeName = ""
    private var original: ContributionSubmission? = null
    private var draft: ContributionSubmission? = null
    private val localPhotos = mutableMapOf<String, ByteArray>()

    @Throws(Exception::class)
    suspend fun load() {
        _state.value = ReviewEditState.Loading
        try {
            val loaded = api.reviewForEdit(reviewId)
            placeName = loaded.placeName
            original = loaded.submission
            draft = loaded.submission
            localPhotos.clear()
            publish()
        } catch (error: Exception) {
            _state.value = ReviewEditState.Failed(error.message ?: "This review couldn't be loaded.")
        }
    }

    /** Picks [optionId] for a choice row. Related answers follow (e.g. "Nothing notable" clears the others). */
    fun choose(rowId: String, optionId: String) = change { ReviewEditRules.choose(it, rowId, optionId) }

    /** Edits a text row (an elevator or toilet location). */
    fun setText(rowId: String, text: String) = change { ReviewEditRules.setText(it, rowId, text) }

    fun setNotes(notesKey: String, text: String) = change { ReviewEditRules.setNotes(it, notesKey, text) }

    /** Adds a photo the app already compressed to JPEG. Returns false when the section is full. */
    fun addPhoto(sectionId: String, jpeg: ByteArray, caption: String = ""): Boolean {
        val current = draft ?: return false
        val section = ReviewEditRules.sections(current, localPhotos).firstOrNull { it.id == sectionId } ?: return false
        if (!section.canAddPhoto || jpeg.isEmpty()) return false
        val fileId = newPhotoFileId()
        localPhotos[fileId] = jpeg
        change { ReviewEditRules.addPhoto(it, sectionId, ContributionPhoto("$LOCAL_PREFIX$fileId", caption.trim())) }
        return true
    }

    fun removePhoto(sectionId: String, photoId: String) {
        localPhotos.remove(photoId.removePrefix(LOCAL_PREFIX))
        change { ReviewEditRules.removePhoto(it, sectionId, photoId) }
    }

    /** Uploads new photos, then replaces the review. On success the state becomes [ReviewEditState.Saved]. */
    @Throws(Exception::class)
    suspend fun save() {
        val ready = _state.value as? ReviewEditState.Ready ?: return
        val current = draft ?: return
        if (!ready.canSave) return
        _state.value = ready.copy(isSaving = true, error = null)
        try {
            val urls = mutableMapOf<String, String>()
            // Only photos still on the page; ones added then removed never upload.
            val used = ReviewEditRules.photoUrls(current).filter { it.startsWith(LOCAL_PREFIX) }.map { it.removePrefix(LOCAL_PREFIX) }
            for (fileId in used) {
                val jpeg = localPhotos[fileId] ?: continue
                urls[fileId] = api.uploadReviewPhoto(current.placeId, current.submissionId, fileId, jpeg)
            }
            val result = api.updateContribution(reviewId, current.withUploadedPhotos(urls))
            _state.value = ReviewEditState.Saved(result)
        } catch (error: Exception) {
            _state.value = ready.copy(isSaving = false, error = error.message ?: "Your changes couldn't be saved.")
            throw error
        }
    }

    private fun change(transform: (ContributionSubmission) -> ContributionSubmission) {
        val current = draft ?: return
        if ((_state.value as? ReviewEditState.Ready)?.isSaving == true) return
        draft = transform(current)
        publish()
    }

    private fun publish() {
        val current = draft ?: return
        val previous = _state.value as? ReviewEditState.Ready
        _state.value = ReviewEditState.Ready(
            placeName = placeName,
            sections = ReviewEditRules.sections(current, localPhotos),
            isDirty = current != original,
            problem = ReviewEditRules.problem(current),
            error = previous?.error,
        )
    }

    companion object {
        internal const val LOCAL_PREFIX = "local:"
    }
}

/** Pure rules behind [ReviewEditModel]: rows from a v2 body, and changes back into it. */
internal object ReviewEditRules {
    private val yesNo = listOf(EditOption("yes", "Yes"), EditOption("no", "No"))
    private val tri = listOf(EditOption("yes", "Yes"), EditOption("no", "No"), EditOption("not_sure", "Not sure"))
    private val rampOptions = listOf(
        EditOption("yes", "Easy"), EditOption("with_push", "With a push"), EditOption("too_steep", "Steep"),
        EditOption("not_sure", "Not sure"), EditOption(NONE, "No ramp"),
    )
    private val handrailOptions = listOf(
        EditOption("yes", "Good reach and grip"), EditOption("with_effort", "With effort"), EditOption("no", "Hard to use"),
        EditOption("not_sure", "Not sure"), EditOption(NONE, "No handrail"),
    )
    private val doorOptions = listOf(EditOption("manual", "Manual"), EditOption("sliding", "Sliding"), EditOption("automatic", "Automatic"))
    private val seatOptions = listOf(
        EditOption("yes", "Easy height"), EditOption("too_low", "Too low"), EditOption("too_high", "Too high"), EditOption("not_sure", "Not sure"),
    )
    private val grabOptions = listOf(
        EditOption("yes", "Reachable"), EditOption("awkward", "Awkward"), EditOption("no", "No"), EditOption("not_sure", "Not sure"),
    )
    private val emergencyOptions = listOf(
        EditOption("yes", "Reachable"), EditOption("no", "Hard to reach"), EditOption("not_sure", "Not sure"), EditOption("none", "None"),
    )

    /** Tag rows after Ramp/Handrail, in the design's order. */
    private val lobbyTags = listOf(
        "automatic_doors" to "Automatic door", "manual_doors" to "Manual door",
        "security_assistance" to "Security assistance", "wheelchairs_available" to "Wheelchairs available",
    )
    private val basementTags = listOf(
        "elevator" to "Elevator", "disabled_parking" to "Disabled parking", "security_assistance" to "Security assistance",
    )
    private val tagOrder = listOf(
        "ramp", "handrail", "automatic_doors", "manual_doors", "security_assistance", "wheelchairs_available", "elevator", "disabled_parking",
    )
    val notices = listOf(
        "loose_surface" to "Loose gravel or sand",
        "rough_surface" to "Rough or uneven surface",
        "tight_gap" to "Tight gap",
        "narrow_path" to "Narrow pathway",
        "steep_section" to "Steep section",
        "curb_no_ramp" to "Curb or step with no ramp",
        NOTHING_NOTABLE to "Nothing notable",
    )

    const val NONE = "none"
    const val NOTHING_NOTABLE = "nothing_notable"

    fun sections(s: ContributionSubmission, local: Map<String, ByteArray>): List<EditSection> {
        val out = mutableListOf<EditSection>()
        fun photos(list: List<ContributionPhoto>) = list.map { photo ->
            val fileId = photo.url.removePrefix(ReviewEditModel.LOCAL_PREFIX)
            if (photo.url.startsWith(ReviewEditModel.LOCAL_PREFIX)) EditPhoto(photo.url, jpeg = local[fileId], caption = photo.caption)
            else EditPhoto(photo.url, url = photo.url, caption = photo.caption)
        }
        val room = photoUrls(s).size < MAX_PHOTOS
        fun numbered(title: String, index: Int, count: Int) = if (count > 1) "$title ${index + 1}" else title

        s.entrance?.passes?.forEachIndexed { p, pass ->
            val grouped = pass.points.size > 1
            val rows = pass.points.flatMap { point ->
                val location = point.location
                val group = if (grouped) location.replaceFirstChar { it.uppercase() } else null
                val base = "entrance/$p/$location"
                val tagRows = (if (location == "lobby") lobbyTags else basementTags).map { (tag, label) ->
                    EditRow("$base/tag/$tag", label, yesNo, if (tag in point.tags) "yes" else "no", group = group)
                }
                val ramp = EditRow("$base/ramp", "Ramp", rampOptions, if ("ramp" in point.tags) point.ramp else NONE, group = group)
                val handrail = EditRow("$base/handrail", "Handrail", handrailOptions, if ("handrail" in point.tags) point.handrail else NONE, group = group)
                if (location == "lobby") listOf(ramp, handrail) + tagRows else tagRows.take(2) + listOf(ramp, handrail) + tagRows.drop(2)
            }
            val last = p == s.entrance.passes.lastIndex
            out += EditSection(
                "entrance/$p", numbered("Entrance", p, s.entrance.passes.size), rows, photos(pass.photos),
                room && pass.photos.size < ContributePhotoLimits.SECTION,
                if (last) "entrance" else null, if (last) s.entrance.notes.orEmpty() else "",
            )
        }
        s.elevator?.passes?.forEachIndexed { p, pass ->
            val base = "elevator/$p"
            val rows = buildList {
                add(EditRow("$base/wideEntrance", "Wide entrance", tri, pass.wideEntrance))
                if (pass.wideEntrance != "no") {
                    add(EditRow("$base/spaceToManeuver", "Space to maneuver", tri, pass.spaceToManeuver))
                    add(EditRow("$base/reachableButtons", "Reachable buttons", tri, pass.reachableButtons))
                }
                add(EditRow("$base/location", "Location", text = pass.location.orEmpty(), placeholder = "e.g. GF, next to the food court"))
            }
            val last = p == s.elevator.passes.lastIndex
            out += EditSection(
                base, numbered("Elevator", p, s.elevator.passes.size), rows, photos(pass.photos),
                room && pass.photos.size < ContributePhotoLimits.SECTION,
                if (last) "elevator" else null, if (last) s.elevator.notes.orEmpty() else "",
            )
        }
        s.toilet?.passes?.forEachIndexed { p, pass ->
            val base = "toilet/$p"
            val rows = listOf(
                EditRow("$base/door", "Door", doorOptions, pass.door),
                EditRow("$base/seat", "Toilet seat", seatOptions, pass.seat),
                EditRow("$base/grabBars", "Grab bars", grabOptions, pass.grabBars),
                EditRow("$base/space", "Space to maneuver", tri, pass.space),
                EditRow("$base/sink", "Reachable sink", tri, pass.sink),
                EditRow("$base/emergency", "Emergency aid", emergencyOptions, pass.emergency),
                EditRow("$base/location", "Location", text = pass.location.orEmpty(), placeholder = "e.g. 3rd floor, next to the cinema"),
            )
            val last = p == s.toilet.passes.lastIndex
            out += EditSection(
                base, numbered("Accessible Toilets", p, s.toilet.passes.size), rows, photos(pass.photos),
                room && pass.photos.size < ContributePhotoLimits.SECTION,
                if (last) "toilet" else null, if (last) s.toilet.notes.orEmpty() else "",
            )
        }
        s.pathways?.let { area ->
            val rows = notices.map { (code, label) -> EditRow("pathways/$code", label, yesNo, if (code in area.notices) "yes" else "no") }
            out += EditSection("pathways", "Outdoor Pathways", rows, photos(area.photos), room && area.photos.size < ContributePhotoLimits.SECTION, "pathways", area.notes.orEmpty())
        }
        s.seating?.let { area ->
            out += EditSection(
                "seating", "Seating", listOf(EditRow("seating/answer", "Wheelchair friendly seating", tri, area.answer)),
                photos(area.photos), room && area.photos.size < ContributePhotoLimits.SECTION, "seating", area.notes.orEmpty(),
            )
        }
        s.parking?.let { area ->
            out += EditSection(
                "parking", "Parking", listOf(EditRow("parking/answer", "Accessible parking", tri, area.answer)),
                photos(area.photos), room && area.photos.size < ContributePhotoLimits.SECTION, "parking", area.notes.orEmpty(),
            )
        }
        return out
    }

    /** The first thing the backend would reject, phrased for the user; null when the review can be saved. */
    fun problem(s: ContributionSubmission): String? {
        s.entrance?.passes?.forEachIndexed { p, pass ->
            pass.points.forEach { point ->
                if (point.tags.isEmpty()) return "Choose at least one feature for the ${point.location} entrance${passSuffix(p, s.entrance.passes.size)}."
            }
        }
        s.elevator?.passes?.forEachIndexed { p, pass ->
            if (pass.wideEntrance != "no" && (pass.spaceToManeuver == null || pass.reachableButtons == null)) {
                return "Answer every question for the elevator${passSuffix(p, s.elevator.passes.size)}."
            }
        }
        return null
    }

    private fun passSuffix(index: Int, count: Int) = if (count > 1) " ${index + 1}" else ""

    fun choose(s: ContributionSubmission, rowId: String, option: String): ContributionSubmission {
        val parts = rowId.split("/")
        return when (parts[0]) {
            "entrance" -> s.copy(entrance = s.entrance?.let { entrance ->
                val p = parts[1].toInt()
                entrance.copy(passes = entrance.passes.mapIndexed { index, pass ->
                    if (index != p) pass else pass.copy(points = pass.points.map { point ->
                        if (point.location != parts[2]) point else entrancePoint(point, parts.drop(3), option)
                    })
                })
            })
            "elevator" -> s.copy(elevator = s.elevator?.let { elevator ->
                val p = parts[1].toInt()
                elevator.copy(passes = elevator.passes.mapIndexed { index, pass -> if (index != p) pass else elevatorPass(pass, parts[2], option) })
            })
            "toilet" -> s.copy(toilet = s.toilet?.let { toilet ->
                val p = parts[1].toInt()
                toilet.copy(passes = toilet.passes.mapIndexed { index, pass -> if (index != p) pass else toiletPass(pass, parts[2], option) })
            })
            "pathways" -> s.copy(pathways = s.pathways?.let { it.copy(notices = pathwayNotices(it.notices, parts[1], option == "yes")) })
            "seating" -> s.copy(seating = s.seating?.answer(option))
            "parking" -> s.copy(parking = s.parking?.answer(option))
            else -> s
        }
    }

    private fun ContributionAnswerArea.answer(option: String) = copy(answer = option)

    private fun entrancePoint(point: ContributionEntrancePoint, path: List<String>, option: String): ContributionEntrancePoint {
        fun withTag(tag: String, on: Boolean): List<String> {
            val tags = if (on) point.tags + tag else point.tags - tag
            return tagOrder.filter { it in tags }
        }
        return when (path.first()) {
            "ramp" -> if (option == NONE) point.copy(tags = withTag("ramp", false), ramp = null, evidence = point.evidence - "ramp")
            else point.copy(tags = withTag("ramp", true), ramp = option, evidence = keepEvidenceIfNotSure(point.evidence, "ramp", option))
            "handrail" -> if (option == NONE) point.copy(tags = withTag("handrail", false), handrail = null, evidence = point.evidence - "handrail")
            else point.copy(tags = withTag("handrail", true), handrail = option, evidence = keepEvidenceIfNotSure(point.evidence, "handrail", option))
            "tag" -> point.copy(tags = withTag(path[1], option == "yes"))
            else -> point
        }
    }

    private fun elevatorPass(pass: ContributionElevatorPass, field: String, option: String): ContributionElevatorPass = when (field) {
        // "No" ends the elevator questions, so the follow-ups (and their photos) go.
        "wideEntrance" -> if (option == "no") {
            pass.copy(wideEntrance = option, spaceToManeuver = null, reachableButtons = null, evidence = keepEvidenceIfNotSure(pass.evidence, field, option) - "spaceToManeuver" - "reachableButtons")
        } else pass.copy(wideEntrance = option, evidence = keepEvidenceIfNotSure(pass.evidence, field, option))
        "spaceToManeuver" -> pass.copy(spaceToManeuver = option, evidence = keepEvidenceIfNotSure(pass.evidence, field, option))
        "reachableButtons" -> pass.copy(reachableButtons = option, evidence = keepEvidenceIfNotSure(pass.evidence, field, option))
        else -> pass
    }

    private fun toiletPass(pass: ContributionToiletPass, field: String, option: String): ContributionToiletPass {
        val evidence = keepEvidenceIfNotSure(pass.evidence, field, option)
        return when (field) {
            "door" -> pass.copy(door = option)
            "seat" -> pass.copy(seat = option, evidence = evidence)
            "grabBars" -> pass.copy(grabBars = option, evidence = evidence)
            "space" -> pass.copy(space = option, evidence = evidence)
            "sink" -> pass.copy(sink = option, evidence = evidence)
            "emergency" -> pass.copy(emergency = option, evidence = evidence)
            else -> pass
        }
    }

    /** "Not sure" photos only make sense while the answer is still "Not sure". */
    private fun keepEvidenceIfNotSure(evidence: Map<String, List<ContributionPhoto>>, question: String, option: String) =
        if (option == "not_sure") evidence else evidence - question

    /**
     * "Nothing notable" and the real notices exclude each other (design note on Outdoor Pathways),
     * and the section always says something: clearing the last notice means nothing notable.
     */
    fun pathwayNotices(current: List<String>, code: String, on: Boolean): List<String> {
        val next = when {
            code == NOTHING_NOTABLE && on -> listOf(NOTHING_NOTABLE)
            on -> current - NOTHING_NOTABLE + code
            else -> current - code
        }.ifEmpty { listOf(NOTHING_NOTABLE) }
        return notices.map { it.first }.filter { it in next }
    }

    fun setText(s: ContributionSubmission, rowId: String, text: String): ContributionSubmission {
        val parts = rowId.split("/")
        val value = text.take(LOCATION_MAX).ifBlank { null }
        val p = parts.getOrNull(1)?.toIntOrNull() ?: return s
        return when (parts[0]) {
            "elevator" -> s.copy(elevator = s.elevator?.let { e -> e.copy(passes = e.passes.mapIndexed { i, pass -> if (i == p) pass.copy(location = value) else pass }) })
            "toilet" -> s.copy(toilet = s.toilet?.let { t -> t.copy(passes = t.passes.mapIndexed { i, pass -> if (i == p) pass.copy(location = value) else pass }) })
            else -> s
        }
    }

    fun setNotes(s: ContributionSubmission, key: String, text: String): ContributionSubmission {
        val value = text.take(TEXT_MAX).ifBlank { null }
        return when (key) {
            "entrance" -> s.copy(entrance = s.entrance?.copy(notes = value))
            "elevator" -> s.copy(elevator = s.elevator?.copy(notes = value))
            "toilet" -> s.copy(toilet = s.toilet?.copy(notes = value))
            "pathways" -> s.copy(pathways = s.pathways?.copy(notes = value))
            "seating" -> s.copy(seating = s.seating?.copy(notes = value))
            "parking" -> s.copy(parking = s.parking?.copy(notes = value))
            else -> s
        }
    }

    fun addPhoto(s: ContributionSubmission, sectionId: String, photo: ContributionPhoto) = mapSectionPhotos(s, sectionId) { it + photo }

    fun removePhoto(s: ContributionSubmission, sectionId: String, photoId: String) = mapSectionPhotos(s, sectionId) { list -> list.filterNot { it.url == photoId } }

    private fun mapSectionPhotos(
        s: ContributionSubmission,
        sectionId: String,
        transform: (List<ContributionPhoto>) -> List<ContributionPhoto>,
    ): ContributionSubmission {
        val parts = sectionId.split("/")
        val p = parts.getOrNull(1)?.toIntOrNull()
        return when (parts[0]) {
            "entrance" -> s.copy(entrance = s.entrance?.let { e -> e.copy(passes = e.passes.mapIndexed { i, pass -> if (i == p) pass.copy(photos = transform(pass.photos)) else pass }) })
            "elevator" -> s.copy(elevator = s.elevator?.let { e -> e.copy(passes = e.passes.mapIndexed { i, pass -> if (i == p) pass.copy(photos = transform(pass.photos)) else pass }) })
            "toilet" -> s.copy(toilet = s.toilet?.let { t -> t.copy(passes = t.passes.mapIndexed { i, pass -> if (i == p) pass.copy(photos = transform(pass.photos)) else pass }) })
            "pathways" -> s.copy(pathways = s.pathways?.let { it.copy(photos = transform(it.photos)) })
            "seating" -> s.copy(seating = s.seating?.let { it.copy(photos = transform(it.photos)) })
            "parking" -> s.copy(parking = s.parking?.let { it.copy(photos = transform(it.photos)) })
            else -> s
        }
    }

    /** Every photo URL in the body (section, evidence and final), uploaded or `local:`. */
    fun photoUrls(s: ContributionSubmission): List<String> = buildList {
        fun all(list: List<ContributionPhoto>) = list.forEach { add(it.url) }
        s.entrance?.passes?.forEach { pass -> all(pass.photos); pass.points.forEach { point -> point.evidence.values.forEach(::all) } }
        s.elevator?.passes?.forEach { pass -> all(pass.photos); pass.evidence.values.forEach(::all) }
        s.toilet?.passes?.forEach { pass -> all(pass.photos); pass.evidence.values.forEach(::all) }
        s.pathways?.let { all(it.photos) }
        s.seating?.let { all(it.photos) }
        s.parking?.let { all(it.photos) }
        s.final?.let { all(it.photos) }
    }

    /** Backend limits (contribution.ts). */
    private const val MAX_PHOTOS = 60
    private const val LOCATION_MAX = 200
    private const val TEXT_MAX = 4_000
}
