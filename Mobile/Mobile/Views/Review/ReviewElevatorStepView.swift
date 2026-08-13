import SwiftUI

/// Steps 5-6 — elevator presence, then (if present) wheelchair fit + inline
/// blocker follow-up. Rendered by a single view via `phase`, same pattern as
/// ReviewLobbyBasementStepView.
struct ReviewElevatorStepView: View {
    enum Phase {
        case presence
        case wheelchairFit
    }

    let phase: Phase
    @Binding var elevator: ElevatorDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            switch phase {
            case .presence:
                presenceContent
            case .wheelchairFit:
                wheelchairFitContent
            }
        }
    }

    @ViewBuilder
    private var presenceContent: some View {
        Text("Elevator")
            .font(.title2.bold())
        ReviewQuestionBlock(title: "Is there an elevator?") {
            YesNoPills(value: $elevator.exists)
        }
    }

    @ViewBuilder
    private var wheelchairFitContent: some View {
        Text("Elevator")
            .font(.title2.bold())
        ReviewQuestionBlock(title: "Can a wheelchair get inside?") {
            YesNoPills(value: $elevator.wheelchairAccessible)
        }
        if elevator.wheelchairAccessible == false {
            ReviewQuestionBlock(title: "What's the issue?") {
                MultiSelectPills(options: ElevatorBlocker.allCases, label: \.label, selection: $elevator.blockers)
            }
        }
    }
}

#Preview {
    ReviewElevatorStepView(phase: .wheelchairFit, elevator: .constant(ElevatorDraft(exists: true, wheelchairAccessible: false)))
        .padding()
}
