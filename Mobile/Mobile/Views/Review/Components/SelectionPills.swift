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
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth + size.width > maxWidth, rowWidth > 0 {
                totalHeight += rowHeight + spacing
                rowWidth = 0
                rowHeight = 0
            }
            rowWidth += size.width + (rowWidth > 0 ? spacing : 0)
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? rowWidth : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), anchor: .topLeading, proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
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
