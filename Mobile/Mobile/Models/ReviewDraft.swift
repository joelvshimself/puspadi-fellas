import CoreLocation
import SwiftUI

/// State for the "Add Review" wizard (Views/Review/).
///
/// Field names/types mirror the real payload contract for the
/// `submit-accessibility-review` Edge Function (backend/supabase/functions/
/// submit-accessibility-review/index.ts) — see `ReviewSubmissionPayload` for
/// the exact wire shape and `ReviewService` for the live call site.
final class ReviewDraft: ObservableObject {
    /// TODO(backend): Place has no Apple Maps identifier field yet. This is
    /// placeholder-sourced from place.id.uuidString — real source TBD
    /// (likely an MKMapItem identifier once the search flow captures one).
    let appleMapsId: String
    let coordinate: CLLocationCoordinate2D

    /// The wizard always walks both entrances in sequence (Lobby, then
    /// Basement) rather than letting the user pick one — matches the
    /// backend's example payload, which submits both as separate
    /// `EntranceReport` array items.
    @Published var lobby = EntranceDraft(location: .lobby)
    @Published var basement = EntranceDraft(location: .basement)
    @Published var elevator = ElevatorDraft()
    @Published var toilet = ToiletDraft()

    init(appleMapsId: String, coordinate: CLLocationCoordinate2D) {
        self.appleMapsId = appleMapsId
        self.coordinate = coordinate
    }
}

// MARK: - Entrance

enum EntranceLocation: String {
    case lobby, basement

    var stepTitle: String {
        switch self {
        case .lobby: "Lobby entrance"
        case .basement: "Basement entrance"
        }
    }
}

enum DoorType: String, CaseIterable, Identifiable {
    case manual, automatic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .automatic: "Automatic"
        }
    }
}

struct EntranceDraft {
    let location: EntranceLocation
    var hasDropoffRamp: Bool?
    var hasRails: Bool?
    /// UI-only context copy from the flowchart ("Easy to go through / Needs
    /// assistance / Can't go through") — the backend contract has no
    /// matching field for this, so it is not sent at submit time.
    var easeOfAccess: EaseOfAccess?
    var doorType: DoorType?
    var isWideEnough: Bool?
    var review = ReviewNoteDraft()
}

enum EaseOfAccess: String, CaseIterable, Identifiable {
    case easy, needsAssistance, cantGoThrough

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "Easy to go through"
        case .needsAssistance: "Needs assistance"
        case .cantGoThrough: "Can't go through"
        }
    }
}

// MARK: - Elevator

enum ElevatorBlocker: String, CaseIterable, Identifiable {
    case noRamp = "no_ramp"
    case tooSmall = "too_small"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noRamp: "No ramp"
        case .tooSmall: "Too small"
        }
    }
}

struct ElevatorDraft {
    var exists: Bool?
    /// Only asked/shown once `exists == true`.
    var wheelchairAccessible: Bool?
    /// Only relevant when `wheelchairAccessible == false`; cleared client-side
    /// if the user flips back to `true`, mirroring the contract's
    /// "ifAccessibleTrue: strip blockers" rule.
    var blockers: Set<ElevatorBlocker> = []
    var review = ReviewNoteDraft()
}

// MARK: - Toilet

struct ToiletDraft {
    var hasDisabledToilet: Bool?
    var review = ReviewNoteDraft()
}

// MARK: - Shared review note

struct ReviewNoteDraft {
    /// Empty string is treated as "no text" (→ nil) at submit time, per contract.
    var text: String = ""
    /// In-memory only for this pass. TODO(backend): real flow uploads to
    /// Supabase Storage and the contract expects `photoUrls: [String]`.
    var photoImage: UIImage?
}

// MARK: - Wizard steps

enum ReviewStep: Int, CaseIterable {
    case lobbyRampsRails
    case lobbyDoor
    case lobbyNote
    case basementRampsRails
    case basementDoor
    case basementNote
    case elevatorPresence
    case elevatorWheelchair
    case elevatorNote
    case toiletPresence
    case toiletNote
    case submitted

    /// Steps counted by the progress bar (submission confirmation excluded).
    static var answerableSteps: [ReviewStep] {
        allCases.filter { $0 != .submitted }
    }
}
