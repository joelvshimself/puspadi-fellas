package app.rollspot.shared.map

import app.rollspot.shared.api.Place
import app.rollspot.shared.places.OverallAccessibility
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.delay
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.advanceUntilIdle
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull
import kotlin.test.assertTrue

private class FakeProvider : PlaceSearchProvider {
    val nearbyCalls = mutableListOf<Triple<Double, Double, Int>>()
    val searchCalls = mutableListOf<String>()
    var nearbyResult: List<Place> = emptyList()
    var searchResult: List<Place> = emptyList()
    var failure: Exception? = null
    var latencyMs = 0L
    var coverageResult: List<CoverageRegion> = emptyList()

    override suspend fun coverage(): List<CoverageRegion> = coverageResult

    override suspend fun nearby(lat: Double, lng: Double, radiusMeters: Int): List<Place> {
        nearbyCalls += Triple(lat, lng, radiusMeters)
        delay(latencyMs)
        failure?.let { throw it }
        return nearbyResult
    }

    override suspend fun search(query: String, nearLat: Double, nearLng: Double): List<Place> {
        searchCalls += query
        failure?.let { throw it }
        return searchResult
    }
}

private class FakeGeocoder : AreaSearchProvider {
    var result: List<AreaResult> = emptyList()
    var failure: Exception? = null

    override suspend fun search(query: String, nearLat: Double, nearLng: Double): List<AreaResult> {
        failure?.let { throw it }
        return result
    }
}

private fun area(title: String, subtitle: String = "Japan", kind: AreaKind = AreaKind.City) =
    AreaResult(title, subtitle, 35.68, 139.76, kind)

private val bali = CoverageRegion("bali", "Bali", -8.85, 114.43, -8.06, 115.71)

@OptIn(ExperimentalCoroutinesApi::class)
class MapModelTest {
    private val provider = FakeProvider()

    private fun TestScope.model() = MapModel(provider, this, regionDebounceMs = 400, searchDebounceMs = 300)

    @Test
    fun panningBurstCallsNearbyOnceAfterTheCameraSettles() = runTest {
        val model = model()
        for (i in 0 until 10) {
            model.onRegionChanged(-8.72 + i * 0.001, 115.17, 3_000)
            advanceTimeBy(100)
        }
        assertEquals(0, provider.nearbyCalls.size)
        advanceUntilIdle()
        assertEquals(1, provider.nearbyCalls.size)
        assertEquals(-8.711, provider.nearbyCalls.single().first, 1e-9)
    }

    @Test
    fun loadedPlacesBecomeSortedPins() = runTest {
        provider.nearbyResult = listOf(testPlace("far", lat = -8.74), testPlace("near", lat = -8.7205))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        assertEquals(listOf("near", "far"), model.state.value.pins.map { it.id })
        assertEquals(false, model.state.value.isLoading)
    }

    @Test
    fun smallMoveAfterALoadDoesNotCallTheApiAgain() = runTest {
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 4_000)
        advanceUntilIdle()
        model.onRegionChanged(-8.7205, 115.17, 4_100) // ~55 m, 2.5% zoom
        advanceUntilIdle()
        assertEquals(1, provider.nearbyCalls.size)
    }

    @Test
    fun bigMoveOrZoomLoadsAgain() = runTest {
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 2_000)
        advanceUntilIdle()
        model.onRegionChanged(-8.73, 115.17, 2_000) // ~1.1 km on a 2 km radius
        advanceUntilIdle()
        model.onRegionChanged(-8.73, 115.17, 6_000) // zoomed out
        advanceUntilIdle()
        assertEquals(3, provider.nearbyCalls.size)
    }

    @Test
    fun radiusIsClamped() = runTest {
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 900_000)
        advanceUntilIdle()
        assertEquals(MapModel.MAX_RADIUS_METERS, provider.nearbyCalls.single().third)
    }

    @Test
    fun failedLoadSetsErrorAndKeepsOldPins() = runTest {
        provider.nearbyResult = listOf(testPlace("a"))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        provider.failure = RuntimeException("offline")
        model.onRegionChanged(-8.80, 115.17, 3_000)
        advanceUntilIdle()
        assertEquals("offline", model.state.value.error)
        assertEquals(listOf("a"), model.state.value.pins.map { it.id })
        assertEquals(false, model.state.value.isLoading)
    }

    @Test
    fun refreshReloadsEvenWithoutMovement() = runTest {
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        model.refresh()
        advanceUntilIdle()
        assertEquals(2, provider.nearbyCalls.size)
        assertEquals(provider.nearbyCalls[0], provider.nearbyCalls[1])
    }

    @Test
    fun searchSpinnerShowsDuringTheDebounce() = runTest {
        val model = model()
        model.onQueryChanged("kuta")
        runCurrent()
        assertTrue(model.state.value.isSearching)
        advanceUntilIdle()
        assertEquals(false, model.state.value.isSearching)
    }

    @Test
    fun typingDebouncesToOneSearchWithTheLatestText() = runTest {
        provider.searchResult = listOf(testPlace("k", "Kuta Mall"))
        val model = model()
        model.onQueryChanged("ku")
        advanceTimeBy(100)
        model.onQueryChanged("kut")
        advanceTimeBy(100)
        model.onQueryChanged("kuta")
        advanceUntilIdle()
        assertEquals(listOf("kuta"), provider.searchCalls)
        assertEquals(listOf("k"), model.state.value.results.map { it.id })
    }

    @Test
    fun shortQueryClearsResultsWithoutCallingTheApi() = runTest {
        provider.searchResult = listOf(testPlace("k"))
        val model = model()
        model.onQueryChanged("kuta")
        advanceUntilIdle()
        model.onQueryChanged("k")
        advanceUntilIdle()
        assertEquals(listOf("kuta"), provider.searchCalls)
        assertTrue(model.state.value.results.isEmpty())
        assertEquals(false, model.state.value.isSearchActive)
    }

    @Test
    fun staleSearchIsCancelledWhenQueryCleared() = runTest {
        val model = model()
        model.onQueryChanged("kuta")
        advanceTimeBy(100)
        model.clearQuery()
        advanceUntilIdle()
        assertTrue(provider.searchCalls.isEmpty())
    }

    @Test
    fun selectionSurvivesReloadsAndRecordsTheQuery() = runTest {
        provider.nearbyResult = listOf(testPlace("a", "Alpha Mall"))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        model.onQueryChanged("alpha")
        runCurrent()
        model.select(model.state.value.pins.single())
        provider.nearbyResult = emptyList()
        model.onRegionChanged(-8.90, 115.17, 3_000)
        advanceUntilIdle()
        assertEquals("a", model.state.value.selected?.id)
        assertEquals(listOf("a"), model.state.value.recentPlaces.map { it.id })
        model.clearSelection()
        assertNull(model.state.value.selected)
    }

    private val green = listOf(grade("entrance", "yes"))
    private val red = listOf(grade("entrance", "no"))

    @Test
    fun noPinsAreDrawnUntilAFilterIsChosen() = runTest {
        provider.nearbyResult = listOf(testPlace("a", grade = green))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        assertEquals(1, model.state.value.pins.size)
        assertTrue(model.state.value.visiblePins.isEmpty())
    }

    @Test
    fun filterShowsOnlyThatGradeAndTogglesOff() = runTest {
        provider.nearbyResult = listOf(testPlace("g", grade = green), testPlace("r", lat = -8.7201, grade = red))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        model.setGradeFilter(OverallAccessibility.ACCESSIBLE)
        advanceUntilIdle()
        assertEquals(listOf("g"), model.state.value.visiblePins.map { it.id })
        assertEquals(1, provider.nearbyCalls.size) // a match was already in view: no widening
        model.setGradeFilter(OverallAccessibility.ACCESSIBLE)
        assertNull(model.state.value.gradeFilter)
        assertTrue(model.state.value.visiblePins.isEmpty())
    }

    @Test
    fun filterWidensUntilAMatchAppears() = runTest {
        provider.nearbyResult = listOf(testPlace("r", grade = red))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 2_000)
        advanceUntilIdle()
        provider.nearbyResult = listOf(testPlace("r", grade = red), testPlace("g", lat = -8.75, grade = green))
        model.setGradeFilter(OverallAccessibility.ACCESSIBLE)
        advanceUntilIdle()
        val state = model.state.value
        assertEquals(listOf("g"), state.visiblePins.map { it.id })
        assertEquals(4_000, state.focus?.radiusMeters)
        assertEquals(false, state.isWidening)
    }

    @Test
    fun filterGivesUpAfterTheStepLimitAndKeepsTheMapWhereItWas() = runTest {
        provider.nearbyResult = listOf(testPlace("r", grade = red))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 1_000)
        advanceUntilIdle()
        model.setGradeFilter(OverallAccessibility.ACCESSIBLE)
        advanceUntilIdle()
        assertEquals(1 + MapModel.MAX_FILTER_STEPS, provider.nearbyCalls.size)
        assertNull(model.state.value.focus)
        assertTrue(model.state.value.visiblePins.isEmpty())
        assertEquals(false, model.state.value.isWidening)
    }

    @Test
    fun cameraEventsAreIgnoredWhileWidening() = runTest {
        provider.nearbyResult = listOf(testPlace("r", grade = red))
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 1_000)
        advanceUntilIdle()
        provider.latencyMs = 1_000
        model.setGradeFilter(OverallAccessibility.ACCESSIBLE)
        runCurrent()
        assertTrue(model.state.value.isWidening)
        model.onRegionChanged(-8.9, 115.3, 1_000)
        advanceTimeBy(500)
        assertEquals(-8.72, model.state.value.centerLat, 1e-9)
        advanceUntilIdle()
        assertEquals(1 + MapModel.MAX_FILTER_STEPS, provider.nearbyCalls.size)
    }

    @Test
    fun recentsMatchTheQueryAndAreNotRepeatedInResults() = runTest {
        val park = testPlace("p", "Park 23")
        val other = testPlace("o", "Parklife Bali", lat = -8.73)
        provider.nearbyResult = listOf(park)
        provider.searchResult = listOf(park, other)
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        model.select(model.state.value.pins.single())
        model.onQueryChanged("park")
        advanceUntilIdle()
        val state = model.state.value
        assertEquals(listOf("p"), state.matchingRecents.map { it.id })
        assertEquals(listOf("o"), state.freshResults.map { it.id })
        model.onQueryChanged("xyz")
        advanceUntilIdle()
        assertTrue(model.state.value.matchingRecents.isEmpty())
    }

    @Test
    fun filterCancellingARegionLoadClearsTheSpinner() = runTest {
        provider.latencyMs = 1_000
        val model = model()
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceTimeBy(500) // debounce passed, request in flight
        runCurrent()
        assertTrue(model.state.value.isLoading)
        model.setGradeFilter(OverallAccessibility.NOT_ACCESSIBLE)
        assertEquals(false, model.state.value.isLoading)
        advanceUntilIdle()
        assertEquals(false, model.state.value.isLoading)
    }

    @Test
    fun emptyAreaCountsAsLoaded() = runTest {
        val model = model()
        assertEquals(false, model.state.value.hasLoaded)
        model.onRegionChanged(-8.72, 115.17, 3_000)
        advanceUntilIdle()
        assertTrue(model.state.value.hasLoaded)
        assertTrue(model.state.value.pins.isEmpty())
    }

    @Test
    fun openRemembersPlacesTheMapNeverLoaded() = runTest {
        val model = model()
        val deepLinked = testPlace("from-link")
        model.open(deepLinked)
        assertEquals(listOf("from-link"), model.state.value.recentPlaces.map { it.id })
    }

    @Test
    fun viewportRadiusIsTheSameFormulaOnBothApps() {
        // 0.05° square at Bali's latitude: north side 5.6 km, east side a bit shorter → half of 5.6 km.
        assertEquals(2_783, viewportRadiusMeters(-8.72, 0.05, 0.05))
        // Wide but short viewport: the east-west side decides, shrunk by latitude.
        assertEquals(5_502, viewportRadiusMeters(-8.72, 0.02, 0.1))
        assertEquals(MapModel.MIN_RADIUS_METERS, viewportRadiusMeters(-8.72, 0.0001, 0.0001))
        assertEquals(MapModel.MAX_RADIUS_METERS, viewportRadiusMeters(-8.72, 5.0, 5.0))
    }

    @Test
    fun areasFollowPlacesWithoutRepeatsAndAtMostThree() = runTest {
        provider.searchResult = listOf(testPlace("k", "Kuta Mall"))
        val geocoder = FakeGeocoder().apply {
            result = listOf(area("Kuta Mall"), area("Kuta", "Bali"), area("Kuta", "Bali"), area("Kuta Utara"), area("Kuta Selatan"), area("Kutai"))
        }
        val model = model().apply { areaSearch = geocoder }
        model.onQueryChanged("kuta")
        advanceUntilIdle()
        assertEquals(listOf("k"), model.state.value.results.map { it.id })
        assertEquals(listOf("Kuta", "Kuta Utara", "Kuta Selatan"), model.state.value.areaResults.map { it.title })

        model.clearQuery()
        assertTrue(model.state.value.areaResults.isEmpty())
    }

    @Test
    fun aFailingGeocoderNeverHidesPlacesAndAreasStandInForAFailedPlaceSearch() = runTest {
        provider.searchResult = listOf(testPlace("k", "Kuta Mall"))
        val geocoder = FakeGeocoder().apply { failure = IllegalStateException("offline") }
        val model = model().apply { areaSearch = geocoder }
        model.onQueryChanged("kuta")
        advanceUntilIdle()
        assertEquals(1, model.state.value.results.size)
        assertNull(model.state.value.error)

        geocoder.failure = null
        geocoder.result = listOf(area("Tokyo"))
        provider.failure = IllegalStateException("API down")
        model.onQueryChanged("tokyo")
        advanceUntilIdle()
        assertEquals(listOf("Tokyo"), model.state.value.areaResults.map { it.title })
        assertNull(model.state.value.error, "an area to go to is better than an error")
    }

    @Test
    fun goingToAnAreaMovesTheCameraClosesSearchAndLoadsPlacesThere() = runTest {
        val model = model()
        model.onQueryChanged("tokyo")
        model.goTo(area("Tokyo"))
        advanceUntilIdle()
        val state = model.state.value
        assertEquals("", state.query)
        assertEquals(35.68, state.focus?.lat)
        assertEquals(AreaKind.City.radiusMeters, state.focus?.radiusMeters)
        assertEquals(35.68, provider.nearbyCalls.last().first)
    }

    @Test
    fun outsideCoverageIsKnownOnlyOnceCoverageHasLoaded() = runTest {
        val model = model()
        model.onRegionChanged(35.68, 139.76, 5_000)
        advanceUntilIdle()
        assertEquals(false, model.state.value.isOutsideCoverage, "coverage unknown: don't claim anything")

        provider.coverageResult = listOf(bali)
        val covered = model()
        advanceUntilIdle()
        covered.onRegionChanged(35.68, 139.76, 5_000)
        advanceUntilIdle()
        assertTrue(covered.state.value.isOutsideCoverage)
        assertEquals("bali", covered.state.value.nearestCoveredRegion?.id)

        covered.goTo(bali)
        advanceUntilIdle()
        assertEquals(false, covered.state.value.isOutsideCoverage)
    }
}
