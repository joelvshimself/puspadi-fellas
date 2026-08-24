import SwiftUI

/// Notes from reviews card — latest review snippets, or a quiet per-facility
/// empty line. (The big blue CTA that used to live here is gone: a place with
/// no contributions at all shows the dedicated "Know something about the
/// place?" state instead, and the floating CONTRIBUTE pill covers the rest.)
struct NotesFromReviewsSection: View {
    let snippets: [String]
    var onOpenReviews: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes from reviews".localized)
                .font(.system(size: 17, weight: .semibold))

            if snippets.isEmpty {
                Text("No notes for this facility yet".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.mockSectionBackground)
                    )
            } else {
                // TODO(ai): cluster note topics and show an AI summary above the three snippets
                VStack(spacing: 0) {
                    ForEach(Array(snippets.enumerated()), id: \.offset) { index, note in
                        if index > 0 { Divider().padding(.leading, 16) }
                        Button(action: onOpenReviews) {
                            HStack {
                                Text(note)
                                    .font(.system(size: 15))
                                    .multilineTextAlignment(.leading)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            // Whole row tappable: without this only the text
                            // and chevron pixels hit — the transparent Spacer
                            // stretch in the middle was a dead zone.
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.mockSectionBackground)
                )
            }
        }
    }
}

#Preview("Empty") {
    NotesFromReviewsSection(snippets: [], onOpenReviews: {})
        .padding()
}

#Preview("With snippets") {
    NotesFromReviewsSection(
        snippets: ["The entrance is quite hard to find.", "Buttons were too high."],
        onOpenReviews: {}
    )
    .padding()
}
