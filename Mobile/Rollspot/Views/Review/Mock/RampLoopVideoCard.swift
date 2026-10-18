import AVFoundation
import SwiftUI
import UIKit

/// Looping follow-up animation with a pause control and an info sheet.
struct RampLoopVideoCard: View {
    let resourceName: String
    let infoTitle: String
    let infoSections: [(title: String, body: String)]
    @StateObject private var model = RampLoopPlayer()
    @State private var showInfo = false

    var body: some View {
        ZStack {
            LoopingPlayerView(player: model.player)
                .contentShape(Rectangle())
                .onTapGesture { showInfo = true }

            VStack {
                HStack {
                    Spacer()
                    overlayButton(systemName: model.isPlaying ? "pause.fill" : "play.fill") {
                        model.toggle()
                    }
                }
                Spacer()
                HStack {
                    Spacer()
                    overlayButton(systemName: "info", tint: .white, fill: Color.accentColor) {
                        showInfo = true
                    }
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        }
        .onAppear { model.start(resource: resourceName) }
        .onDisappear { model.pause() }
        .sheet(isPresented: $showInfo) {
            FollowUpInfoSheet(title: infoTitle, sections: infoSections)
        }
    }

    private func overlayButton(
        systemName: String,
        tint: Color = .primary,
        fill: Color = Color(.systemGray6),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(fill, in: Circle())
        }
        .buttonStyle(.plain)
    }
}

/// Still illustration in the same card as the looping videos, with the info sheet.
struct FollowUpStillCard: View {
    let imageName: String
    let infoTitle: String
    let infoSections: [(title: String, body: String)]
    @State private var showInfo = false

    var body: some View {
        ZStack {
            Image(imageName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)
                .contentShape(Rectangle())
                .onTapGesture { showInfo = true }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        showInfo = true
                    } label: {
                        Image(systemName: "info")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.accentColor, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color(.systemGray5), lineWidth: 1)
        }
        .sheet(isPresented: $showInfo) {
            FollowUpInfoSheet(title: infoTitle, sections: infoSections)
        }
    }
}

private struct FollowUpInfoSheet: View {
    let title: String
    let sections: [(title: String, body: String)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title2.bold())
                ForEach(Array(sections.enumerated()), id: \.offset) { _, item in
                    section(title: item.title, body: item.body)
                }
            }
            .padding(24)
            .padding(.top, 8)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
            }
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

private final class RampLoopPlayer: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    @Published var isPlaying = false

    func start(resource name: String) {
        guard looper == nil,
              let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        player.play()
        isPlaying = true
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            player.play()
            isPlaying = true
        }
    }

    func pause() {
        player.pause()
        isPlaying = false
    }
}

private struct LoopingPlayerView: UIViewRepresentable {
    let player: AVQueuePlayer

    func makeUIView(context: Context) -> PlayerHostView {
        let view = PlayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: PlayerHostView, context: Context) {
        uiView.playerLayer.player = player
    }
}

private final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
