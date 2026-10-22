#if DEBUG
import SwiftUI

/// Debug-only design review: launch with `-designReview <screen>` to open one screen in a
/// fixed state, so iOS and Android can be screenshotted side by side against the Figma frames.
/// The same screen names exist on Android (`--es designReview <screen>`). Compiled out of release.
enum DesignReview: String, CaseIterable {
    case splash
    case welcome
    case emailFound, emailFoundFilled, emailFoundError
    case createPassword
    case name
    case mobility, mobilityFilled
    case allSet
    case home, homeFilter, homeFilterChosen, homeSearch, homeSearchQuery
    // Signed in: pass `-designReviewEmail <email> -designReviewPassword <password>` (a local test account).
    case profile, profileDeleteReview, profilePhotos, profileSettings, profileLanguage
    case myAccount, mobilityProfile, deleteAccount, accountDeleted
    case editResponse, editResponseLeave
    /// Home with a waiting contribution (banner, then folded into the profile badge) and Profile's row.
    case homeContinueSurvey, homeContinueSurveyFolded, profileOngoing
    /// Contribute flow (Figma "Contribute Review Category Menus" and "Question 3 - Filled").
    case contributeMenu, contributeMenuProgress, contributeMenuComplete
    case contributeNotes, contributeNotesFilled, contributeCaption, contributeSubmitted

    static let current: DesignReview? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-designReview"), index + 1 < args.count else { return nil }
        return DesignReview(rawValue: args[index + 1])
    }()

    static let sampleEmail = "name@gmail.com"

    static func argument(_ name: String) -> String? {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: name), index + 1 < args.count else { return nil }
        return args[index + 1]
    }

    static func `is`(_ screens: DesignReview...) -> Bool {
        current.map(screens.contains) ?? false
    }
}

struct DesignReviewRoot: View {
    let screen: DesignReview

    var body: some View {
        switch screen {
        case .splash:
            SplashScreenView()
        case .welcome:
            login([])
        case .emailFound, .emailFoundFilled, .emailFoundError:
            login([.emailFound(DesignReview.sampleEmail)])
        case .createPassword:
            login([.createPassword(DesignReview.sampleEmail)])
        case .name:
            login([.createPassword(DesignReview.sampleEmail), .name])
        case .mobility:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility])
        case .mobilityFilled:
            login([.createPassword(DesignReview.sampleEmail), .name, .mobility], aids: ["Wheelchair"])
        case .allSet:
            login([.allSet])
        case .home, .homeFilter, .homeFilterChosen, .homeSearch, .homeSearchQuery:
            HomeMapView()
        case .profile, .profileDeleteReview:
            signedIn { NavigationStack { ProfileView(initialTab: .reviews) } }
        case .profilePhotos:
            signedIn { NavigationStack { ProfileView(initialTab: .photos) } }
        case .profileSettings, .profileLanguage:
            signedIn { NavigationStack { ProfileView(initialTab: .settings) } }
        case .myAccount, .mobilityProfile, .deleteAccount, .accountDeleted:
            signedIn { NavigationStack { MyAccountView() } }
        case .homeContinueSurvey, .homeContinueSurveyFolded:
            signedIn { DesignReviewWaiting { HomeMapView() } }
        case .profileOngoing:
            signedIn { DesignReviewWaiting { NavigationStack { ProfileView(initialTab: .reviews) } } }
        case .contributeMenu, .contributeMenuProgress, .contributeMenuComplete:
            ContributeReviewCategoryMenusView(
                status: screen == .contributeMenuComplete ? [.entrance: .complete]
                    : screen == .contributeMenuProgress ? [.entrance: .inProgress] : [:],
                canContinue: screen == .contributeMenuComplete,
                onBack: {}, onOpen: { _ in }, onContinue: {}
            )
        case .contributeNotes, .contributeNotesFilled:
            DesignReviewNotes(filled: screen == .contributeNotesFilled)
        case .contributeCaption:
            PhotoCaptionEditorView(photo: DesignReviewNotes.samplePhoto(), onSave: { _ in }, onDismiss: {})
        case .contributeSubmitted:
            ContributeSubmittedView(onDone: {})
        case .editResponse, .editResponseLeave:
            signedIn { DesignReviewEditResponse() }
        }
    }

    private func signedIn(@ViewBuilder _ content: () -> some View) -> some View {
        DesignReviewSignIn(content: content())
    }

    private func login(_ path: [AuthRoute], aids: Set<String> = []) -> some View {
        LoginView(onSuccess: {}, onCancel: {}, onExploreMalls: {}, initialPath: path, initialMobilityAids: aids)
    }
}
/// Leaves a part-done contribution for "Park 23" so the Continue Survey states have something to show.
private struct DesignReviewWaiting<Content: View>: View {
    @ViewBuilder let content: () -> Content
    @State private var ready = false

    var body: some View {
        Group { if ready { content() } else { ProgressView() } }
            .task {
                let place = Place.fromSearchResult(
                    name: "Park 23", category: "Mall",
                    coordinate: .init(latitude: -8.7180, longitude: 115.1700), placeId: "design-review-park23"
                )
                let draft = ReviewDraft(placeId: place.reviewPlaceId, coordinate: place.coordinate, name: place.name)
                draft.elevator.review.text = "Lift next to the food court"
                UnfinishedReviewStore.save(
                    place: place, startingFacility: nil, screenIndex: 2, selectedFacilities: [],
                    entranceLocations: [], lobbyEntranceTags: [], basementEntranceTags: [],
                    elevatorTags: [], toiletTags: [], draft: draft
                )
                ready = true
            }
    }
}

/// The notes step empty, or with text and two photos (one captioned).
private struct DesignReviewNotes: View {
    let filled: Bool
    @State private var note = ReviewNoteDraft()

    static func samplePhoto(caption: String = "") -> ReviewPhotoDraft {
        let image = UIImage(named: "SamplePlacePhoto") ?? UIImage()
        var photo = ReviewPhotoDraft(image: image, jpegData: image.jpegData(compressionQuality: 0.5) ?? Data())
        photo.caption = caption
        return photo
    }

    var body: some View {
        ContributePhotosNotesStepView(
            facilityName: "Entrance", navTitle: "Entrance", progress: (3, 4),
            note: $note, onBack: {}, onContinue: {}
        )
        .onAppear {
            guard filled else { return }
            note.text = "The ramp is too steep for wheelchair user"
            note.photos = [Self.samplePhoto(caption: "Main entrance"), Self.samplePhoto()]
        }
    }
}

/// Edit Response for the account's newest editable review.
private struct DesignReviewEditResponse: View {
    @State private var reviewId: String?

    var body: some View {
        NavigationStack {
            if let reviewId { EditResponseView(reviewId: reviewId) } else { ProgressView() }
        }
        .task {
            let mine = try? await ReviewService.shared.fetchMyReviews()
            reviewId = mine?.reviews.first(where: \.editable)?.id.uuidString.lowercased()
        }
    }
}

/// Signs in with the account from the launch arguments, then shows the screen.
private struct DesignReviewSignIn<Content: View>: View {
    let content: Content
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var ready = false

    var body: some View {
        Group {
            if ready { content } else { ProgressView() }
        }
        .task {
            if !auth.isSignedIn,
               let email = DesignReview.argument("-designReviewEmail"),
               let password = DesignReview.argument("-designReviewPassword") {
                _ = try? await auth.signIn(email: email, password: password)
            }
            ready = true
        }
    }
}
#endif
