import SwiftUI

/// Branded cold-launch splash: rotating ring/star over a static crescent mark.
/// Shown for 1 second before the main app content appears.
struct SplashScreenView: View {
    @State private var rotation: Double = 0
    @State private var isSpinning = false

    private static let rotationPeriod: TimeInterval = 2

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            ZStack {
                Image("Spla")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 143, height: 143)
                    .rotationEffect(.degrees(rotation))
                    .offset(y: -75)

                Image("Splash Subtract")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 147, height: 73)
                    .offset(y: -16)

                Text("RollSpot")
                    .font(Font(UIFont(name: "SFProDisplay-Bold", size: 40) ?? .systemFont(ofSize: 40, weight: .bold)))
                    .foregroundStyle(.black)
                    .offset(y: 60)
            }
        }
        .onAppear {
            isSpinning = true
            startSpinning()
        }
        .onDisappear {
            isSpinning = false
        }
    }

    private func startSpinning() {
        guard isSpinning else { return }
        withAnimation(.easeInOut(duration: Self.rotationPeriod)) {
            rotation += 360
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rotationPeriod) {
            startSpinning()
        }
    }
}

#Preview {
    SplashScreenView()
}
