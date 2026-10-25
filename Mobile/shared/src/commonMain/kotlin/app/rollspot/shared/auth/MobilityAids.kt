package app.rollspot.shared.auth

/** The answers to "How do you usually get around?". These strings are stored in `profiles.mobility_aids`. */
object MobilityAids {
    const val WHEELCHAIR = "Wheelchair"
    const val NONE = "No mobility aid"

    val options: List<String> = listOf(WHEELCHAIR, "Crutches", "Walking Aid", NONE, "Other")

    /** The role shown next to a contributor's name, matching the backend's reviewer_role. */
    fun role(aids: List<String>): String? = when {
        aids.isEmpty() -> null
        WHEELCHAIR in aids -> "Wheelchair User"
        else -> "Community Contributor"
    }
}

/**
 * The two profile roles shown in My Account. Picking one stores a canonical answer
 * in `mobility_aids`; any stored answers map back to one role.
 */
enum class MobilityRole(val label: String, val storageAids: List<String>) {
    WHEELCHAIR_USER("Wheelchair User", listOf(MobilityAids.WHEELCHAIR)),
    COMMUNITY_CONTRIBUTOR("Community Contributor", listOf(MobilityAids.NONE));

    companion object {
        fun fromAids(aids: List<String>): MobilityRole? = when {
            aids.isEmpty() -> null
            MobilityAids.WHEELCHAIR in aids -> WHEELCHAIR_USER
            else -> COMMUNITY_CONTRIBUTOR
        }
    }
}
