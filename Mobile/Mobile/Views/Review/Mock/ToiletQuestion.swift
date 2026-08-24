import Foundation

/// Questions asked in the revamped Accessible Toilets review survey flow.
enum ToiletQuestion: String, CaseIterable, Identifiable, Hashable {
    case initial
    case doorKind
    case seat
    case grabBars
    case space
    case sink
    case emergency
    case locationNote

    var id: String { rawValue }

    var eyebrow: String {
        switch self {
        case .initial: ""
        case .doorKind: "Doors"
        case .seat: "Toilet Seat"
        case .grabBars: "Grab Bars"
        case .space: "Space to Maneuver"
        case .sink: "Sink Height"
        case .emergency: "Emergency Button"
        case .locationNote: ""
        }
    }

    var title: String {
        switch self {
        case .initial: "Does the mall have accessible toilets?"
        case .doorKind: "What kind of door does the toilet have?"
        case .seat: "Is the toilet seat easy to transfer to from your wheelchair?"
        case .grabBars: "Are the grab bars within reach of the toilet?"
        case .space: "Could you turn your wheelchair freely inside?"
        case .sink: "Could you reach the sink?"
        case .emergency: "Could you reach the emergency button from your wheelchair or fallen position?"
        case .locationNote: "Where is the accessible toilet?"
        }
    }

    var options: [String] {
        switch self {
        case .initial: ["Yes", "No", "Not sure"]
        case .doorKind: ["Manual", "Sliding", "Automatic"]
        case .seat: ["Yes", "Too low", "Too high", "Not sure"]
        case .grabBars: ["Yes", "Positioned awkwardly", "No", "Not sure"]
        case .space: ["Yes", "No", "Not sure"]
        case .sink: ["Yes", "No", "Not sure"]
        case .emergency: ["Yes", "No", "Not sure", "There is no emergency button"]
        case .locationNote: []
        }
    }

    var photoRevealOption: String? {
        switch self {
        case .seat, .grabBars, .space, .sink, .emergency: "Not sure"
        default: nil
        }
    }
}
