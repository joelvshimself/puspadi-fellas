package app.rollspot.shared.places

import app.rollspot.shared.api.FeatureGrade
import app.rollspot.shared.util.mapWithLimit
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class AccessibilityTest {
    private fun grade(feature: String, value: String) = FeatureGrade(feature, value, 1.0)

    @Test
    fun noGradesMeansNoData() {
        assertEquals(OverallAccessibility.NO_DATA, collapseAccessibility(emptyList()))
    }

    @Test
    fun unknownValuesAreIgnoredNotPenalised() {
        assertEquals(OverallAccessibility.NO_DATA, collapseAccessibility(listOf(grade("restroom", "unknown"))))
        assertEquals(
            OverallAccessibility.ACCESSIBLE,
            collapseAccessibility(listOf(grade("entrance", "yes"), grade("restroom", "unknown"))),
        )
    }

    @Test
    fun worstKnownVerdictWins() {
        assertEquals(
            OverallAccessibility.NOT_ACCESSIBLE,
            collapseAccessibility(listOf(grade("entrance", "yes"), grade("elevator", "limited"), grade("restroom", "no"))),
        )
        assertEquals(
            OverallAccessibility.PARTIALLY_ACCESSIBLE,
            collapseAccessibility(listOf(grade("entrance", "yes"), grade("elevator", "limited"))),
        )
        assertEquals(OverallAccessibility.ACCESSIBLE, collapseAccessibility(listOf(grade("entrance", "yes"))))
    }

    @Test
    fun mapWithLimitKeepsOrderAndCapsConcurrency() = runTest {
        var running = 0
        var peak = 0
        val result = mapWithLimit((1..10).toList(), limit = 3) { item ->
            running++
            peak = maxOf(peak, running)
            delay((11 - item) * 10L)
            running--
            item * 2
        }
        assertEquals((1..10).map { it * 2 }, result)
        assertTrue(peak <= 3, "peak was $peak")
    }
}

class DistanceTest {
    @Test
    fun formatsDistancesForPeople() {
        assertEquals("350 m", formatDistance(347.0))
        assertEquals("1.2 km", formatDistance(1_234.0))
        assertEquals("12 km", formatDistance(12_400.0))
    }

    @Test
    fun computesGreatCircleDistance() {
        // Beachwalk Bali to Discovery Mall Bali is about 2.4 km.
        val meters = distanceMeters(-8.7165, 115.1696, -8.7374, 115.1676)
        assertTrue(meters in 2_200.0..2_500.0, "was $meters")
    }
}
