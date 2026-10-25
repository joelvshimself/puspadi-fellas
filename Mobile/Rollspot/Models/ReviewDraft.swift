import CoreLocation
import SwiftUI

/// State for the "Add Review" wizard (Views/Review/).
///
/// Field names/types mirror the real `POST /v1/reviews` payload contract — see
/// `ReviewSubmissionPayload` for the exact wire shape and `ReviewService` for
/// the live call site.
final class ReviewDraft: ObservableObject {
    /// Stable across retries and double taps; the database accepts one review
    /// for this submission identifier.
    let submissionId = UUID()
    /// Stable Apple Maps place identifier used by the backend.
    let placeId: String
    /// Used only to restore an unfinished local draft in context.
    let coordinate: CLLocationCoordinate2D
    /// Used only to label an unfinished local draft.
    let name: String

    /// The wizard always walks both entrances in sequence (Lobby, then
    /// Basement) rather than letting the user pick one — matches the
    /// backend's example payload, which submits both as separate
    /// `EntranceReport` array items.
    @Published var lobby = EntranceDraft(location: .lobby)
    @Published var basement = EntranceDraft(location: .basement)
    /// Set just before submit when the contributor reviewed one or more entrances.
    var entrancePassSnapshots: [EntrancePassSnapshot] = []
    @Published var elevator = ElevatorDraft()
    @Published var toilet = ToiletDraft()

    init(placeId: String, coordinate: CLLocationCoordinate2D, name: String) {
        self.placeId = placeId
        self.coordinate = coordinate
        self.name = name
    }
}

// MARK: - Entrance

enum EntranceLocation: String {
    case lobby, basement

    var stepTitle: String {
        switch self {
        case .lobby: "Lobby entrance"
        case .basement: "Basement entrance"
        }
    }
}

enum DoorType: String, CaseIterable, Identifiable {
    case manual, automatic

    var id: String { rawValue }

    var label: String {
        switch self {
        case .manual: "Manual"
        case .automatic: "Automatic"
        }
    }
}

/// One finished walk through the entrance section, kept so a second entrance can be reviewed.
struct EntrancePassSnapshot {
    var sectionPhotos: [ReviewPhotoDraft]
    var locations: Set<EntranceLocation>
    var lobby: EntranceDraft
    var basement: EntranceDraft
}

struct EntranceDraft {
    let location: EntranceLocation
    var hasDropoffRamp: Bool?
    var hasRails: Bool?
    /// UI-only context copy from the flowchart ("Easy to go through / Needs
    /// assistance / Can't go through") — the backend contract has no
    /// matching field for this, so it is not sent at submit time.
    var easeOfAccess: EaseOfAccess?
    var doorType: DoorType?
    var isWideEnough: Bool?
    var review = ReviewNoteDraft()
}

enum EaseOfAccess: String, CaseIterable, Identifiable {
    case easy, needsAssistance, cantGoThrough

    var id: String { rawValue }

    var label: String {
        switch self {
        case .easy: "Easy to go through"
        case .needsAssistance: "Needs assistance"
        case .cantGoThrough: "Can't go through"
        }
    }
}

// MARK: - Elevator

enum ElevatorBlocker: String, CaseIterable, Identifiable {
    case noRamp = "no_ramp"
    case tooSmall = "too_small"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noRamp: "No ramp"
        case .tooSmall: "Too small"
        }
    }
}

struct ElevatorDraft {
    var exists: Bool?
    /// Only asked/shown once `exists == true`.
    var wheelchairAccessible: Bool?
    /// Only relevant when `wheelchairAccessible == false`; cleared client-side
    /// if the user flips back to `true`, mirroring the contract's
    /// "ifAccessibleTrue: strip blockers" rule.
    var blockers: Set<ElevatorBlocker> = []
    var review = ReviewNoteDraft()
}

// MARK: - Toilet

struct ToiletDraft {
    var hasDisabledToilet: Bool?
    var review = ReviewNoteDraft()
}

// MARK: - Shared review note

/// One local photo attached to a facility note. JPEG bytes are uploaded to
/// Cloudflare R2 at submit time; the resulting public
/// URLs become `photoUrls` in the wire payload.
struct ReviewPhotoDraft: Identifiable {
    let id: UUID
    let image: UIImage
    let jpegData: Data
    var caption: String = ""

    init(id: UUID = UUID(), image: UIImage, jpegData: Data, caption: String = "") {
        self.id = id
        self.image = image
        self.jpegData = jpegData
        self.caption = caption
    }
}

struct ReviewNoteDraft {
    static let maxPhotos = 5
    static let jpegQuality: CGFloat = 0.7

    /// Empty string is treated as "no text" (→ nil) at submit time, per contract.
    var text: String = ""
    /// Local photos (≤ `maxPhotos`). Uploaded to Storage before submit.
    var photos: [ReviewPhotoDraft] = []

    var canAddMorePhotos: Bool { photos.count < Self.maxPhotos }

    mutating func addPhoto(from image: UIImage, limit: Int = maxPhotos) {
        guard photos.count < limit,
              let jpegData = image.jpegData(compressionQuality: Self.jpegQuality)
        else { return }
        photos.append(ReviewPhotoDraft(image: image, jpegData: jpegData))
    }

    mutating func removePhoto(id: UUID) {
        photos.removeAll { $0.id == id }
    }

    mutating func updatePhotoCaption(id: UUID, caption: String) {
        if let idx = photos.firstIndex(where: { $0.id == id }) {
            photos[idx].caption = caption
        }
    }
}

// MARK: - Merged review photos (Final Review)

extension ReviewDraft {
    /// All photos captured across entrance, elevator, and toilet steps, in order.
    var allReviewPhotos: [ReviewPhotoDraft] {
        lobby.review.photos
            + basement.review.photos
            + elevator.review.photos
            + toilet.review.photos
    }

    func removeReviewPhoto(id: UUID) {
        lobby.review.removePhoto(id: id)
        basement.review.removePhoto(id: id)
        elevator.review.removePhoto(id: id)
        toilet.review.removePhoto(id: id)
    }

    func updateReviewPhotoCaption(id: UUID, caption: String) {
        lobby.review.updatePhotoCaption(id: id, caption: caption)
        basement.review.updatePhotoCaption(id: id, caption: caption)
        elevator.review.updatePhotoCaption(id: id, caption: caption)
        toilet.review.updatePhotoCaption(id: id, caption: caption)
    }
}

// MARK: - Wizard steps

enum ReviewStep: Int, CaseIterable {
    case lobbyRampsRails
    case lobbyDoor
    case lobbyNote
    case basementRampsRails
    case basementDoor
    case basementNote
    case elevatorPresence
    case elevatorWheelchair
    case elevatorNote
    case toiletPresence
    case toiletNote
    case submitted

    /// Steps counted by the progress bar (submission confirmation excluded).
    static var answerableSteps: [ReviewStep] {
        allCases.filter { $0 != .submitted }
    }
}

// MARK: - Photo Caption Editor Component

/// Full-screen photo viewer and caption editor for the review flow —
/// matches the design mockup's "Photo Clicked to view" → "caption field goes up with keyboard"
/// → "Photo caption added, button activated" → "Added caption shows caption icon" screens.
struct PhotoCaptionEditorView: View {
    let photo: ReviewPhotoDraft
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var captionText: String
    @State private var isPhotoZoomed = false
    @FocusState private var isCaptionFocused: Bool

    init(photo: ReviewPhotoDraft, onSave: @escaping (String) -> Void, onDismiss: @escaping () -> Void) {
        self.photo = photo
        self.onSave = onSave
        self.onDismiss = onDismiss
        self._captionText = State(initialValue: photo.caption)
    }

    private var isModified: Bool {
        let trimmedNew = captionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOld = photo.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedNew != trimmedOld || !trimmedNew.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            ContributeStepProgressBar(currentStep: 4)
            HStack {
                Button(action: onDismiss) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Color(designHex: 0x0F0F0F))
                        .frame(width: 44, height: 44)
                        .background(ContributePalette.circleButton, in: Circle())
                        .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Back")

                Spacer()

                Button {
                    onSave(captionText)
                    onDismiss()
                } label: {
                    // "Photo caption added, button activated": grey until there's a caption, then blue.
                    ZStack {
                        Circle()
                            .fill(isModified ? ContributePalette.blue : ContributePalette.circleButton)
                            .frame(width: 44, height: 44)
                            .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: isModified ? .semibold : .regular))
                            .foregroundStyle(isModified ? .white : Color(designHex: 0x9B9B9B))
                    }
                    .animation(.easeOut(duration: 0.2), value: isModified)
                }
                .buttonStyle(PressableButtonStyle())
                .accessibilityLabel("Save Caption")
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)

            ZoomablePhotoContainer(image: photo.image, isZoomed: $isPhotoZoomed)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            captionField
        }
    }

    private var captionField: some View {
        TextField("Add a caption ...".localized, text: $captionText, axis: .vertical)
            .font(.system(size: 15))
            .foregroundStyle(ContributePalette.text)
            .lineLimit(1...4)
            .focused($isCaptionFocused)
            .padding(.horizontal, 16)
            .padding(.vertical, 15)
            .background(
                Capsule(style: .continuous)
                    .fill(ContributePalette.fill)
            )
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        ContributePalette.blue.opacity(isCaptionFocused ? 0.5 : 0),
                        lineWidth: 2
                    )
            }
            .animation(.easeOut(duration: 0.15), value: isCaptionFocused)
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 12)
            .background(Color(.systemBackground))
    }
}
