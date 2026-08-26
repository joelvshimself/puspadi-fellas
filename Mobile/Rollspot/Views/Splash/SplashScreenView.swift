import SwiftUI

/// Branded cold-launch splash: rotating ring/star over a static crescent mark.
/// Shown for 1 second after it is visible and the scene is active, then calls `onFinished`.
struct SplashScreenView: View {
    var onFinished: () -> Void = {}

    @Environment(\.scenePhase) private var scenePhase

    /// Wall-clock start of the visible spin. `nil` until the scene is active so
    /// cold launch doesn't burn the timer before anything is on screen — and
    /// rotation always begins at 0°.
    @State private var startDate: Date?

    private static let displayDuration: TimeInterval = 2
    private static let rotationPeriod: TimeInterval = 3

    var body: some View {
        TimelineView(
            .animation(
                minimumInterval: 1.0 / 60.0,
                paused: startDate == nil
            )
        ) { context in
            let elapsed = startDate.map { context.date.timeIntervalSince($0) } ?? 0
            let rotation = (elapsed / Self.rotationPeriod)
                .truncatingRemainder(dividingBy: 1) * 360

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
        }
        .task(id: scenePhase) {
            guard scenePhase == .active, startDate == nil else { return }
            // One frame after becoming active so layout/assets can paint first.
            await Task.yield()
            startDate = .now
            try? await Task.sleep(nanoseconds: UInt64(Self.displayDuration * 1_000_000_000))
            onFinished()
        }
    }
}

#Preview {
    SplashScreenView()
}
