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
    /// True when `symbol` is an SF Symbol name (`Image(systemName:)`); false
    /// when it's a custom template-rendered asset in Assets.xcassets.
    var isSystemSymbol: Bool = true

    var id: String { label }
}

/// The elevator section asks three single-select questions instead of a
/// chip multi-select — each question's "Yes" is what earns the matching
/// chip in `ContributeReviewTags.tags(for: .elevator)` (per the mockup's
/// "This question answers for WIDE ENTRANCE" dev notes).
enum ElevatorQuestion: String, CaseIterable {
    case wideEntrance
    case spaceToManeuver
    case reachableButtons

    var eyebrow: String {
        switch self {
        case .wideEntrance: "Entrance Width"
        case .spaceToManeuver: "Space to Maneuver"
        case .reachableButtons: "Reachable Buttons"
        }
    }

    func title(for persona: ReviewPersona) -> String {
        switch (self, persona) {
        case (.wideEntrance, .wheelchair):
            "Could you enter the elevator?"
        case (.wideEntrance, .everyone):
            "Could someone in a wheelchair enter the elevator?"
        case (.spaceToManeuver, .wheelchair):
            "Could you turn your wheelchair freely inside?"
        case (.spaceToManeuver, .everyone):
            "Could someone turn their wheelchair freely inside?"
        case (.reachableButtons, .wheelchair):
            "Could you reach the buttons from your wheelchair?"
        case (.reachableButtons, .everyone):
            "Could someone in a wheelchair reach the buttons?"
        }
    }

    /// Chip label this question's "Yes" answer earns.
    var tagLabel: String {
        switch self {
        case .wideEntrance: "WIDE ENTRANCE"
        case .spaceToManeuver: "SPACE TO MANEUVER"
        case .reachableButtons: "REACHABLE BUTTONS"
        }
    }
}

enum ContributeReviewTags {
    /// Lobby and Basement each get their own chip catalog — Basement adds
    /// "Elevator"/"Disabled Parking" (things you'd only meet coming from a
    /// parking level) and drops the door/wheelchair chips Lobby has.
    static func tags(forEntrance location: EntranceLocation, persona: ReviewPersona = .wheelchair) -> [ContributeTagOption] {
        switch location {
        case .lobby:
            lobbyTags(for: persona)
        case .basement:
            [
                ContributeTagOption(symbol: "Review - Elevators", label: "ELEVATOR", isSystemSymbol: false),
                ContributeTagOption(symbol: "Review - Disabled Parking", label: "DISABLED PARKING", isSystemSymbol: false),
                ContributeTagOption(symbol: "Ramp Icon", label: "RAMP", isSystemSymbol: false),
                ContributeTagOption(symbol: "Handrail Icon", label: "HANDRAIL", isSystemSymbol: false),
                ContributeTagOption(symbol: "Review - Security Assistance", label: "SECURITY ASSISTANCE", isSystemSymbol: false),
            ]
        }
    }

    private static func lobbyTags(for persona: ReviewPersona) -> [ContributeTagOption] {
        var tags: [ContributeTagOption] = [
            ContributeTagOption(symbol: "Ramp Icon", label: "RAMP", isSystemSymbol: false),
            ContributeTagOption(symbol: "Handrail Icon", label: "HANDRAIL", isSystemSymbol: false),
            ContributeTagOption(symbol: "Review - Elevators", label: "AUTOMATIC DOORS", isSystemSymbol: false),
        ]
        switch persona {
        case .wheelchair:
            tags.append(ContributeTagOption(symbol: "door.left.hand.open", label: "MANUAL DOORS"))
        case .everyone:
            tags.append(ContributeTagOption(symbol: "Review - Elevators", label: "ELEVATOR/ESCALATOR", isSystemSymbol: false))
        }
        tags.append(contentsOf: [
            ContributeTagOption(symbol: "Review - Security Assistance", label: "SECURITY ASSISTANCE", isSystemSymbol: false),
            ContributeTagOption(symbol: "Review - Wheelchair Available", label: "WHEELCHAIRS AVAILABLE", isSystemSymbol: false),
        ])
        return tags
    }

    static func tags(for kind: FacilityKind) -> [ContributeTagOption] {
        switch kind {
        case .entrance:
            // Kept for compatibility — entrance now goes through
            // `tags(forEntrance:)` per location instead.
            tags(forEntrance: .lobby)
        case .elevator:
            [
                ContributeTagOption(symbol: "Review - Elevators", label: "WIDE ENTRANCE", isSystemSymbol: false),
                ContributeTagOption(symbol: "arrow.clockwise.circle", label: "SPACE TO MANEUVER"),
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
