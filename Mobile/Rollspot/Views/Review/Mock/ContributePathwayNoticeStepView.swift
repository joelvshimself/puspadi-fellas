import Shared
import SwiftUI

/// "What did you notice along the pathway?" — multi-select capsules.
/// "Nothing notable" clears the other rows, and any other row clears it.
struct ContributePathwayNoticeStepView: View {
    let progress: (current: Int, total: Int)
    var subStepProgress: CGFloat = 0.35
    @Binding var selection: Set<String>
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ContributeStepProgressBar(currentStep: 4, subStepProgress: subStepProgress)
                PhotoFlowHeader(title: "Outdoor Pathways".localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ContributeQuestionHeading(title: "What did you notice along the pathway?")
                        .padding(.top, 26)

                    Button {
                        showInfo = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Learn more about accessible pathways".localized)
                                .font(.system(size: 13, weight: .medium))
                                .underline()
                        }
                        .foregroundStyle(ContributePalette.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    VStack(spacing: ContributeQuestionMetrics.optionSpacing) {
                        ForEach(Self.options, id: \.self) { option in
                            ContributeOptionRow(title: option, isSelected: selection.contains(option)) { toggle(option) }
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showInfo) {
            PathwayInfoSheet()
        }
    }

    private func toggle(_ option: String) {
        if option == Self.nothingNotable {
            if selection.contains(option) {
                selection.remove(option)
            } else {
                selection = [option]
            }
        } else {
            selection.remove(Self.nothingNotable)
            if selection.contains(option) {
                selection.remove(option)
            } else {
                selection.insert(option)
            }
        }
    }

    static let nothingNotable = "Nothing notable"
    static let options = [
        "Loose gravel or sand",
        "Rough or uneven surface",
        "Tight gap",
        "Narrow pathway",
        "Steep section",
        "Curb or step with no ramp",
        nothingNotable,
    ]
}

/// The pathway pages come from the shared `PathwayInfoCatalog` (same copy on Android); only the
/// video file names are iOS's.
private extension Shared.PathwayInfoPage {
    var videoName: String { "PATHWAYS_\(videoKey.uppercased())" }
}

/// "Learn more about accessible pathways" (Figma): grey sheet, swipeable white video card,
/// SURFACES / WIDTH / OBSTRUCTIONS tabs, then the page copy and "What to avoid".
struct PathwayInfoSheet: View {
    @State private var page = 0
    private let pages = PathwayInfoCatalog.shared.pages

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PathwayVideoCarousel(page: $page, videos: pages.map(\.videoName))
                    .padding(.bottom, 2)

                HStack(spacing: 6) {
                    ForEach(Array(pages.enumerated()), id: \.offset) { index, item in
                        tab(item.chip, selected: page == index) {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.86)) { page = index }
                        }
                    }
                }

                pageCopy(pages[page])
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .presentationBackground(Color(designHex: 0xE8E8E8))
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private func tab(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.localized)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.3)
                .foregroundStyle(selected ? Color.white : Color(designHex: 0x3F3F3F))
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(selected ? ContributePalette.blue : Color.white, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
    }

    private func pageCopy(_ item: Shared.PathwayInfoPage) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title.localized)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ContributePalette.text)
            item.bodyRuns.reduce(Text("")) { text, run in
                text + Text(run.text.localized)
                    .fontWeight(run.bold ? .semibold : .regular)
                    .foregroundColor(run.bold ? Color(designHex: 0x4A4A4A) : Color(designHex: 0x666666))
            }
            .font(.system(size: 13))
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 5) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(designHex: 0xD9534F))
                Text("What to avoid:".localized)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(designHex: 0x5E5E5E))
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(item.avoid.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•")
                        (Text(point.lead.localized).fontWeight(.semibold).foregroundColor(Color(designHex: 0x4A4A4A))
                            + Text(point.rest.localized))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Color(designHex: 0x5D5D5D))
                    .padding(.leading, 4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PathwayVideoCarousel: View {
    @Binding var page: Int
    let videos: [String]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(videos.enumerated()), id: \.offset) { index, name in
                    PathwayVideoCard(resourceName: name, isActive: page == index)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: Binding(
            get: { page as Int? },
            set: { if let newValue = $0 { page = newValue } }
        ))
        .scrollIndicators(.hidden)
        .frame(height: ContributeQuestionMetrics.cardHeight)
    }
}

struct PathwayVideoCard: View {
    let resourceName: String
    let isActive: Bool
    @StateObject private var model = RampLoopPlayer()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LoopingPlayerView(player: model.player)
            ContributeCardPauseButton(isPlaying: model.isPlaying) { model.toggle() }
                .padding(4)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: ContributeQuestionMetrics.cardRadius, style: .continuous))
        .onAppear {
            model.start(resource: resourceName)
            model.setActive(isActive)
        }
        .onChange(of: isActive) { _, active in
            model.setActive(active)
        }
        .onDisappear { model.pause() }
    }
}
