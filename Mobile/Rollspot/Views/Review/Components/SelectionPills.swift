import SwiftUI

/// Single-select row of capsule pills, for both custom enum choices and the
/// Yes/No questions (via `YesNoPills` below).
struct SelectionPills<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option?

    var body: some View {
        FlowRow(spacing: 10) {
            ForEach(options) { option in
                pill(for: option)
            }
        }
    }

    private func pill(for option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            selection = isSelected ? nil : option
        } label: {
            Text(label(option))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Multi-select variant, used for door attributes / elevator blockers.
struct MultiSelectPills<Option: Identifiable & Hashable>: View {
    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Set<Option>

    var body: some View {
        FlowRow(spacing: 10) {
            ForEach(options) { option in
                pill(for: option)
            }
        }
    }

    private func pill(for option: Option) -> some View {
        let isSelected = selection.contains(option)
        return Button {
            if isSelected {
                selection.remove(option)
            } else {
                selection.insert(option)
            }
        } label: {
            Text(label(option))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Yes/No pill pair bound directly to `Bool?` (nil = unanswered, matches the
/// backend contract's tri-state fields exactly).
struct YesNoPills: View {
    @Binding var value: Bool?

    var body: some View {
        HStack(spacing: 10) {
            pill(title: "Yes", isSelected: value == true) {
                value = (value == true) ? nil : true
            }
            pill(title: "No", isSelected: value == false) {
                value = (value == false) ? nil : false
            }
        }
    }

    private func pill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor : Color(.secondarySystemBackground))
                )
        }
        .buttonStyle(.plain)
    }
}

/// Minimal wrapping HStack — options never exceed a handful of short labels,
/// so a simple wrap (rather than pulling in a layout package) keeps pills
/// from clipping on narrow devices.
struct FlowRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxAllowedWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var currentRowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxAllowedWidth, height: nil))
            let itemWidth = min(size.width, maxAllowedWidth)

            if currentX + itemWidth > maxAllowedWidth, currentX > 0 {
                currentY += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }

            currentX += itemWidth + spacing
            currentRowHeight = max(currentRowHeight, size.height)
            maxRowWidth = max(maxRowWidth, currentX - spacing)
        }

        let totalHeight = currentY + currentRowHeight
        let finalWidth = proposal.width ?? maxRowWidth
        return CGSize(width: finalWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxAllowedWidth = bounds.width
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: maxAllowedWidth, height: nil))
            let itemWidth = min(size.width, maxAllowedWidth)

            if currentX + itemWidth > bounds.maxX, currentX > bounds.minX {
                currentX = bounds.minX
                currentY += currentRowHeight + spacing
                currentRowHeight = 0
            }

            subview.place(
                at: CGPoint(x: currentX, y: currentY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: itemWidth, height: size.height)
            )

            currentX += itemWidth + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        YesNoPills(value: .constant(true))
        MultiSelectPills(options: ElevatorBlocker.allCases, label: \.label, selection: .constant([.tooSmall]))
    }
    .padding()
}
