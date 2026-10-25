package app.rollspot.shared.media

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class PhotoUploadTest {
    @Test
    fun bigPhotosShrinkToTheLongestSideAndSmallOnesStay() {
        // 48 MP iPhone photo, portrait.
        assertEquals(PixelSize(1536, 2048), PhotoUpload.Review.targetSize(6048, 8064))
        assertEquals(PixelSize(1024, 576), PhotoUpload.Avatar.targetSize(4000, 2250))
        assertEquals(PixelSize(800, 600), PhotoUpload.Review.targetSize(800, 600))
        assertEquals(PixelSize(2048, 1), PhotoUpload.Review.targetSize(20_000, 3), "panorama strips keep at least 1 px")
    }

    @Test
    fun qualityDropsUntilTheBytesFit() {
        val tried = mutableListOf<Int>()
        val bytes = PhotoUpload.Avatar.encodeWithinLimit { quality ->
            tried += quality
            ByteArray(if (quality > 60) 6_000_000 else 1_000_000)
        }
        assertEquals(listOf(82, 72, 60), tried)
        assertEquals(1_000_000, bytes?.size)
    }

    @Test
    fun aFailedEncodeGivesUpAtOnce() {
        var calls = 0
        assertNull(PhotoUpload.Review.encodeWithinLimit { calls++; null })
        assertEquals(1, calls)
    }
}
