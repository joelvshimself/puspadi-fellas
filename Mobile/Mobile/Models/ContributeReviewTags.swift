import SwiftUI

/// The "what did this facility have" tag catalog for the Contribute Review
/// flow (Views/Review/Mock) — matches the Figma mockup's exact chip lists,
/// which is a deliberate choice: they don't map 1:1 onto the real backend's
/// structured fields (see ContributeReviewFlowView's field-mapping comment),
/// but the user confirmed the mockup's tags should win over the existing
/// `FacilityKind.reviewedProvidedItems` catalog.
///
/// Entrance's list happens to already match `FacilityKind.reviewedProvidedItems`
/// exactly (see Views/Facilities Details/NotReview.swift) — reused directly
/// rather than duplicated. Elevator/Toilet diverge from what's already there,
/// so those get their own literal lists here.
struct ContributeTagOption: Identifiable, Hashable {
    let symbol: String
    let label: String

    var id: String { label }
}

enum ContributeReviewTags {
    static func tags(for kind: FacilityKind) -> [ContributeTagOption] {
        switch kind {
        case .entrance:
            // Exact match to FacilityKind.reviewedProvidedItems — reused,
            // not duplicated by hand.
            kind.reviewedProvidedItems.map { ContributeTagOption(symbol: $0.symbol, label: $0.label) }
        case .elevator:
            [
                ContributeTagOption(symbol: "door.left.hand.closed", label: "WIDE ENTRANCE"),
                ContributeTagOption(symbol: "button.programmable", label: "REACHABLE BUTTONS"),
            ]
        case .toilet:
            [
                ContributeTagOption(symbol: "figure.roll", label: "GRAB BARS"),
                ContributeTagOption(symbol: "bell", label: "EMERGENCY BUTTONS"),
                ContributeTagOption(symbol: "door.left.hand.closed", label: "AUTOMATIC DOORS"),
            ]
        }
    }
}
