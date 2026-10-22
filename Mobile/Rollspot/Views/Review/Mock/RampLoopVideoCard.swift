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
                    ContributeCardPauseButton(isPlaying: model.isPlaying) { model.toggle() }
                }
                Spacer()
                HStack {
                    Spacer()
                    ContributeCardInfoButton { showInfo = true }
                }
            }
            .padding(4)
        }
        .contributeIllustrationCard()
        .onAppear { model.start(resource: resourceName) }
        .onDisappear { model.pause() }
        .sheet(isPresented: $showInfo) {
            FollowUpInfoSheet(title: infoTitle, sections: infoSections, videoName: infoVideoName)
        }
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
                    ContributeCardInfoButton { showInfo = true }
                }
            }
            .padding(4)
        }
        .contributeIllustrationCard()
        .sheet(isPresented: $showInfo) {
            FollowUpInfoSheet(title: infoTitle, sections: infoSections)
        }
    }
}

/// Explanation sheet behind the card's "i" (Figma: grey sheet, white card with the loop, then
/// title, sub-headings and body copy).
private struct FollowUpInfoSheet: View {
    let title: String
    let sections: [(title: String, body: String)]
    var videoName: String? = nil
    @StateObject private var model = RampLoopPlayer()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let videoName {
                    LoopingPlayerView(player: model.player)
                        .overlay(alignment: .topTrailing) {
                            ContributeCardPauseButton(isPlaying: model.isPlaying) { model.toggle() }
                                .padding(4)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 220)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .onAppear { model.start(resource: videoName) }
                        .onDisappear { model.pause() }
                        .padding(.bottom, 6)
                }

                Text(title.localized)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ContributePalette.text)
                ForEach(Array(sections.enumerated()), id: \.offset) { _, item in
                    section(title: item.title, body: item.body)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .presentationBackground(Color(designHex: 0xE8E8E8))
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title.localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(designHex: 0x575757))
            }
            Text(body.localized)
                .font(.system(size: 13))
                .foregroundStyle(Color(designHex: 0x5D5D5D))
                .fixedSize(horizontal: false, vertical: true)
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

/// The white card around a question's illustration or loop (Figma: 262pt, 16pt corners, hairline).
extension View {
    func contributeIllustrationCard() -> some View {
        let shape = RoundedRectangle(cornerRadius: ContributeQuestionMetrics.cardRadius, style: .continuous)
        return self
            .frame(maxWidth: .infinity)
            .frame(height: ContributeQuestionMetrics.cardHeight)
            .background(Color.white)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Color(designHex: 0xF0F0F0), lineWidth: 1) }
    }
}

/// Small grey pause/play dot, top-right of the card. The hit area is larger than the dot.
struct ContributeCardPauseButton: View {
    let isPlaying: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Color(designHex: 0x8E8E93))
                .frame(width: 22, height: 22)
                .background(ContributePalette.circleButton, in: Circle())
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel((isPlaying ? "Pause" : "Play").localized)
    }
}

/// Small blue "i", bottom-right of the card: opens the explanation sheet.
struct ContributeCardInfoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "info")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(ContributePalette.blue, in: Circle())
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("More information".localized)
    }
}
