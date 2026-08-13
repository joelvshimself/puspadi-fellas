import SwiftUI

/// Lobby entrance and Basement entrance are both always asked, back to back
/// (not a user choice) — matches the backend's example payload, which
/// submits both as separate `entrances[]` items. Both locations ask the same
/// ramps/rails/door questions, so this single view renders either location's
/// `.rampsRails`/`.door` phase via parameters rather than 4 near-duplicate
/// files.
struct ReviewLobbyBasementStepView: View {
    enum Phase {
        case rampsRails
        case door
    }

    let phase: Phase
    @Binding var entrance: EntranceDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(entrance.location.stepTitle)
                .font(.title2.bold())

            switch phase {
            case .rampsRails:
                rampsRailsContent
            case .door:
                doorContent
            }
        }
    }

    @ViewBuilder
    private var rampsRailsContent: some View {
        ReviewQuestionBlock(title: "Any dropoff or ramps?", hint: "Look for a step-free path from the curb.") {
            YesNoPills(value: $entrance.hasDropoffRamp)
        }
        ReviewQuestionBlock(title: "Is there a rails?") {
            YesNoPills(value: $entrance.hasRails)
        }
        ReviewQuestionBlock(title: "How easy is it to go through?") {
            SelectionPills(options: EaseOfAccess.allCases, label: \.label, selection: $entrance.easeOfAccess)
        }
    }

    @ViewBuilder
    private var doorContent: some View {
        ReviewQuestionBlock(title: "Door entrance", hint: "What kind of door is it?") {
            SelectionPills(options: DoorType.allCases, label: \.label, selection: $entrance.doorType)
        }
        ReviewQuestionBlock(title: "Is it wide enough for a wheelchair?") {
            YesNoPills(value: $entrance.isWideEnough)
        }
    }
}

#Preview {
    ReviewLobbyBasementStepView(phase: .rampsRails, entrance: .constant(EntranceDraft(location: .lobby)))
        .padding()
}
