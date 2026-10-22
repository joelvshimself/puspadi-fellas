package com.rollspot.app.ui.screens.contribute

import androidx.annotation.DrawableRes
import androidx.compose.runtime.Composable
import androidx.compose.ui.res.painterResource
import app.rollspot.shared.reviews.ContributeCatalog
import app.rollspot.shared.reviews.ContributeHeroAsset
import app.rollspot.shared.reviews.ContributeReviewCategory
import com.rollspot.app.R

@DrawableRes
fun heroDrawable(asset: ContributeHeroAsset): Int? = when (asset) {
    ContributeHeroAsset.EntranceMall -> R.drawable.contribute_entrance_mall
    ContributeHeroAsset.Lobby -> R.drawable.contribute_lobby
    ContributeHeroAsset.Basement -> R.drawable.contribute_basement
    ContributeHeroAsset.Elevator -> R.drawable.contribute_elevator
    ContributeHeroAsset.ElevatorQuestion -> R.drawable.contribute_elevator_question
    ContributeHeroAsset.ToiletSurvey -> R.drawable.contribute_toilet_survey
    // Design: the pathway photo step uses the same amenities illustration as seating.
    ContributeHeroAsset.Pathway -> R.drawable.contribute_toilet_survey
    ContributeHeroAsset.Seating -> R.drawable.contribute_toilet_survey
    ContributeHeroAsset.None -> null
}

@DrawableRes
fun tagChipDrawable(tag: String): Int? = when (tag) {
    ContributeCatalog.TAG_RAMP -> R.drawable.chip_ramp
    ContributeCatalog.TAG_HANDRAIL -> R.drawable.chip_handrail
    ContributeCatalog.TAG_AUTO_DOORS -> R.drawable.chip_automatic_doors
    ContributeCatalog.TAG_MANUAL_DOORS -> R.drawable.chip_manual_doors
    "SECURITY ASSISTANCE" -> R.drawable.chip_security_assistance
    "WHEELCHAIRS AVAILABLE" -> R.drawable.chip_wheelchair_available
    "ELEVATOR" -> R.drawable.chip_elevator
    "DISABLED PARKING" -> R.drawable.chip_disabled_parking
    else -> null
}

/** Category tiles on "Help make every visit easier", from `grafical assts` SVGs. */
@DrawableRes
fun categoryMenuIcon(category: ContributeReviewCategory): Int = when (category) {
    ContributeReviewCategory.Entrance -> R.drawable.contribute_menu_entrance
    ContributeReviewCategory.Elevator -> R.drawable.contribute_menu_elevator
    ContributeReviewCategory.Toilet -> R.drawable.contribute_menu_toilet
    ContributeReviewCategory.OutdoorPathways -> R.drawable.contribute_menu_pathway
    ContributeReviewCategory.Seating -> R.drawable.contribute_menu_seating
    ContributeReviewCategory.Parking -> R.drawable.contribute_menu_parking
}

@Composable
fun rememberHeroPainter(asset: ContributeHeroAsset) =
    heroDrawable(asset)?.let { painterResource(it) }
