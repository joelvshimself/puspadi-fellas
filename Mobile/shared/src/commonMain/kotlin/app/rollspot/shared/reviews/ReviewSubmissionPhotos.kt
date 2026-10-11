package app.rollspot.shared.reviews

import app.rollspot.shared.api.EntranceReport
import app.rollspot.shared.api.ElevatorReport
import app.rollspot.shared.api.ReviewNote
import app.rollspot.shared.api.ReviewSubmission
import app.rollspot.shared.api.ToiletReport

internal data class SlotPhotoUrls(
    val urls: List<String> = emptyList(),
    val captions: List<String> = emptyList(),
)

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
