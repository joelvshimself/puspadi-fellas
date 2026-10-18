package app.rollspot.shared.reviews

import app.rollspot.shared.api.ContributionAnswerArea
import app.rollspot.shared.api.ContributionElevator
import app.rollspot.shared.api.ContributionElevatorPass
import app.rollspot.shared.api.ContributionEntrance
import app.rollspot.shared.api.ContributionEntrancePass
import app.rollspot.shared.api.ContributionEntrancePoint
import app.rollspot.shared.api.ContributionFinal
import app.rollspot.shared.api.ContributionPathways
import app.rollspot.shared.api.ContributionPhoto
import app.rollspot.shared.api.ContributionSubmission
import app.rollspot.shared.api.ContributionToilet
import app.rollspot.shared.api.ContributionToiletPass
import app.rollspot.shared.api.EntranceReport
import app.rollspot.shared.api.ElevatorReport
import app.rollspot.shared.api.ReviewNote
import app.rollspot.shared.api.ReviewSubmission
import app.rollspot.shared.api.ToiletReport

internal data class SlotPhotoUrls(
    val urls: List<String> = emptyList(),
    val captions: List<String> = emptyList(),
)

internal fun ContributionSubmission.withUploadedPhotos(urls: Map<String, String>): ContributionSubmission {
    fun photos(list: List<ContributionPhoto>) = list.map { it.uploaded(urls) }
    fun evidence(map: Map<String, List<ContributionPhoto>>) = map.mapValues { (_, list) -> photos(list) }
    return copy(
        entrance = entrance?.let { section ->
            ContributionEntrance(section.passes.map { pass ->
                ContributionEntrancePass(
                    photos = photos(pass.photos),
                    points = pass.points.map { point ->
                        ContributionEntrancePoint(
                            location = point.location,
                            tags = point.tags,
                            ramp = point.ramp,
                            handrail = point.handrail,
                            evidence = evidence(point.evidence),
                        )
                    },
                )
            })
        },
        elevator = elevator?.let { section ->
            ContributionElevator(section.passes.map { pass ->
                ContributionElevatorPass(
                    photos = photos(pass.photos),
                    wideEntrance = pass.wideEntrance,
                    spaceToManeuver = pass.spaceToManeuver,
                    reachableButtons = pass.reachableButtons,
                    location = pass.location,
                    evidence = evidence(pass.evidence),
                )
            })
        },
        toilet = toilet?.let { section ->
            ContributionToilet(section.passes.map { pass ->
                ContributionToiletPass(
                    photos = photos(pass.photos),
                    door = pass.door,
                    seat = pass.seat,
                    grabBars = pass.grabBars,
                    space = pass.space,
                    sink = pass.sink,
                    emergency = pass.emergency,
                    location = pass.location,
                    evidence = evidence(pass.evidence),
                )
            })
        },
        pathways = pathways?.let { ContributionPathways(photos(it.photos), it.notices) },
        seating = seating?.let { ContributionAnswerArea(photos(it.photos), it.answer) },
        parking = parking?.let { ContributionAnswerArea(photos(it.photos), it.answer) },
        final = final?.let { ContributionFinal(it.text, photos(it.photos)) },
    )
}

private fun ContributionPhoto.uploaded(urls: Map<String, String>): ContributionPhoto {
    val fileId = url.removePrefix("local:")
    val remote = if (url.startsWith("local:")) urls[fileId] else null
    return if (remote == null) this else copy(url = remote)
}

internal fun ReviewSubmission.withUploadedPhotos(bySlot: Map<ReviewPhotoSlot, SlotPhotoUrls>): ReviewSubmission {
    if (bySlot.isEmpty()) return this
    return ReviewSubmission(
        submissionId = submissionId,
        placeId = placeId,
        entrances = entrances?.map { entrance ->
            val slot = when (entrance.location) {
                "lobby" -> ReviewPhotoSlot.Lobby
                "basement" -> ReviewPhotoSlot.Basement
                else -> null
            }
            val photos = slot?.let { bySlot[it] }
            if (photos == null || (photos.urls.isEmpty() && entrance.review?.text == null)) {
                entrance
            } else {
                entrance.copy(review = mergeNote(entrance.review, photos))
            }
        },
        elevator = elevator?.let { report ->
            val photos = bySlot[ReviewPhotoSlot.Elevator]
            if (photos == null || photos.urls.isEmpty()) report else report.copy(review = mergeNote(report.review, photos))
        },
        toilet = toilet?.let { report ->
            val photos = bySlot[ReviewPhotoSlot.Toilet]
            if (photos == null || photos.urls.isEmpty()) report else report.copy(review = mergeNote(report.review, photos))
        },
    )
}

private fun mergeNote(existing: ReviewNote?, photos: SlotPhotoUrls): ReviewNote? {
    val text = existing?.text
    if (text.isNullOrBlank() && photos.urls.isEmpty()) return null
    return ReviewNote(
        text = text,
        photoUrls = photos.urls,
        photoCaptions = photos.captions,
    )
}
