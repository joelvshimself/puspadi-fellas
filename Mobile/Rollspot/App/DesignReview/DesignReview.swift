#if DEBUG
import SwiftUI

/// Debug-only design review: launch with `-designReview <screen>` to open one screen in a
/// fixed state, so iOS and Android can be screenshotted side by side against the Figma frames.
/// The same screen names exist on Android (`--es designReview <screen>`). Compiled out of release.
enum DesignReview: String, CaseIterable {
    case splash
    case welcome
    case name
    case mobility, mobilityFilled
    case allSet
    case home, homeFilter, homeFilterChosen, homeSearch, homeSearchQuery
    // Signed in: pass `-designReviewToken <session token>` (from the local D1 `session` table).
    case profile, profileDeleteReview, profilePhotos, profileSettings, profileLanguage, notifications
    case myAccount, mobilityProfile, deleteAccount, accountDeleted
    case editResponse, editResponseLeave
    /// Home with a waiting contribution (banner, then folded into the profile badge) and Profile's row.
    case homeContinueSurvey, homeContinueSurveyFolded, profileOngoing
    /// Contribute flow (Figma "Contribute Review Category Menus" and "Question 3 - Filled").
    case contributeMenu, contributeMenuProgress, contributeMenuComplete
    case contributeNotes, contributeNotesFilled, contributeCaption, contributeSubmitted
    /// Question steps (Figma Entrance / Elevators / Toilets / Seating / Parking frames).
    case flowPhotos, flowQuestion, flowQuestionYes, flowQuestionNotSure, flowParking
    case flowLocation, flowTags, flowAnother, flowWhere
    case flowPathwayPhotos, flowPathway, flowPathwayInfo

    static let current: DesignReview? = {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "-designReview"), index + 1 < args.count else { return nil }
        return DesignReview(rawValue: args[index + 1])
    }()


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
        case .name:
            login([.name])
        case .mobility:
            login([.name, .mobility])
        case .mobilityFilled:
            login([.name, .mobility], aids: ["Wheelchair"])
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
        case .notifications:
            signedIn { NavigationStack { NotificationsSettingsView() } }
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
        case .flowPhotos, .flowQuestion, .flowQuestionYes, .flowQuestionNotSure, .flowParking,
             .flowLocation, .flowTags, .flowAnother, .flowWhere,
             .flowPathwayPhotos, .flowPathway, .flowPathwayInfo:
            DesignReviewFlowStep(screen: screen)
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

/// One question step in a fixed state, matching a Figma frame.
private struct DesignReviewFlowStep: View {
    let screen: DesignReview
    @State private var note = ReviewNoteDraft()
    @State private var answer: String?
    @State private var locations: Set<EntranceLocation> = []
    @State private var tags: Set<ContributeTagOption> = []
    @State private var location = ""
    @State private var notices: Set<String> = []
    @State private var showSheet = false

    var body: some View {
        content.onAppear {
            switch screen {
            case .flowQuestionYes: answer = "Yes"
            case .flowQuestionNotSure:
                answer = "Not sure"
                note.photos = [DesignReviewNotes.samplePhoto(), DesignReviewNotes.samplePhoto()]
            case .flowParking: answer = "Not sure"
            case .flowLocation: locations = [.lobby]
            case .flowPathway: notices = ["Loose gravel or sand", "Rough or uneven surface"]
            case .flowPathwayInfo:
                Task { try? await Task.sleep(for: .milliseconds(400)); showSheet = true }
            case .flowTags: tags = Set(ContributeReviewTags.tags(forEntrance: .lobby).prefix(2))
            default: break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch screen {
        case .flowPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Seating", illustrationAssetName: "Toilet Survey Asset", stepNumber: 4,
                progress: (1, 3), note: $note, onBack: {}, onContinue: {}
            )
        case .flowQuestion, .flowQuestionYes, .flowQuestionNotSure:
            ContributeAccessFollowupStepView(
                navTitle: "Seating", illustrationAssetName: "Toilet Survey Asset",
                eyebrow: "Wheelchair Friendly Seating", questionTitle: "Are there wheelchair friendly seatings?",
                progress: (2, 3), options: ["Yes", "No", "Not sure"], photoRevealOption: "Not sure",
                selection: $answer, note: $note, stepNumber: 4,
                loopingVideoName: "SEATING_SEATING", videoInfoTitle: "Wheelchair Friendly Seating",
                videoInfoSections: [("Height", "Low enough to comfortably reach the tabletop from a seated position.")],
                onBack: {}, onContinue: {}
            )
        case .flowParking:
            ContributeParkingQuestionStepView(progress: (2, 3), selection: $answer, onBack: {}, onContinue: {})
        case .flowLocation:
            ContributeEntranceLocationStepView(facilityName: "Park 23", progress: (1, 6), selection: $locations, onBack: {}, onContinue: {})
        case .flowTags:
            ContributeFacilityQuestionStepView(
                kind: .entrance, navTitle: "Entrances", questionTitle: "What does the lobby have?", progress: (2, 6),
                selection: $tags, illustrationAssetName: "Lobby Asset",
                optionsOverride: ContributeReviewTags.tags(forEntrance: .lobby), onBack: {}, onContinue: {}
            )
        case .flowAnother:
            ContributeAccessFollowupStepView(
                navTitle: "Entrances", illustrationAssetName: "Lobby Asset", eyebrow: "",
                questionTitle: "Review another entrance?", progress: (5, 6), options: ["Yes", "No"],
                photoRevealOption: "", selection: $answer, note: $note, advancesOnSelect: true,
                onBack: {}, onContinue: {}
            )
        case .flowPathwayPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Outdoor Pathways", illustrationAssetName: "Toilet Survey Asset", stepNumber: 4,
                progress: (1, 3), note: $note, onBack: {}, onContinue: {}
            )
        case .flowPathway, .flowPathwayInfo:
            ContributePathwayNoticeStepView(progress: (2, 3), selection: $notices, onBack: {}, onContinue: {})
                .sheet(isPresented: $showSheet) { PathwayInfoSheet() }
        default:
            ContributeToiletLocationStepView(
                navTitle: "Elevators", question: "Where is the elevator located?",
                illustrationAssetName: "Elevator Question Asset", stepNumber: 2,
                locationText: $location, onBack: {}, onContinue: {}
            )
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
            if !auth.isSignedIn, let token = DesignReview.argument("-designReviewToken") {
                RollspotServices.sdk.tokenStore.save(token: token)
                try? await RollspotServices.sdk.auth.restore()
            }
            ready = true
        }
    }
}
#endif
