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
                PhotoFlowHeader(title: "Outdoor Pathways".localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: 4, subStepProgress: subStepProgress)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("What did you notice along the pathway?".localized)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showInfo = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Learn more about accessible pathways".localized)
                                .font(.subheadline.weight(.semibold))
                                .underline()
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 12) {
                        ForEach(Self.options, id: \.self) { option in
                            noticeRow(option)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showInfo) {
            PathwayInfoSheet()
        }
    }

    private func noticeRow(_ option: String) -> some View {
        let isSelected = selection.contains(option)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                toggle(option)
            }
        } label: {
            Text(option.localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
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

/// Mirrors `PathwayInfoCatalog` in the shared module.
struct PathwayInfoPage: Identifiable {
    let id: String
    let chip: String
    let title: String
    let body: String
    let avoid: [(lead: String, rest: String)]
    let videoName: String

    static let all: [PathwayInfoPage] = [
        PathwayInfoPage(
            id: "surfaces",
            chip: "SURFACES",
            title: "Surfaces",
            body: "For wheelchairs and people with limited mobility, firm and smooth surfaces provide more support and balance.",
            avoid: [
                ("Loose material like gravel or sand", " lets wheels sink and shifts under the foot."),
                ("Rough or uneven surfaces", " such as broken ground, cracked surfaces, and tree roots will get caught in wheels."),
            ],
            videoName: "PATHWAYS_SURFACES"
        ),
        PathwayInfoPage(
            id: "width",
            chip: "WIDTH",
            title: "Width",
            body: "Wide, unobstructed pathways allow people on wheels, strollers, and mobility aids to pass through comfortably.",
            avoid: [
                ("Narrow pathways", " would let wheelchairs ride off the edge."),
                ("Tight gaps", " between obstacles."),
            ],
            videoName: "PATHWAYS_WIDTH"
        ),
        PathwayInfoPage(
            id: "obstructions",
            chip: "OBSTRUCTIONS",
            title: "Obstructions",
            body: "Curbs and steps without a ramp block wheelchairs and strollers.",
            avoid: [
                ("Curbs or steps with no ramp", " stop a wheelchair at the edge."),
                ("Objects blocking the path", " force a detour or a turn-around."),
            ],
            videoName: "PATHWAYS_OBSTRUCTIONS"
        ),
    ]
}

struct PathwayInfoSheet: View {
    @State private var page = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PathwayVideoCarousel(page: $page)

                HStack(spacing: 8) {
                    ForEach(Array(PathwayInfoPage.all.enumerated()), id: \.offset) { index, item in
                        chip(item.chip, selected: page == index) {
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                                page = index
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                pageCopy(PathwayInfoPage.all[page])
                    .id(page)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .presentationDetents([.large])
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(selected ? Color.white : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(selected ? Color.accentColor : Color(.systemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func pageCopy(_ item: PathwayInfoPage) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.title)
                .font(.title.bold())
            Text(item.body)
                .font(.body)
                .foregroundStyle(.primary)
            Label("What to avoid:", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.primary)
                .labelStyle(.titleAndIcon)
                .tint(.red)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(item.avoid.enumerated()), id: \.offset) { _, point in
                    (Text("•  ").foregroundStyle(.primary)
                        + Text(point.lead).bold()
                        + Text(point.rest))
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PathwayVideoCarousel: View {
    @Binding var page: Int

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(PathwayInfoPage.all.enumerated()), id: \.offset) { index, item in
                    PathwayVideoCard(resourceName: item.videoName, isActive: page == index)
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
        .frame(height: 210)
    }
}

private struct PathwayVideoCard: View {
    let resourceName: String
    let isActive: Bool
    @StateObject private var model = RampLoopPlayer()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            LoopingPlayerView(player: model.player)
            Button {
                model.toggle()
            } label: {
                Image(systemName: model.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 32, height: 32)
                    .background(Color(.systemGray6), in: Circle())
            }
            .buttonStyle(.plain)
            .padding(10)
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
