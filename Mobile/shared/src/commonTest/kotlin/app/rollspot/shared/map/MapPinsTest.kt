package app.rollspot.shared.map

import app.rollspot.shared.api.FeatureGrade
import app.rollspot.shared.api.Place
import app.rollspot.shared.places.OverallAccessibility
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertSame

fun testPlace(
    id: String,
    name: String = id,
    lat: Double = -8.72,
    lng: Double = 115.17,
    grade: List<FeatureGrade> = emptyList(),
) = Place(id = id, osmRef = "node/$id", name = name, lat = lat, lng = lng, grade = grade)

fun grade(feature: String, value: String) = FeatureGrade(feature, value, 1.0)

class MapPinsTest {
    @Test
    fun normalizeIgnoresCaseSpacesAndPunctuation() {
        assertEquals("beachwalkbali", normalizePlaceName("Beachwalk  Bali!"))
        assertEquals(normalizePlaceName("Mal Bali Galeria"), normalizePlaceName("mal bali-galeria"))
    }

    @Test
    fun dedupeMergesSameNameCloseTogether() {
        val node = testPlace("a", "Beachwalk", lat = -8.7200, lng = 115.1700)
        val way = testPlace("b", "BEACHWALK", lat = -8.7203, lng = 115.1702)
        assertEquals(listOf("a"), dedupePlaces(listOf(node, way)).map { it.id })
    }

    @Test
    fun dedupeKeepsSameNameFarApart() {
        val kuta = testPlace("a", "Lippo Mall", lat = -8.72, lng = 115.17)
        val sanur = testPlace("b", "Lippo Mall", lat = -8.69, lng = 115.26)
        assertEquals(listOf("a", "b"), dedupePlaces(listOf(kuta, sanur)).map { it.id })
    }

    @Test
    fun dedupeKeepsDifferentNamesClosetogether() {
        val a = testPlace("a", "Mall One")
        val b = testPlace("b", "Mall Two")
        assertEquals(2, dedupePlaces(listOf(a, b)).size)
    }

    @Test
    fun dedupePrefersTheEntryWithMoreGrades() {
        val bare = testPlace("a", "Beachwalk")
        val graded = testPlace("b", "Beachwalk", grade = listOf(grade("entrance", "yes")))
        assertSame(graded, dedupePlaces(listOf(bare, graded)).single())
    }

    @Test
    fun dedupeDropsRepeatedIds() {
        val p = testPlace("a", "Beachwalk")
        assertEquals(1, dedupePlaces(listOf(p, p.copy(name = "Renamed", lat = -8.5))).size)
    }

    @Test
    fun pinsAreSortedNearestFirstWithGradeAndLabel() {
        val far = testPlace("far", lat = -8.74, grade = listOf(grade("entrance", "no")))
        val near = testPlace("near", lat = -8.7205, grade = listOf(grade("entrance", "yes")))
        val pins = toPins(listOf(far, near), lat = -8.72, lng = 115.17)
        assertEquals(listOf("near", "far"), pins.map { it.id })
        assertEquals(OverallAccessibility.ACCESSIBLE, pins[0].grade)
        assertEquals(OverallAccessibility.NOT_ACCESSIBLE, pins[1].grade)
        assertEquals("60 m", pins[0].distanceLabel)
    }

    @Test
    fun equalDistanceBreaksTiesByName() {
        val b = testPlace("1", "B Mall")
        val a = testPlace("2", "A Mall")
        assertEquals(listOf("2", "1"), toPins(listOf(b, a), -8.73, 115.17).map { it.id })
    }

    @Test
    fun recentPlacesAreNewestFirstOnePerPlaceAndCapped() {
        var recent = emptyList<Place>()
        for (id in listOf("a", "b", "c", "a", "d", "e", "f")) recent = recent.withRecent(testPlace(id))
        assertEquals(listOf("f", "e", "d", "a", "c"), recent.map { it.id })
    }
}
