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

    func title(for persona: ReviewPersona) -> String {
        switch self {
        case .initial:
            ReviewQuestionCopy.toiletInitialQuestion
        case .doorKind:
            "What kind of door does the toilet have?"
        case .seat:
            switch persona {
            case .wheelchair:
                "Is the toilet seat easy to transfer to from your wheelchair?"
            case .everyone:
                "Is the toilet seat easy to transfer to from a wheelchair?"
            }
        case .grabBars:
            "Are the grab bars within reach of the toilet?"
        case .space:
            switch persona {
            case .wheelchair:
                "Could you turn your wheelchair freely inside?"
            case .everyone:
                "Could someone turn their wheelchair freely inside?"
            }
        case .sink:
            switch persona {
            case .wheelchair:
                "Could you reach the sink?"
            case .everyone:
                "Could someone in a wheelchair reach the sink?"
            }
        case .emergency:
            switch persona {
            case .wheelchair:
                "Could you reach the emergency button from your wheelchair or fallen position?"
            case .everyone:
                "Could someone reach the emergency button from a seated or fallen position?"
            }
        case .locationNote:
            "Where is the accessible toilet?"
        }
    }

    func options(for persona: ReviewPersona) -> [String] {
        switch self {
        case .initial:
            ReviewQuestionCopy.toiletInitialOptions
        case .doorKind:
            ["Manual", "Sliding", "Automatic"]
        case .seat:
            switch persona {
            case .wheelchair:
                ["Yes", "No", "Not sure"]
            case .everyone:
                ["Yes", "Too low", "Too high", "Not sure"]
            }
        case .grabBars:
            switch persona {
            case .wheelchair:
                ["Yes", "Positioned awkwardly", "No"]
            case .everyone:
                ["Yes", "Positioned awkwardly", "Not sure"]
            }
        case .space, .sink:
            ["Yes", "No", "Not sure"]
        case .emergency:
            ["Yes", "No", "Not sure", "There is no emergency button"]
        case .locationNote:
            []
        }
    }

    func photoRevealOption(for persona: ReviewPersona) -> String? {
        switch self {
        case .seat, .space, .sink, .emergency:
            "Not sure"
        case .grabBars:
            persona == .everyone ? "Not sure" : nil
        default:
            nil
        }
    }
}
