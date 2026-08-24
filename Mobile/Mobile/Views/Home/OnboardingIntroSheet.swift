import SwiftUI
import UIKit

/// The one-time intro shown over the home map right after signup, presented
/// as a sheet so it takes the same Liquid Glass the search sheet has.
/// No grabber and no background of its own — the sheet material is the look.
///
/// Layout from Figma node 697:10383 ("Sheet", 390pt frame): 350×350
/// illustration (= sheet width - 2×20), 20pt gaps between sections, title
/// SF bold 22 #2D2D2D, body 17 #5F5F5F at 346pt, button 244×50 #09F,
/// 32pt bottom padding.
struct OnboardingIntroSheet: View {
    var onExplore: () -> Void

    /// Which page is visible, driven by the paging scroll below. A ScrollView
    /// pager instead of `TabView(.page)`: the TabView kept a stale content
    /// offset when laid out inside a detent sheet and showed both pages
    /// half-on-screen.
    @State private var page: Int? = 0

    /// The illustration's inset on every side — the image spans the sheet
    /// width minus this padding left/right, and sits this far from the top.
    private static let edgePadding: CGFloat = 20

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    OnboardingIntroPage(
                        assetName: "Onboarding Map Asset",
                        framesIllustration: true,
                        title: "Know before you go".localized,
                        subtitle: "Find malls you can roll into and see real facilities, checked and confirmed by people who've actually been there.".localized,
                        edgePadding: Self.edgePadding
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(0)

                    OnboardingIntroPage(
                        assetName: "Onboarding Contribute Asset",
                        framesIllustration: false,
                        title: "Your visit might be their answer".localized,
                        subtitle: "A photo, a few tags, and a quick note. That's all it takes to help the next person roll everywhere with ease.".localized,
                        edgePadding: Self.edgePadding
                    )
                    .containerRelativeFrame(.horizontal)
                    .id(1)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $page)
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    Circle()
                        .fill(index == (page ?? 0) ? Color.primary : Color.gray.opacity(0.35))
                        .frame(width: 7, height: 7)
                }
            }
            .padding(.top, 20)
            .animation(.easeInOut(duration: 0.2), value: page)

            Button(action: onExplore) {
                Text("Explore Malls".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.43)
                    .foregroundStyle(.white)
                    .frame(width: 244, height: 50)
                    .background(Capsule().fill(SheetPalette.brandBlue))
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }
}

/// The sheet exactly as HomeMapView presents it — same detent, no grabber —
/// over a stand-in for the map so the glass has something to blur.
#Preview("In sheet") {
    LinearGradient(
        colors: [Color(red: 0.72, green: 0.88, blue: 1.0), Color(red: 0.55, green: 0.75, blue: 0.6)],
        startPoint: .top,
        endPoint: .bottom
    )
    .ignoresSafeArea()
    .sheet(isPresented: .constant(true)) {
        OnboardingIntroSheet(onExplore: {})
            .presentationDetents([.fraction(0.81)])
            .presentationDragIndicator(.hidden)
            .interactiveDismissDisabled()
    }
    .environmentObject(LanguageManager.shared)
}

/// Just the content, full screen — handy for tweaking paddings with the
/// preview canvas's inspector.
#Preview("Content only") {
    OnboardingIntroSheet(onExplore: {})
        .environmentObject(LanguageManager.shared)
}

private struct OnboardingIntroPage: View {
    let assetName: String
    let framesIllustration: Bool
    let title: String
    let subtitle: String
    let edgePadding: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            // A square container the image FILLS; the padding lives on the
            // container, so it positions the box without resizing the image
            // inside it. Top inset matches the side insets.
            illustrationContainer
                .padding(.horizontal, edgePadding)
                .padding(.top, edgePadding)
                // Sized FIRST: the box gets the full width-driven square and
                // the Spacer below only keeps its minimum — without this the
                // VStack splits the flexible height between them and the
                // square shrinks off the sheet's edges.
                .layoutPriority(1)

            // Flexible: any leftover height lands HERE, pushing the text
            // toward the dots so the image keeps its full width-to-width
            // square, like the mock.
            Spacer(minLength: 20)

            Text(title)
                .font(.system(size: 22, weight: .bold))
                .tracking(-0.26)
                .foregroundStyle(Color(red: 0.176, green: 0.176, blue: 0.176))
                // Never compressed by the flexible siblings — full text always
                // renders; only the Spacer above gives way.
                .fixedSize(horizontal: false, vertical: true)

            Text(subtitle)
                .font(.system(size: 17))
                .tracking(-0.43)
                .foregroundStyle(Color(red: 0.373, green: 0.373, blue: 0.373))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 10)
                .fixedSize(horizontal: false, vertical: true)

        }
        .frame(maxWidth: .infinity)
    }

    /// Width-to-width square, like the mock: `aspectRatio(1, .fit)` sizes the
    /// box from the width the padding leaves it (shrinking square only if the
    /// sheet ever runs out of height), and the square image fills it exactly.
    /// The image is an overlay so it can never change the box; clip + border
    /// are drawn on the box, whose bounds ARE the artwork's bounds here.
    @ViewBuilder
    private var illustrationContainer: some View {
        Color.clear
            .frame(maxWidth: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .overlay { illustrationFill }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                // Only the map export needs a code-drawn border — the second
                // page's asset has its frame baked into the PNG.
                if framesIllustration {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(red: 0.231, green: 0.231, blue: 0.231), lineWidth: 1.5)
                }
            }
    }

    @ViewBuilder
    private var illustrationFill: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
                .scaledToFill()
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.gray.opacity(0.08))
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "photo")
                            .font(.system(size: 32))
                            .foregroundStyle(.tertiary)
                        Text(assetName)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.gray.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                )
        }
    }
}
