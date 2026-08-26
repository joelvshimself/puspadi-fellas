import Foundation

/// Review survey voice: first-person for wheelchair users, third-person for everyone else.
enum ReviewPersona {
    case wheelchair
    case everyone

    static func from(mobilityProfile: MobilityProfile?) -> ReviewPersona {
        mobilityProfile == .wheelchairUser ? .wheelchair : .everyone
    }

    static func from(aids: [String]?) -> ReviewPersona {
        from(mobilityProfile: MobilityProfile.from(aids: aids))
    }
}

/// Persona-specific question copy for the Contribute Review flow.
enum ReviewQuestionCopy {
    // MARK: Entrance follow-ups

    static func rampQuestion(for persona: ReviewPersona) -> String {
        switch persona {
        case .wheelchair:
            "Could you push your wheelchair up the ramp without help?"
        case .everyone:
            "Could someone using a wheelchair get up the ramp on their own?"
        }
    }

    static func rampOptions(for persona: ReviewPersona) -> [String] {
        switch persona {
        case .wheelchair:
            ["Yes", "With a push", "Too steep", "Not sure"]
        case .everyone:
            ["Yes", "With a push", "Too steep", "Not sure"]
        }
    }

    static func handrailQuestion(for persona: ReviewPersona) -> String {
        switch persona {
        case .wheelchair:
            "Could you reach and grip the handrail from your wheelchair?"
        case .everyone:
            "Could someone using a wheelchair reach and grip the handrail?"
        }
    }

    static let handrailOptions = ["Yes", "With effort", "No", "Not sure"]

    // MARK: Elevators

    static func elevatorTitle(for question: ElevatorQuestion, persona: ReviewPersona) -> String {
        question.title(for: persona)
    }

    static let elevatorOptions = ["Yes", "No", "Not sure"]

    // MARK: Toilets

    static let toiletInitialQuestion = "Does the mall have accessible toilets?"
    static let toiletInitialOptions = ["Yes", "No", "Not sure"]
}
