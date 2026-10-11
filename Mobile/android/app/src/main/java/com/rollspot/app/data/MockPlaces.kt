package com.rollspot.app.data

import app.rollspot.shared.api.Place

/** Fake directory rows for debug builds — form navigation only, not real API ids. */
object MockPlaces {
    private const val LAT = -8.7200
    private const val LNG = 115.1700

    val all: List<Place> = listOf(
        place("mock-park-23", "Park 23", "Jl. Mock 23, Denpasar"),
        place("mock-park-22", "Park 22", "Jl. Mock 22, Denpasar"),
        place("mock-park-21", "Park 21", "Jl. Mock 21, Denpasar"),
        place("mock-mall-sunset", "Sunset Mall (mock)", "Badung"),
        place("mock-mall-beachwalk", "Beachwalk Mall (mock)", "Kuta"),
        place("mock-hospital", "Mock General Hospital", "Tabanan"),
        place("mock-library", "Mock City Library", "Denpasar"),
        place("mock-station", "Mock Transit Hub", "Gianyar"),
    )

    fun find(id: String): Place? = all.find { it.id == id }

    fun filter(query: String): List<Place> {
        val q = query.trim()
        if (q.isEmpty()) return all
        return all.filter {
            it.name.contains(q, ignoreCase = true) ||
                (it.address?.contains(q, ignoreCase = true) == true)
        }
    }

    private fun place(id: String, name: String, address: String) = Place(
        id = id,
        osmRef = "mock:$id",
        name = name,
        category = "mock",
        lat = LAT,
        lng = LNG,
        address = address,
    )
}
