import Foundation

/// Questions asked in the Accessible Toilets review survey.
enum ToiletQuestion: String, CaseIterable, Identifiable, Hashable {
    case doorKind
    case seat
    case grabBars
    case space
    case sink
    case emergency

    var id: String { rawValue }

    var eyebrow: String {
        switch self {
        case .doorKind: "Doors"
        case .seat: "Toilet Seat"
        case .grabBars: "Grab Bars"
        case .space: "Space to Maneuver"
        case .sink: "Sink"
        case .emergency: "Emergency Aid"
        }
    }

    func title(for persona: ReviewPersona) -> String {
        switch self {
        case .doorKind:
            "What kind of door does the toilet have?"
        case .seat:
            "Is the toilet seat easy to transfer to from your wheelchair?"
        case .grabBars:
            "Are the grab bars within reach of the toilet?"
        case .space:
            switch persona {
            case .wheelchair:
                "Could you turn your wheelchair freely inside?"
            case .everyone:
                "Could someone in a wheelchair turn freely inside?"
            }
        case .sink:
            switch persona {
            case .wheelchair:
                "Could you reach the sink?"
            case .everyone:
                "Can someone in a wheelchair reach the sink faucet comfortably?"
            }
        case .emergency:
            switch persona {
            case .wheelchair:
                "Could you reach the emergency aid from your wheelchair or fallen position?"
            case .everyone:
                "Could you reach the emergency aid from a seated or fallen position?"
            }
        }
    }

    func options(for persona: ReviewPersona) -> [String] {
        switch self {
        case .doorKind:
            ["Manual", "Sliding", "Automatic"]
        case .seat:
            ["Yes", "Too low", "Too high", "Not sure"]
        case .grabBars:
            ["Yes", "Positioned awkwardly", "No", "Not sure"]
        case .space, .sink:
            ["Yes", "No", "Not sure"]
        case .emergency:
            ["Yes", "No", "Not sure", "There is no emergency button"]
        }
    }

    func photoRevealOption(for _: ReviewPersona) -> String? {
        switch self {
        case .seat, .grabBars, .space, .sink, .emergency:
            "Not sure"
        case .doorKind:
            nil
        }
    }

    var loopingVideoName: String? {
        switch self {
        case .doorKind: "TOILET_DOORS"
        case .seat: "TOILET_TOILET_SEAT"
        case .grabBars: "TOILET_GRAB_BARS"
        case .space: "TOILET_SPACE_TO_MANEUVER"
        case .sink: "TOILET_SINK"
        case .emergency: nil
        }
    }

    /// Still illustration used when this question has no video.
    var stillImageName: String? {
        switch self {
        case .emergency: "Emergency Toilet"
        default: nil
        }
    }

    var videoInfoTitle: String {
        switch self {
        case .doorKind: "Doors"
        case .seat: "Toilet Seat"
        case .grabBars: "Grab Bars"
        case .space: "Space to Maneuver"
        case .sink: "Sink"
        case .emergency: "Emergency Aid"
        }
    }

    var videoInfoSections: [(title: String, body: String)] {
        switch self {
        case .doorKind:
            [
                ("Manual", "Manual doors require users to reach out the handles and push/pull. Heavier doors make it harder to navigate to spaces."),
                ("Sliding/Automatic", "Sliding doors are much easier to use as they don't obstruct wheelchairs like pulling a door or require someone seated to lean forward to push. Automatic doors remove that effort entirely."),
            ]
        case .seat:
            [
                ("Height", "Toilet seats at wheelchair height make it easier to transfer to. Seats that are too low or too high may affect balance."),
            ]
        case .grabBars:
            [
                ("Height", "Mounted around waist height when seated, not up near shoulder height."),
                ("Placement", "Beside the toilet within arm's reach while seated, not across the room."),
            ]
        case .space:
            [
                ("Space", "Enough room to enter, close the door, and turn a full circle without hitting the door, toilet, or sink."),
            ]
        case .sink:
            [
                ("Reach", "Faucet and soap dispenser is operable without a strong grip or twisting motion."),
                ("Clearance", "Open space underneath so a wheelchair can roll up close and not be blocked by a cabinet."),
            ]
        case .emergency:
            [
                ("Reach", "Emergency aids can be in the form of buttons or pulleys and should be accessible from a seated or fallen position."),
            ]
        }
    }
}
