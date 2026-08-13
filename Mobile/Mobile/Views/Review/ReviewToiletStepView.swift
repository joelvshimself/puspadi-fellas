import SwiftUI

/// Step 7 — "Is there a disabled/accessible toilet?"
struct ReviewToiletStepView: View {
    @Binding var toilet: ToiletDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Toilet")
                .font(.title2.bold())
            ReviewQuestionBlock(title: "Is there a disabled/accessible toilet?") {
                YesNoPills(value: $toilet.hasDisabledToilet)
            }
        }
    }
}

#Preview {
    ReviewToiletStepView(toilet: .constant(ToiletDraft()))
        .padding()
}
