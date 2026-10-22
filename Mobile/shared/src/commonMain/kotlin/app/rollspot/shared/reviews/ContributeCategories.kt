package app.rollspot.shared.reviews

enum class ContributeReviewCategory {
    Entrance,
    Elevator,
    Toilet,
    OutdoorPathways,
    Seating,
    Parking,
    ;

    val isSupplemental: Boolean
        get() = this in supplemental

    companion object {
        val menuOrder: List<ContributeReviewCategory> = entries
        val coreFacilities: List<ContributeReviewCategory> = listOf(Entrance, Elevator, Toilet)
        val supplemental: List<ContributeReviewCategory> = listOf(OutdoorPathways, Seating, Parking)
    }
}

object ContributeCategoryLabels {
    fun menuTitle(category: ContributeReviewCategory): String = when (category) {
        ContributeReviewCategory.Entrance -> "Entrance"
        ContributeReviewCategory.Elevator -> "Elevators"
        ContributeReviewCategory.Toilet -> "Toilet"
        ContributeReviewCategory.OutdoorPathways -> "Outdoor Pathways"
        ContributeReviewCategory.Seating -> "Seating"
        ContributeReviewCategory.Parking -> "Parking"
    }

    fun supplementalSectionTitle(category: ContributeReviewCategory): String = when (category) {
        ContributeReviewCategory.OutdoorPathways -> "Outdoor Pathways"
        ContributeReviewCategory.Seating -> "Seating"
        ContributeReviewCategory.Parking -> "Parking"
        else -> menuTitle(category)
    }
}
