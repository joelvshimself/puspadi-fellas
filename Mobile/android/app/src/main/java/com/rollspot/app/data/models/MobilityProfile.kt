package com.rollspot.app.data.models

import kotlinx.serialization.Serializable

/**
 * User mobility profile.
 * Mirrors iOS MobilityProfile
 */
@Serializable
data class MobilityProfile(
    val userId: String,
    val mobilityType: String? = null,
    val requiresWheelchair: Boolean = false,
    val requiresWalker: Boolean = false,
    val requiresCane: Boolean = false,
    val needsAccessibleEntrance: Boolean = true,
    val needsAccessibleRestroom: Boolean = true,
    val needsAccessibleParking: Boolean = true,
    val notes: String? = null
)
