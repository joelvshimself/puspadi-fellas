import SwiftUI

/// Notes from reviews card — empty CTA or latest review snippets.
struct NotesFromReviewsSection: View {
    let snippets: [String]
    var onBeFirstReviewer: () -> Void
    var onOpenReviews: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Notes from reviews".localized)
                .font(.system(size: 17, weight: .semibold))

            if snippets.isEmpty {
                VStack(alignment: .leading, spacing: 16) {
                    Text("No one review this place yet".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onBeFirstReviewer) {
                        Text("Be the first reviewer".localized)
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
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
    NotesFromReviewsSection(snippets: [], onBeFirstReviewer: {}, onOpenReviews: {})
        .padding()
}

#Preview("With snippets") {
    NotesFromReviewsSection(
        snippets: ["The entrance is quite hard to find.", "Buttons were too high."],
        onBeFirstReviewer: {},
        onOpenReviews: {}
    )
    .padding()
}
