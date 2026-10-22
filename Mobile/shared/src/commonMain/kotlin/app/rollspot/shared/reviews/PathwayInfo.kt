package app.rollspot.shared.reviews

data class PathwayAvoidPoint(val lead: String, val rest: String)

/** A run of copy; [bold] runs are the design's emphasised phrases. */
data class TextRun(val text: String, val bold: Boolean = false)

data class PathwayInfoPage(
    val id: String,
    val chip: String,
    val title: String,
    /** Plain copy, with the design's emphasised phrases in [bodyRuns]. */
    val bodyRuns: List<TextRun>,
    val avoid: List<PathwayAvoidPoint>,
    val videoKey: String,
) {
    val body: String get() = bodyRuns.joinToString("") { it.text }
}

object PathwayInfoCatalog {
    val pages: List<PathwayInfoPage> = listOf(
        PathwayInfoPage(
            id = "surfaces",
            chip = "SURFACES",
            title = "Surfaces",
            bodyRuns = listOf(
                TextRun("For wheelchairs and people with limited mobility, "),
                TextRun("firm and smooth surfaces", bold = true),
                TextRun(" provide more support and balance."),
            ),
            avoid = listOf(
                PathwayAvoidPoint(
                    "Loose material like gravel or sand",
                    " lets wheels sink and shifts under the foot.",
                ),
                PathwayAvoidPoint(
                    "Rough or uneven surfaces",
                    " such as broken ground, cracked surfaces, and tree roots will get caught in wheels.",
                ),
            ),
            videoKey = "surfaces",
        ),
        PathwayInfoPage(
            id = "width",
            chip = "WIDTH",
            title = "Width",
            bodyRuns = listOf(
                TextRun("Wide, unobstructed pathways", bold = true),
                TextRun(" allow people on wheels, strollers, and mobility aids to pass through comfortably."),
            ),
            avoid = listOf(
                PathwayAvoidPoint(
                    "Narrow pathways",
                    " would let wheelchairs ride off the edge.",
                ),
                PathwayAvoidPoint(
                    "Tight gaps",
                    " between obstacles.",
                ),
            ),
            videoKey = "width",
        ),
        PathwayInfoPage(
            id = "obstructions",
            chip = "OBSTRUCTIONS",
            title = "Obstructions",
            bodyRuns = listOf(
                TextRun("An inclined path should behave like a ramp: gentle enough to climb not a sudden steep rise."),
            ),
            avoid = listOf(
                PathwayAvoidPoint(
                    "Steep sections",
                    " will be dangerous for wheelchair users to navigate on their own.",
                ),
                PathwayAvoidPoint(
                    "Curb or steps with no ramps",
                    " without any nearby alternatives.",
                ),
            ),
            videoKey = "obstructions",
        ),
    )
}

data class ParkingInfoSection(val title: String, val body: String)

object ParkingInfo {
    const val title = "Accessible Parking"
    const val videoKey = "parking"
    val sections: List<ParkingInfoSection> = listOf(
        ParkingInfoSection(
            title = "Space",
            body = "Wider than a standard spot, with designated access aisle for a wheelchair to unload.",
        ),
        ParkingInfoSection(
            title = "Distance",
            body = "Ideally located on the shortest, most direct route to the entrance, not the far end of the lot.",
        ),
    )
}
