package app.rollspot.shared.places

import app.rollspot.shared.api.FeatureGrade
import app.rollspot.shared.api.Place

/** The single badge on a map pin and a place header. Views map it to colors, icons and copy. */
enum class OverallAccessibility { ACCESSIBLE, PARTIALLY_ACCESSIBLE, NOT_ACCESSIBLE, NO_DATA }

/**
 * THE ONE RULE for collapsing per-feature grades into one badge. The pin and the
 * detail page used to collapse grades differently, so the same mall was green on
 * the map and orange when opened. Everything calls this now.
 *
 * Unknown features are ignored rather than counted against a place: not knowing
 * whether a restroom is accessible is not evidence that it isn't, and counting it
 * would punish exactly the under-documented places contributors should visit.
 */
fun collapseAccessibility(grades: List<FeatureGrade>): OverallAccessibility {
    val known = grades.map { it.bestValue }.filter { it == "yes" || it == "no" || it == "limited" }
    return when {
        known.isEmpty() -> OverallAccessibility.NO_DATA
        "no" in known -> OverallAccessibility.NOT_ACCESSIBLE
        "limited" in known -> OverallAccessibility.PARTIALLY_ACCESSIBLE
        else -> OverallAccessibility.ACCESSIBLE
    }
}

val Place.overallAccessibility: OverallAccessibility get() = collapseAccessibility(grade)
