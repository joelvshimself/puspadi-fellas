import SwiftUI

/// The three tabs of a facility's detail screen. Only `.photos` is designed so
/// far (nodes 518:16038 / 572:6900 / 572:7071); see `FacilityPhotosView` for
/// what the other two currently render.
enum FacilityDetailTab: String, CaseIterable, Identifiable {
    case overview
    case reviews
    case photos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .reviews: "Reviews"
        case .photos: "Photos"
        }
    }
}

/// Pill segmented control from node 526:17120 — a grey track with a white
/// capsule under the selected tab and uppercase footnote labels.
struct FacilitySegmentedControl: View {
    @Binding var selection: FacilityDetailTab

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: PhotoMetrics.segmentedSpacing) {
            ForEach(FacilityDetailTab.allCases) { tab in
                segment(for: tab)
            }
        }
        .padding(PhotoMetrics.segmentedPadding)
        .background(Capsule().fill(PhotoPalette.segmentedTrack))
    }

    private func segment(for tab: FacilityDetailTab) -> some View {
        let isSelected = selection == tab
        return Button {
            withAnimation(.snappy(duration: 0.22)) { selection = tab }
        } label: {
            Text(tab.title.uppercased())
                .font(.system(size: PhotoMetrics.segmentedLabelSize, weight: .semibold))
                .tracking(PhotoMetrics.segmentedTracking)
                .foregroundStyle(PhotoPalette.primaryLabel)
                .frame(maxWidth: .infinity)
                .frame(height: PhotoMetrics.segmentedItemHeight)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(.white)
                            .matchedGeometryEffect(id: "selectedSegment", in: indicator)
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

#Preview {
    FacilitySegmentedControl(selection: .constant(.photos))
        .padding(PhotoMetrics.gutter)
}
