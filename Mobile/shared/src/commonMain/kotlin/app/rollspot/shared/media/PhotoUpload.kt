package app.rollspot.shared.media

import kotlin.math.max
import kotlin.math.roundToInt

/**
 * How every photo is prepared before upload, on both apps. Whatever the user picks (a 48 MP
 * iPhone shot, HEIC, PNG, a screenshot), the app decodes it upright, shrinks it to fit [maxSide]
 * and encodes JPEG, lowering quality until it fits [maxBytes]. The backend's JPEG-only, size-
 * capped endpoints then never turn a photo away.
 */
enum class PhotoUpload(val maxSide: Int, val maxBytes: Int) {
    /** Review and place photos: sharp on any phone screen. Backend limit is 10 MB. */
    Review(2048, 9_500_000),
    /** Profile pictures. Backend limit is 5 MB. */
    Avatar(1024, 4_500_000);

    /** The size to draw a [width] × [height] image at: fits [maxSide], never enlarged. */
    fun targetSize(width: Int, height: Int): PixelSize {
        val longest = max(width, height)
        if (longest <= maxSide || longest <= 0) return PixelSize(width, height)
        val scale = maxSide.toDouble() / longest
        return PixelSize(max(1, (width * scale).roundToInt()), max(1, (height * scale).roundToInt()))
    }

    /**
     * Encodes with falling quality until the bytes fit. [encode] gets a JPEG quality from 0 to 100
     * and returns the bytes, or null if encoding failed. Null when nothing fits (in practice only a
     * failed encode: a 2048 px JPEG at quality 50 is well under a megabyte).
     */
    fun encodeWithinLimit(encode: (quality: Int) -> ByteArray?): ByteArray? {
        for (quality in QUALITIES) {
            val bytes = encode(quality) ?: return null
            if (bytes.isNotEmpty() && bytes.size <= maxBytes) return bytes
        }
        return null
    }

    companion object {
        /** First try keeps photos crisp; the later ones only matter for unusual, noisy images. */
        val QUALITIES = listOf(82, 72, 60, 45, 30)
    }
}

data class PixelSize(val width: Int, val height: Int)
