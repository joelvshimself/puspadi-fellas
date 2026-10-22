import AVFoundation
import SwiftUI
import UIKit

/// Looping follow-up animation with a pause control and an info sheet.
struct RampLoopVideoCard: View {
    let resourceName: String
    let infoTitle: String
    let infoSections: [(title: String, body: String)]
    var infoVideoName: String? = nil
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
                    overlayButton(systemName: "info", tint: .white, fill: ContributePalette.blue) {
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
            FollowUpInfoSheet(title: infoTitle, sections: infoSections, videoName: infoVideoName)
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
                            .background(ContributePalette.blue, in: Circle())
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
    var videoName: String? = nil
    @StateObject private var model = RampLoopPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let videoName {
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
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .onAppear { model.start(resource: videoName) }
                    .onDisappear { model.pause() }
                }

                Text(title)
                    .font(.title2.bold())
                ForEach(Array(sections.enumerated()), id: \.offset) { _, item in
                    section(title: item.title, body: item.body)
                }
                if videoName != nil {
                    Divider()
                }
            }
            .padding(24)
            .padding(.top, 8)
        }
        .presentationBackground(videoName == nil ? Color(.systemBackground) : Color(.systemGray6))
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(videoName == nil ? Color.primary : Color.secondary)
            }
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
}

final class RampLoopPlayer: ObservableObject {
    let player = AVQueuePlayer()
    private var looper: AVPlayerLooper?
    private var resource: String?
    @Published var isPlaying = false

    func start(resource name: String) {
        guard resource != name else { return }
        resource = name
        looper = nil
        player.removeAllItems()
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp4") else { return }
        looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: url))
        play()
    }

    /// Plays the visible carousel page and rewinds the ones that scrolled away.
    func setActive(_ active: Bool) {
        if active {
            play()
        } else {
            pause()
            player.seek(to: .zero)
        }
    }

    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    func play() {
        player.play()
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }
}

struct LoopingPlayerView: UIViewRepresentable {
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

final class PlayerHostView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}
