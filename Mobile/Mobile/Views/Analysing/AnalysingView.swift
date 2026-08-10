import SwiftUI

struct AnalysingView: View {
    let onDismiss: () -> Void

    @State private var pulse = false
    @State private var orbit = false
    @State private var statusIndex = 0

    private let statuses = [
        "Analysing accessibility…",
        "Reading recent clips…",
        "Matching places nearby…"
    ]

    private let cardOffsets: [(CGFloat, CGFloat, Double)] = [
        (-110, -130, -12),
        (115, -100, 10),
        (-120, 110, 8),
        (105, 125, -14)
    ]

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            TimelineView(.animation(minimumInterval: 1 / 30)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    ForEach(0..<cardOffsets.count, id: \.self) { index in
                        floatingCard(index: index, time: t)
                    }
                }
            }

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulse ? 1.12 : 0.92)
                        .opacity(pulse ? 0.55 : 0.9)

                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 88, height: 88)
                        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)

                    Image(systemName: "sparkles")
                        .font(.system(size: 34, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .symbolEffect(.pulse, options: .repeating, value: pulse)
                }

                VStack(spacing: 8) {
                    Text(statuses[statusIndex])
                        .font(.headline)
                        .multilineTextAlignment(.center)

                    Text("This may take a moment")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 32)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .padding(20)
            .accessibilityLabel("Close")
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                orbit = true
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.2))
                guard !Task.isCancelled else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    statusIndex = (statusIndex + 1) % statuses.count
                }
            }
        }
    }

    private func floatingCard(index: Int, time: TimeInterval) -> some View {
        let base = cardOffsets[index]
        let bob = sin(time * 1.4 + Double(index)) * 10
        let sway = cos(time * 1.1 + Double(index) * 0.7) * 8

        return RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemBackground))
            .frame(width: 72, height: 88)
            .overlay {
                Image(systemName: cardSymbol(index))
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)
            .rotationEffect(.degrees(base.2 + (orbit ? 6 : 0)))
            .offset(x: base.0 + sway, y: base.1 + bob)
            .opacity(0.95)
    }

    private func cardSymbol(_ index: Int) -> String {
        ["figure.roll", "building.2.fill", "map.fill", "video.fill"][index]
    }
}

#Preview {
    AnalysingView(onDismiss: {})
}
