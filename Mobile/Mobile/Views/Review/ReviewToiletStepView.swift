import SwiftUI

/// Step 7 — "Is there a disabled/accessible toilet?"
struct ReviewToiletStepView: View {
    @Binding var toilet: ToiletDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Toilet".localized)
                .font(.title2.bold())
            ReviewQuestionBlock(title: "Is there a disabled/accessible toilet?".localized) {
                YesNoPills(value: $toilet.hasDisabledToilet)
            }
        }
    }
}

#Preview {
    ReviewToiletStepView(toilet: .constant(ToiletDraft()))
        .padding()
}
