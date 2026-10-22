import PhotosUI
import SwiftUI

// Building blocks of every contribute question screen, measured from the Figma frames
// (Entrance, Elevators, Toilets, Seating, Parking). Android: ContributeQuestionComponents.kt.

enum ContributeQuestionMetrics {
    /// Illustration card (video or still) on question screens.
    static let cardHeight: CGFloat = 262
    static let cardRadius: CGFloat = 16
    /// Plain illustrations (location, tags, "review another?", "where is it?").
    static let illustrationHeight: CGFloat = 118
    /// Answer rows.
    static let optionHeight: CGFloat = 46
    static let optionSpacing: CGFloat = 8
    /// Photo tiles everywhere in the flow.
    static let photoTile: CGFloat = 142
}

/// Eyebrow (small grey), question (20pt semibold) and an optional hint line.
struct ContributeQuestionHeading<Trailing: View>: View {
    var eyebrow: String = ""
    let title: String
    var subtitle: String = ""
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !eyebrow.isEmpty {
                Text(eyebrow.localized)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(designHex: 0x5C5C5C))
            }
            HStack(alignment: .top, spacing: 12) {
                Text(title.localized)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ContributePalette.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                trailing()
            }
            if !subtitle.isEmpty {
                Text(subtitle.localized)
                    .font(.system(size: 13))
                    .foregroundStyle(ContributePalette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension ContributeQuestionHeading where Trailing == EmptyView {
    init(eyebrow: String = "", title: String, subtitle: String = "") {
        self.init(eyebrow: eyebrow, title: title, subtitle: subtitle, trailing: { EmptyView() })
    }
}

/// A plain (card-less) illustration at the design's height.
struct ContributeIllustration: View {
    let name: String
    var height: CGFloat = ContributeQuestionMetrics.illustrationHeight

    var body: some View {
        Image(name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(height: height)
            .frame(maxWidth: .infinity)
    }
}

/// One answer: a 46pt grey pill; selected turns white with a blue outline and blue text.
struct ContributeOptionRow: View {
    let title: String
    let isSelected: Bool
    var leadingSymbol: String? = nil
    /// Location rows show a filled radio dot on the right when selected.
    var showsRadio: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if let leadingSymbol {
                    Image(systemName: leadingSymbol)
                        .font(.system(size: 15, weight: .medium))
                        .frame(width: 18)
                }
                Text(title.localized)
                    .font(.system(size: 15, weight: .medium))
                Spacer(minLength: 8)
                if showsRadio && isSelected {
                    Image(systemName: "largecircle.fill.circle")
                        .font(.system(size: 17, weight: .medium))
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .foregroundStyle(isSelected ? ContributePalette.blue : Color(designHex: 0x3E4042))
            .padding(.horizontal, 16)
            .frame(height: ContributeQuestionMetrics.optionHeight)
            .background(isSelected ? Color.white : ContributePalette.fill, in: Capsule())
            .overlay {
                Capsule().strokeBorder(ContributePalette.blue.opacity(isSelected ? 1 : 0), lineWidth: 1.5)
            }
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// "Review another …?" answers: light pills with blue text; the tapped one fills blue.
struct ContributeChoiceButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.localized)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : ContributePalette.blue)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(isSelected ? ContributePalette.blue : ContributePalette.fill, in: Capsule())
                .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Add Photos tile + photos: Choose Existing / Take New Photo, tap a photo to caption it, ✕ to remove.
/// Empty, the tile spans the width; with photos it becomes the first square of a strip.
struct ContributePhotoStrip: View {
    enum Style {
        /// "Take or upload a photo" screens: grey box.
        case box
        /// Revealed under a "Not sure" answer and on the notes step: light box.
        case reveal
    }

    @Binding var note: ReviewNoteDraft
    var limit: Int = ReviewNoteDraft.maxPhotos
    var style: Style = .reveal
    /// Insets of the parent, so the strip can run to the screen edges.
    var edgeInset: CGFloat = 20

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showPicker = false
    @State private var showCamera = false
    @State private var showOptions = false
    @State private var captioning: ReviewPhotoDraft?

    private var tile: CGFloat { ContributeQuestionMetrics.photoTile }
    private var canAdd: Bool { note.photos.count < limit }
    private var fill: Color { style == .box ? Color(designHex: 0xE9EDF0) : ContributePalette.fill }
    private var dash: Color { style == .box ? Color(designHex: 0xC9CED4) : ContributePalette.dash }

    var body: some View {
        Group {
            if note.photos.isEmpty {
                addTile(wide: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if canAdd { addTile(wide: false) }
                        ForEach(note.photos) { photo in
                            thumbnail(photo)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, edgeInset)
                }
                .padding(.horizontal, -edgeInset)
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItems, maxSelectionCount: max(limit - note.photos.count, 0), matching: .images)
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task {
                for item in items {
                    guard note.photos.count < limit else { break }
                    if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                        add(image)
                    }
                }
                pickerItems = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(onCapture: { image in add(image); showCamera = false }, onCancel: { showCamera = false })
                .ignoresSafeArea()
        }
        .fullScreenCover(item: $captioning) { photo in
            PhotoCaptionEditorView(
                photo: photo,
                onSave: { note.updatePhotoCaption(id: photo.id, caption: $0) },
                onDismiss: { captioning = nil }
            )
        }
    }

    private func add(_ image: UIImage) {
        withAnimation(.easeOut(duration: 0.2)) { note.addPhoto(from: image, limit: limit) }
    }

    private func addTile(wide: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            showOptions.toggle()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 22, weight: .medium))
                Text("Add Photos".localized)
                    .font(.system(size: 17, weight: .medium))
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(ContributePalette.blue)
            .frame(width: wide ? nil : tile, height: tile)
            .frame(maxWidth: wide ? .infinity : nil)
            .background(fill, in: shape)
            .overlay { shape.strokeBorder(dash, style: StrokeStyle(lineWidth: 1, dash: [4, 4])) }
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!canAdd)
        .opacity(canAdd ? 1 : 0.4)
        .popover(isPresented: $showOptions, attachmentAnchor: .point(.center), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 16) {
                option("Choose Existing", "photo.on.rectangle") { showOptions = false; showPicker = true }
                if CameraPicker.isAvailable {
                    option("Take New Photo", "camera") { showOptions = false; showCamera = true }
                }
            }
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func option(_ title: String, _ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.system(size: 16, weight: .medium))
                Text(title.localized).font(.system(size: 15))
            }
            .foregroundStyle(ContributePalette.text)
        }
        .buttonStyle(.plain)
    }

    private func thumbnail(_ photo: ReviewPhotoDraft) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            captioning = photo
        } label: {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: tile, height: tile)
                .clipShape(shape)
                .overlay(alignment: .bottomLeading) {
                    if !photo.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.75), in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .padding(8)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { note.removePhoto(id: photo.id) }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo".localized)
        }
    }
}
