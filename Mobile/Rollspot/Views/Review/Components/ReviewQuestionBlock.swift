import SwiftUI

/// Card wrapper for a single question within a wizard step — title, optional
/// hint, and whatever control (YesNoPills, SelectionPills, ...) is passed in.
/// Reused multiple times per step (e.g. ramps/rails/ease-of-access stack 3 of
/// these on one screen).
struct ReviewQuestionBlock<Control: View>: View {
    let title: String
    var hint: String?
    @ViewBuilder let control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                if let hint {
                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            control
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

#Preview {
    ReviewQuestionBlock(title: "Any dropoff or ramps?", hint: "Look for a step-free path from the curb.") {
        YesNoPills(value: .constant(nil))
    }
    .padding()
}
