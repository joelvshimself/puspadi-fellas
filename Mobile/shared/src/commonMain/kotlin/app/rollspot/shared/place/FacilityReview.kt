package app.rollspot.shared.place

import app.rollspot.shared.api.PlaceReview
import app.rollspot.shared.api.PlaceReviewEntrance

/** The facilities a place page breaks reviews down by. */
enum class FacilityKind { ENTRANCE, ELEVATOR, TOILET }

/** Tag the mapper emits when reviewers say a facility doesn't exist at the place. */
const val TAG_NOT_AVAILABLE = "NOT AVAILABLE"

/**
 * One review's verdict on ONE facility. A stored review covers up to three facilities
 * (and several entrances), so the API's [PlaceReview] fans out into several of these.
 */
data class FacilityReview(
    /** Stable per (review, facility): `<reviewId>:<facility>`. */
    val id: String,
    val reviewId: String,
    val kind: FacilityKind,
    /** ISO-8601 UTC as the API sends it. Fixed-width, so string order is time order. */
    val createdAt: String,
    /** What the contributor typed. EMPTY when they typed nothing; never a placeholder. */
    val bodyText: String,
    /** Upper-cased answers like "RAMP" or "AUTOMATIC DOORS", plus [TAG_NOT_AVAILABLE]. */
    val providedTags: List<String>,
    val photoUrls: List<String>,
    /** Parallel to [photoUrls]. */
    val photoCaptions: List<String>,
    val reviewerName: String?,
    val reviewerRole: String?,
    val reviewerAvatarUrl: String?,
    /** True when [reviewerName] is a handle rather than a person's real name. */
    val reviewerIsPseudonym: Boolean,
) {
    val hasBodyText: Boolean get() = bodyText.isNotBlank()

    /** Opening sentence of [bodyText], for the "Notes from reviews" snippets. */
    val firstSentence: String get() = firstSentenceOf(bodyText)

    /** "12 Aug 2026". Empty when [createdAt] isn't a date. */
    val dateLabel: String get() = dateLabelOf(createdAt)
}

/**
 * Fans each stored review out into one [FacilityReview] per facility it says something
 * about, then keeps one verdict per person per facility (their newest). Newest first.
 */
fun mapPlaceReviews(rows: List<PlaceReview>): List<FacilityReview> {
    val results = mutableListOf<Pair<String?, FacilityReview>>()
    for (row in rows) {
        fun review(
            facility: String,
            kind: FacilityKind,
            body: String,
            tags: List<String>,
            photoUrls: List<String>,
            photoCaptions: List<String>,
        ) = FacilityReview(
            id = "${row.id}:$facility",
            reviewId = row.id,
            kind = kind,
            createdAt = row.createdAt,
            bodyText = body,
            providedTags = tags,
            photoUrls = photoUrls,
            photoCaptions = photoCaptions,
            reviewerName = row.reviewerName,
            reviewerRole = row.reviewerRole,
            reviewerAvatarUrl = row.reviewerAvatarUrl,
            reviewerIsPseudonym = row.reviewerIsPseudonym,
        )

        for (entrance in row.reviewEntrances) {
            // The entrance's OWN text only. `notes` is every facility's text joined with
            // internal prefixes; falling back to it rendered a phantom row for the
            // entrance nobody reviewed.
            val body = entrance.reviewText?.trim().orEmpty()
            val hasFacilityData = entrance.hasDropoffRamp != null || entrance.hasRails != null ||
                entrance.doorType != null || entrance.isWideEnough != null
            if (body.isEmpty() && entrance.photoUrls.isEmpty() && !hasFacilityData) continue
            // Per entrance, not per review: one review can cover the lobby and the basement,
            // and those are two different doors.
            val facility = "entrance-${entrance.location}"
            results += dedupeKey(row, facility) to review(
                facility, FacilityKind.ENTRANCE, body, entranceTags(entrance),
                entrance.photoUrls, entrance.photoCaptions,
            )
        }

        if (row.elevatorExists != null || row.elevatorWheelchairAccessible != null ||
            !row.elevatorReviewText.isNullOrEmpty() || row.elevatorPhotoUrls.isNotEmpty()
        ) {
            results += dedupeKey(row, "elevator") to review(
                "elevator", FacilityKind.ELEVATOR, row.elevatorReviewText?.trim().orEmpty(),
                elevatorTags(row), row.elevatorPhotoUrls, row.elevatorPhotoCaptions,
            )
        }

        if (row.hasDisabledToilet == false) {
            results += dedupeKey(row, "toilet") to review(
                "toilet", FacilityKind.TOILET, row.toiletReviewText?.trim().orEmpty(),
                listOf(TAG_NOT_AVAILABLE), row.toiletPhotoUrls, row.toiletPhotoCaptions,
            )
        } else if (row.hasDisabledToilet == true || !row.toiletReviewText.isNullOrEmpty() || row.toiletPhotoUrls.isNotEmpty()) {
            results += dedupeKey(row, "toilet") to review(
                "toilet", FacilityKind.TOILET, row.toiletReviewText?.trim().orEmpty(),
                toiletTags(row), row.toiletPhotoUrls, row.toiletPhotoCaptions,
            )
        }
    }

    // Keep rows that carry photos even with no prose or tags: photo-only uploads still
    // belong in the Reviews list.
    return collapseRepeatVisits(results.filter { (_, r) -> r.hasBodyText || r.providedTags.isNotEmpty() || r.photoUrls.isNotEmpty() })
}

/**
 * "This person's verdict on this facility". Null when the row has no reviewer (pre-auth
 * rows), which can't be attributed to anyone and so are never collapsed together.
 */
private fun dedupeKey(row: PlaceReview, facility: String): String? {
    val reviewer = row.reviewerName?.trim()
    return if (reviewer.isNullOrEmpty()) null else "$reviewer|$facility"
}

/**
 * One verdict per person per facility, keeping their most recent. Somebody who reviews the
 * same mall five times is not five reviewers. Per FACILITY, not per review, so a later visit
 * covering only the toilet doesn't erase what they said about the entrance earlier.
 */
private fun collapseRepeatVisits(entries: List<Pair<String?, FacilityReview>>): List<FacilityReview> {
    val seen = mutableSetOf<String>()
    val kept = mutableListOf<FacilityReview>()
    for ((key, review) in entries.sortedWith { a, b -> newestFirst.compare(a.second, b.second) }) {
        if (key != null && !seen.add(key)) continue
        kept += review
    }
    return kept.sortedWith(newestFirst)
}

/** Newest first. One submit fans out into cards sharing a timestamp; the last wizard step goes first. */
val newestFirst: Comparator<FacilityReview> = Comparator { a, b ->
    when {
        a.createdAt != b.createdAt -> b.createdAt.compareTo(a.createdAt)
        a.reviewId == b.reviewId -> listRank(a.kind).compareTo(listRank(b.kind))
        else -> b.id.compareTo(a.id)
    }
}

private fun listRank(kind: FacilityKind) = when (kind) {
    FacilityKind.TOILET -> 0
    FacilityKind.ELEVATOR -> 1
    FacilityKind.ENTRANCE -> 2
}

private fun entranceTags(entrance: PlaceReviewEntrance): List<String> = buildList {
    if (entrance.hasDropoffRamp == true) add("RAMP")
    if (entrance.hasRails == true) add("HANDRAIL")
    if (entrance.doorType == "automatic") add("AUTOMATIC DOORS")
    if (entrance.doorType == "manual") add("MANUAL DOORS")
    if (entrance.isWideEnough == true) add("WIDE ENTRANCE")
}

private fun elevatorTags(row: PlaceReview): List<String> {
    if (row.elevatorExists == false) return listOf(TAG_NOT_AVAILABLE)
    return buildList {
        if (row.elevatorWheelchairAccessible == true) add("WHEELCHAIR ACCESSIBLE")
        if (row.elevatorWheelchairAccessible == false) add("LIMITED ACCESS")
        if ("no_ramp" in row.elevatorBlockers) add("NO RAMP")
        if ("too_small" in row.elevatorBlockers) add("TOO SMALL")
        if (isEmpty() && row.elevatorExists == true) add("ELEVATOR")
    }
}

private fun toiletTags(row: PlaceReview): List<String> =
    if (row.hasDisabledToilet == true) listOf("ACCESSIBLE TOILET") else emptyList()

internal fun firstSentenceOf(text: String): String {
    val trimmed = text.trim()
    val end = trimmed.indexOfFirst { it == '.' || it == '!' || it == '?' }
    return if (end >= 0) trimmed.substring(0, end + 1).trim() else trimmed
}

private val MONTHS = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

internal fun dateLabelOf(iso: String): String {
    // "2026-08-12T21:51:39.123Z" -> "12 Aug 2026"
    if (iso.length < 10 || iso[4] != '-' || iso[7] != '-') return ""
    val year = iso.substring(0, 4).toIntOrNull() ?: return ""
    val month = iso.substring(5, 7).toIntOrNull()?.takeIf { it in 1..12 } ?: return ""
    val day = iso.substring(8, 10).toIntOrNull() ?: return ""
    return "$day ${MONTHS[month - 1]} $year"
}
