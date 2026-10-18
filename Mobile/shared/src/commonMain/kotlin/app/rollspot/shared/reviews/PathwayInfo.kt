package app.rollspot.shared.reviews

data class PathwayAvoidPoint(val lead: String, val rest: String)

data class PathwayInfoPage(
    val id: String,
    val chip: String,
    val title: String,
    val body: String,
    val avoid: List<PathwayAvoidPoint>,
    val videoKey: String,
)

object PathwayInfoCatalog {
    val pages: List<PathwayInfoPage> = listOf(
        PathwayInfoPage(
            id = "surfaces",
            chip = "SURFACES",
            title = "Surfaces",
            body = "For wheelchairs and people with limited mobility, firm and smooth surfaces provide more support and balance.",
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
            body = "Wide, unobstructed pathways allow people on wheels, strollers, and mobility aids to pass through comfortably.",
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
            body = "Curbs and steps without a ramp block wheelchairs and strollers.",
            avoid = listOf(
                PathwayAvoidPoint(
                    "Curbs or steps with no ramp",
                    " stop a wheelchair at the edge.",
                ),
                PathwayAvoidPoint(
                    "Objects blocking the path",
                    " force a detour or a turn-around.",
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
