import Shared
import SwiftUI

/// Fired when the backend accepts a contribute review — before the user taps Done.
struct ContributeReviewSubmission {
    let reviewId: UUID?
    let placeId: String?
}

/// Contribute flow backed by the Cloudflare API, with local draft persistence.
/// Same screen sequence for wheelchair users and community contributors.
/// Question titles follow `ReviewPersona`.
struct ContributeReviewFlowView: View {
    let place: Place
    let startingFacility: FacilityKind?
    let initialScreenIndex: Int
    /// When true, never resumes an unfinished draft — used for Update Review.
    let ignoreDraftRestore: Bool
    /// Fired the moment the backend accepts the review — BEFORE the user taps
    /// Done on the confirmation screen — so the presenting page can stage its
    /// "Your review submitted!" state. `onFinished` alone can't tell a
    /// submission from a cancel. Passes the new review id when available.
    let onSubmitted: ((ContributeReviewSubmission) -> Void)?
    let onFinished: () -> Void

    @StateObject private var draft: ReviewDraft

    @State private var activeCategory: ContributeReviewCategory?
    @State private var sectionStatus: [ContributeReviewCategory: ContributeCategoryStatus]
    @State private var supplementalNotes: [ContributeReviewCategory: ReviewNoteDraft]
    @State private var pathwayNotices: Set<String> = []
    @State private var seatingAnswer: String?
    @State private var seatingNote = ReviewNoteDraft()
    @State private var parkingAnswer: String?
    @State private var parkingNote = ReviewNoteDraft()
    @State private var screenIndex: Int
    @State private var entranceLocations: Set<EntranceLocation>
    @State private var entranceSectionPhotos: ReviewNoteDraft = ReviewNoteDraft()
    @State private var lobbyEntranceTags: Set<ContributeTagOption> = []
    @State private var basementEntranceTags: Set<ContributeTagOption> = []
    /// Ramp/Handrail follow-up answers — UI-only (like `EntranceDraft.easeOfAccess`
    /// for ramp), not persisted across app relaunch. Handrail's answer has no
    /// matching backend field at all, so it only ever drives the local
    /// "Not sure" → Add Photos reveal.
    @State private var lobbyRampAnswer: String?
    @State private var basementRampAnswer: String?
    @State private var lobbyHandrailAnswer: String?
    @State private var basementHandrailAnswer: String?
    @State private var lobbyRampPhotos = ReviewNoteDraft()
    @State private var lobbyHandrailPhotos = ReviewNoteDraft()
    @State private var basementRampPhotos = ReviewNoteDraft()
    @State private var basementHandrailPhotos = ReviewNoteDraft()
    @State private var elevatorEvidence: [ElevatorQuestion: ReviewNoteDraft] = [:]
    @State private var toiletEvidence: [ToiletQuestion: ReviewNoteDraft] = [:]
    @State private var completedEntrancePasses: [EntrancePassDraft] = []
    @State private var entranceAnotherAnswer: String?
    /// One answer per `ElevatorQuestion` — the elevator section asks these
    /// instead of showing a chip multi-select; `applyElevatorMapping()`
    /// turns them back into `elevatorTags`.
    @State private var elevatorAnswers: [ElevatorQuestion: String] = [:]
    @State private var completedElevatorPasses: [ElevatorPassDraft] = []
    @State private var elevatorAnotherAnswer: String?
    @State private var elevatorTags: Set<ContributeTagOption> = []
    @State private var toiletAnswers: [ToiletQuestion: String] = [:]
    @State private var completedToiletPasses: [ToiletPassDraft] = []
    @State private var toiletAnotherAnswer: String?
    @State private var toiletLocationNote: String = ""
    @State private var toiletTags: Set<ContributeTagOption> = []
    @State private var isSubmitted = false
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var showExitConfirmation = false
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var showLogin = false
    @State private var reviewPersona: ReviewPersona = .everyone

    init(
        place: Place,
        startingFacility: FacilityKind? = nil,
        initialScreenIndex: Int = 0,
        ignoreDraftRestore: Bool = false,
        onSubmitted: ((ContributeReviewSubmission) -> Void)? = nil,
        onFinished: @escaping () -> Void
    ) {
        self.place = place
        self.startingFacility = startingFacility
        self.initialScreenIndex = initialScreenIndex
        self.ignoreDraftRestore = ignoreDraftRestore
        self.onSubmitted = onSubmitted
        self.onFinished = onFinished

        let draft = ReviewDraft(placeId: place.reviewPlaceId, coordinate: place.coordinate, name: place.name)
        var startIndex = initialScreenIndex
        var restoredStatus: [ContributeReviewCategory: ContributeCategoryStatus] = [:]
        var entranceLocs = Set<EntranceLocation>()
        var lobbyTags = Set<ContributeTagOption>()
        var basementTags = Set<ContributeTagOption>()
        var elevTags = Set<ContributeTagOption>()
        var toiletTagsInit = Set<ContributeTagOption>()
        var restoredNotes: [ContributeReviewCategory: ReviewNoteDraft] = [:]

        if !ignoreDraftRestore, let snap = UnfinishedReviewStore.snapshot(for: place) {
            if startingFacility != nil {
                startIndex = snap.screenIndex
            }
            restoredStatus = Self.restoredSectionStatus(from: snap)
            entranceLocs = Set(snap.entranceLocations.compactMap(EntranceLocation.init(rawValue:)))
            lobbyTags = UnfinishedReviewStore.restoreTags(snap.lobbyEntranceTags, forEntrance: .lobby)
            basementTags = UnfinishedReviewStore.restoreTags(snap.basementEntranceTags, forEntrance: .basement)
            elevTags = UnfinishedReviewStore.restoreTags(snap.elevatorTags, for: .elevator)
            toiletTagsInit = UnfinishedReviewStore.restoreTags(snap.toiletTags, for: .toilet)
            draft.lobby.review.text = snap.lobbyNote
            draft.basement.review.text = snap.basementNote
            draft.elevator.review.text = snap.elevatorNote
            draft.toilet.review.text = snap.toiletNote
            for (raw, text) in snap.categoryNotes {
                guard let category = ContributeReviewCategory(rawValue: raw) else { continue }
                var note = ReviewNoteDraft()
                note.text = text
                restoredNotes[category] = note
            }
        }

        _draft = StateObject(wrappedValue: draft)
        _activeCategory = State(initialValue: nil)
        _sectionStatus = State(initialValue: restoredStatus)
        _supplementalNotes = State(initialValue: restoredNotes)
        _screenIndex = State(initialValue: startIndex)
        _entranceLocations = State(initialValue: entranceLocs)
        _lobbyEntranceTags = State(initialValue: lobbyTags)
        _basementEntranceTags = State(initialValue: basementTags)
        _elevatorTags = State(initialValue: elevTags)
        _toiletTags = State(initialValue: toiletTagsInit)
    }

    private static func restoredSectionStatus(
        from snap: UnfinishedReviewStore.Snapshot
    ) -> [ContributeReviewCategory: ContributeCategoryStatus] {
        var status: [ContributeReviewCategory: ContributeCategoryStatus] = [:]
        for raw in snap.completedCategories {
            if let category = ContributeReviewCategory(rawValue: raw) {
                status[category] = .complete
            }
        }
        for raw in snap.inProgressCategories {
            if let category = ContributeReviewCategory(rawValue: raw), status[category] != .complete {
                status[category] = .inProgress
            }
        }
        if snap.completedCategories.isEmpty && snap.inProgressCategories.isEmpty {
            for raw in snap.selectedFacilities {
                if let kind = FacilityKind(rawValue: raw),
                   let category = ContributeReviewCategory(facilityKind: kind) {
                    status[category] = .inProgress
                }
            }
        }
        return status
    }

    private enum FlowScreen: Equatable {
        case category
        case entranceSectionPhotos
        case entranceLocation
        case entranceQuestion(EntranceLocation)
        case entranceRampFollowup(EntranceLocation)
        case entranceHandrailFollowup(EntranceLocation)
        case entranceAnother
        case entrancePhotos(EntranceLocation)
        case elevatorPhotos
        case elevatorQuestion(ElevatorQuestion)
        case elevatorLocation
        case elevatorAnother
        case toiletPhotos
        case toiletQuestion(ToiletQuestion)
        case toiletLocation
        case toiletAnother
        case pathwayPhotos
        case pathwayNotice
        case seatingPhotos
        case seatingQuestion
        case parkingPhotos
        case parkingQuestion
        case supplementalNotes(ContributeReviewCategory)
        case facilityQuestion(FacilityKind)
        case facilityPhotos(FacilityKind)
    }

    private func sectionScreens(for category: ContributeReviewCategory) -> [FlowScreen] {
        switch category {
        case .entrance:
            var list: [FlowScreen] = [.entranceSectionPhotos, .entranceLocation]
            // Lobby before Basement when both are picked — matches
            // EntranceLocation.allCases order.
            for location in EntranceLocation.allCases where entranceLocations.contains(location) {
                list.append(.entranceQuestion(location))
                // Notes to DEV: Ramp and/or Handrail have a follow-up question.
                // Every other tag only records whether it is present. Do not add extra screens for those yet.
                let tags = entranceTags(for: location)
                if tags.contains(where: { $0.label == "RAMP" }) {
                    list.append(.entranceRampFollowup(location))
                }
                if tags.contains(where: { $0.label == "HANDRAIL" }) {
                    list.append(.entranceHandrailFollowup(location))
                }
            }
            list.append(.entranceAnother)
            list.append(.supplementalNotes(.entrance))
            return list
        case .elevator:
            var list: [FlowScreen] = [.elevatorPhotos, .elevatorQuestion(.wideEntrance)]
            if elevatorAnswers[.wideEntrance] != "No" {
                list.append(.elevatorQuestion(.spaceToManeuver))
                list.append(.elevatorQuestion(.reachableButtons))
            }
            list.append(.elevatorLocation)
            list.append(.elevatorAnother)
            list.append(.supplementalNotes(.elevator))
            return list
        case .toilet:
            var list: [FlowScreen] = [.toiletPhotos]
            list.append(contentsOf: ToiletQuestion.allCases.map { .toiletQuestion($0) })
            list.append(.toiletLocation)
            list.append(.toiletAnother)
            list.append(.supplementalNotes(.toilet))
            return list
        case .outdoorPathways:
            return [.pathwayPhotos, .pathwayNotice, .supplementalNotes(.outdoorPathways)]
        case .seating:
            return [.seatingPhotos, .seatingQuestion, .supplementalNotes(.seating)]
        case .parking:
            return [.parkingPhotos, .parkingQuestion, .supplementalNotes(.parking)]
        }
    }

    private var screens: [FlowScreen] {
        if let start = startingFacility, let category = ContributeReviewCategory(facilityKind: start) {
            return sectionScreens(for: category)
        }
        var list: [FlowScreen] = [.category]
        if let activeCategory {
            list.append(contentsOf: sectionScreens(for: activeCategory))
        }
        return list
    }

    private var progressScreens: [FlowScreen] { screens }

    private func progress(for screen: FlowScreen) -> (current: Int, total: Int) {
        (progressScreens.firstIndex(of: screen) ?? 0, max(progressScreens.count, 1))
    }

    private var hasProgress: Bool {
        screenIndex > 0
            || activeCategory != nil
            || !sectionStatus.isEmpty
            || supplementalNotes.values.contains(where: { !$0.text.isEmpty || !$0.photos.isEmpty })
            || !pathwayNotices.isEmpty
            || seatingAnswer != nil
            || !seatingNote.photos.isEmpty
            || !seatingNote.text.isEmpty
            || parkingAnswer != nil
            || !parkingNote.photos.isEmpty
            || !parkingNote.text.isEmpty
            || !entranceLocations.isEmpty
            || !completedEntrancePasses.isEmpty
            || !entranceSectionPhotos.photos.isEmpty
            || !lobbyEntranceTags.isEmpty || !basementEntranceTags.isEmpty || !toiletTags.isEmpty
            || !elevatorAnswers.isEmpty || !completedElevatorPasses.isEmpty
            || !toiletAnswers.isEmpty || !completedToiletPasses.isEmpty
            || !toiletLocationNote.isEmpty || !draft.toilet.review.photos.isEmpty
            || !draft.lobby.review.text.isEmpty || !draft.basement.review.text.isEmpty
            || !draft.elevator.review.text.isEmpty || !draft.toilet.review.text.isEmpty
            || !draft.lobby.review.photos.isEmpty || !draft.basement.review.photos.isEmpty
            || !draft.elevator.review.photos.isEmpty || !draft.toilet.review.photos.isEmpty
    }

    var body: some View {
        Group {
            if isSubmitted {
                ContributeSubmittedView(onDone: {
                    UnfinishedReviewStore.clear(for: place)
                    onFinished()
                })
            } else if let screen = screens[safe: screenIndex] {
                screenView(screen)
            } else {
                // screenIndex out of range — clamp on next layout pass; never
                // auto-submit from here (that caused fail→goBack→toilet).
                Color(.systemBackground)
                    .onAppear { clampScreenIndex() }
            }
        }
        // No sign-in gate on appear: every entry point (Contribute, Be the
        // first reviewer, Edit Accessibility Information) asks for login
        // BEFORE presenting this flow — same pattern as Save. Landing on the
        // wizard and being interrupted by a login popup a beat later read as
        // two competing prompts. `showLogin` remains for one case only: a
        // session that lapsed mid-flow, surfaced by a failed submit.
        .fullScreenCover(isPresented: $showLogin) {
            LoginView(
                onSuccess: { showLogin = false },
                onCancel: { onFinished() },
                onExploreMalls: { showLogin = false }
            )
            .environmentObject(auth)
        }
        .alert(
            "Couldn't submit review",
            isPresented: Binding(get: { submitError != nil }, set: { if !$0 { submitError = nil } }),
            presenting: submitError
        ) { _ in
            Button("OK") { submitError = nil }
        } message: { message in
            Text(message)
        }
        .alert(
            "Leave this form?",
            isPresented: $showExitConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Discard & Leave", role: .destructive) {
                UnfinishedReviewStore.clear(for: place)
                onFinished()
            }
        } message: {
            Text("Your progress won't be saved if you leave now.")
        }
        .onAppear { clampScreenIndex() }
        .onChange(of: screenIndex) { _, _ in persistIfNeeded() }
        .onChange(of: entranceLocations) { _, _ in clampScreenIndex() }
        .onChange(of: lobbyEntranceTags) { _, _ in clampScreenIndex() }
        .onChange(of: basementEntranceTags) { _, _ in clampScreenIndex() }
        .onChange(of: elevatorAnswers) { _, _ in clampScreenIndex() }
        .task { await loadReviewPersona() }
    }

    private func loadReviewPersona() async {
        guard auth.isSignedIn else { return }
        do {
            let profile = try await ProfileService.shared.fetchCurrent()
            reviewPersona = ReviewPersona.from(aids: profile?.mobilityAids)
        } catch {
            reviewPersona = .everyone
        }
    }

    @ViewBuilder
    private func screenView(_ screen: FlowScreen) -> some View {
        switch screen {
        case .category:
            ContributeReviewCategoryMenusView(
                status: sectionStatus,
                canContinue: sectionStatus.values.contains(.complete),
                isSubmitting: isSubmitting,
                onBack: requestExit,
                onOpen: openCategory,
                onContinue: { Task { await submit() } }
            )
        case .pathwayPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Outdoor Pathways",
                illustrationAssetName: "Toilet Survey Asset",
                stepNumber: 4,
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: supplementalNoteBinding(for: .outdoorPathways),
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .seatingPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Seating",
                illustrationAssetName: "Toilet Survey Asset",
                stepNumber: 4,
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: $seatingNote,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .seatingQuestion:
            ContributeAccessFollowupStepView(
                navTitle: "Seating",
                illustrationAssetName: "Toilet Survey Asset",
                eyebrow: "Wheelchair Friendly Seating",
                questionTitle: "Are there wheelchair friendly seatings?",
                progress: progress(for: screen),
                options: ["Yes", "No", "Not sure"],
                photoRevealOption: "",
                selection: $seatingAnswer,
                note: $seatingNote,
                stepNumber: 4,
                subStepProgress: subProgress(for: screen),
                loopingVideoName: "SEATING_SEATING",
                videoInfoTitle: "Wheelchair Friendly Seating",
                videoInfoSections: [
                    ("Height", "Low enough to comfortably reach the tabletop from a seated position."),
                    ("Clearance", "Open space underneath so a wheelchair can roll up close and not blocked by a solid base or crossbar."),
                ],
                infoVideoName: "SEATING_SEATING",
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .parkingPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Accessible Parking",
                illustrationAssetName: "Basement Asset",
                stepNumber: 4,
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: $parkingNote,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .parkingQuestion:
            ContributeParkingQuestionStepView(
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                selection: $parkingAnswer,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .pathwayNotice:
            ContributePathwayNoticeStepView(
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                selection: $pathwayNotices,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .supplementalNotes(let category):
            ContributePhotosNotesStepView(
                facilityName: category.menuTitle,
                navTitle: category.menuTitle,
                progress: progress(for: screen),
                note: supplementalNoteBinding(for: category),
                photoNote: notesPhotosBinding(for: category),
                continueTitle: startingFacility == nil ? "Continue" : "Submit",
                isSubmitting: isSubmitting,
                onBack: goBackOneStep,
                onContinue: {
                    if startingFacility == nil {
                        goNext()
                    } else {
                        Task { await submit() }
                    }
                }
            )
        case .entranceSectionPhotos:
            ContributeEntrancePhotosStepView(
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: $entranceSectionPhotos,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .entranceLocation:
            ContributeEntranceLocationStepView(
                facilityName: place.name,
                progress: progress(for: screen),
                selection: $entranceLocations,
                onBack: goBackOneStep,
                onContinue: {
                    applyEntranceSectionPhotos()
                    goNext()
                }
            )
        case .entranceQuestion(let location):
            ContributeFacilityQuestionStepView(
                kind: .entrance,
                navTitle: "Entrances",
                questionTitle: questionTitle(forEntrance: location),
                progress: progress(for: screen),
                selection: entranceTagsBinding(for: location),
                illustrationAssetName: illustrationAssetName(for: location),
                optionsOverride: ContributeReviewTags.tags(forEntrance: location, persona: reviewPersona),
                subStepProgress: subProgress(for: screen),
                onBack: goBackOneStep,
                onContinue: {
                    applyEntranceMapping(for: location)
                    goNext()
                }
            )
        case .entranceRampFollowup(let location):
            ContributeAccessFollowupStepView(
                navTitle: "Entrances",
                illustrationAssetName: illustrationAssetName(for: location),
                eyebrow: "Ramps",
                questionTitle: ReviewQuestionCopy.rampQuestion(for: reviewPersona),
                progress: progress(for: screen),
                options: ReviewQuestionCopy.rampOptions(for: reviewPersona),
                photoRevealOption: "Not sure",
                selection: rampAnswerBinding(for: location),
                note: rampPhotosBinding(for: location),
                photoLimit: evidencePhotoLimit(currentCount: rampPhotos(for: location).photos.count, totalCount: entranceEvidenceCount),
                stepNumber: 1,
                subStepProgress: subProgress(for: screen),
                loopingVideoName: "ENTRANCE_RAMP",
                videoInfoTitle: "Ramps",
                videoInfoSections: [
                    ("Slope", "Steep slopes require wheelchair users to push hard. The taller the step up, the longer the ramp needs to be to stay gentle."),
                    ("Landing", "Long ramps require a flat landing space partway up that allows wheelchair users to stop and reset."),
                ],
                onBack: goBackOneStep,
                onContinue: {
                    applyRampAnswer(for: location)
                    goNext()
                }
            )
        case .entranceHandrailFollowup(let location):
            ContributeAccessFollowupStepView(
                navTitle: "Entrances",
                illustrationAssetName: illustrationAssetName(for: location),
                eyebrow: "Hand Rails",
                questionTitle: ReviewQuestionCopy.handrailQuestion(for: reviewPersona),
                progress: progress(for: screen),
                options: ReviewQuestionCopy.handrailOptions,
                photoRevealOption: "Not sure",
                selection: handrailAnswerBinding(for: location),
                note: handrailPhotosBinding(for: location),
                photoLimit: evidencePhotoLimit(currentCount: handrailPhotos(for: location).photos.count, totalCount: entranceEvidenceCount),
                stepNumber: 1,
                subStepProgress: subProgress(for: screen),
                loopingVideoName: "ENTRANCE_HANDRAIL",
                videoInfoTitle: "Handrail",
                videoInfoSections: [
                    ("Height", "Low enough to reach and grip while seated, not just at standing height."),
                    ("Grip", "A rounded rail you can wrap your hand around, not a flat edge or wide cap."),
                ],
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .entranceAnother:
            ContributeAccessFollowupStepView(
                navTitle: "Entrances",
                illustrationAssetName: "Lobby Asset",
                eyebrow: "",
                questionTitle: "Review another entrance?",
                progress: progress(for: screen),
                options: ["Yes", "No"],
                photoRevealOption: "",
                selection: $entranceAnotherAnswer,
                note: .constant(ReviewNoteDraft()),
                stepNumber: 1,
                subStepProgress: subProgress(for: screen),
                advancesOnSelect: true,
                onBack: goBackOneStep,
                onContinue: {
                    guard let answer = entranceAnotherAnswer else { return }
                    chooseAnotherEntrance(answer)
                }
            )
        case .entrancePhotos(let location):
            ContributePhotosNotesStepView(
                facilityName: location.displayLabel,
                navTitle: "Entrances",
                progress: progress(for: screen),
                note: entranceNoteBinding(for: location),
                isLastStep: screen == screens.last,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .elevatorPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Elevator",
                illustrationAssetName: "Elevator Question Asset",
                stepNumber: 2,
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 }),
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .elevatorQuestion(let question):
            ContributeAccessFollowupStepView(
                navTitle: "Elevators",
                illustrationAssetName: "Elevator Question Asset",
                eyebrow: question.eyebrow,
                questionTitle: question.title(for: reviewPersona),
                progress: progress(for: screen),
                options: ReviewQuestionCopy.elevatorOptions,
                photoRevealOption: "Not Sure",
                selection: elevatorAnswerBinding(for: question),
                note: elevatorEvidenceBinding(for: question),
                photoLimit: evidencePhotoLimit(
                    currentCount: elevatorEvidence[question]?.photos.count ?? 0,
                    totalCount: elevatorEvidence.values.reduce(0) { $0 + $1.photos.count }
                ),
                stepNumber: 2,
                subStepProgress: subProgress(for: screen),
                loopingVideoName: question.loopingVideoName,
                videoInfoTitle: question.videoInfoTitle,
                videoInfoSections: question.videoInfoSections,
                onBack: goBackOneStep,
                onContinue: {
                    applyElevatorMapping()
                    goNext()
                }
            )
        case .elevatorLocation:
            ContributeToiletLocationStepView(
                navTitle: "Elevators",
                question: "Where is the elevator located?",
                illustrationAssetName: "Elevator Question Asset",
                stepNumber: 2,
                subStepProgress: subProgress(for: screen),
                locationText: Binding(
                    get: { draft.elevator.review.text },
                    set: { draft.elevator.review.text = $0 }
                ),
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .elevatorAnother:
            ContributeAccessFollowupStepView(
                navTitle: "Elevator",
                illustrationAssetName: "Elevator Question Asset",
                eyebrow: "",
                questionTitle: "Review another elevator?",
                progress: progress(for: screen),
                options: ["Yes", "No"],
                photoRevealOption: "",
                selection: $elevatorAnotherAnswer,
                note: Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 }),
                stepNumber: 2,
                subStepProgress: subProgress(for: screen),
                advancesOnSelect: true,
                onBack: goBackOneStep,
                onContinue: {
                    guard let answer = elevatorAnotherAnswer else { return }
                    chooseAnotherElevator(answer)
                }
            )
        case .toiletPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Accessible Toilets",
                illustrationAssetName: "Toilet Survey Asset",
                stepNumber: 3,
                progress: progress(for: screen),
                subStepProgress: subProgress(for: screen),
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .toiletQuestion(let question):
            ContributeAccessFollowupStepView(
                navTitle: "Accessible Toilets",
                illustrationAssetName: question.stillImageName ?? "Toilet Survey Asset",
                eyebrow: question.eyebrow,
                questionTitle: question.title(for: reviewPersona),
                progress: progress(for: screen),
                options: question.options(for: reviewPersona),
                photoRevealOption: question.photoRevealOption(for: reviewPersona) ?? "",
                selection: toiletAnswerBinding(for: question),
                note: toiletEvidenceBinding(for: question),
                photoLimit: evidencePhotoLimit(
                    currentCount: toiletEvidence[question]?.photos.count ?? 0,
                    totalCount: toiletEvidence.values.reduce(0) { $0 + $1.photos.count }
                ),
                stepNumber: 3,
                subStepProgress: subProgress(for: screen),
                loopingVideoName: question.loopingVideoName,
                videoInfoTitle: question.videoInfoTitle,
                videoInfoSections: question.videoInfoSections,
                onBack: goBackOneStep,
                onContinue: {
                    applyToiletQuestionMapping(question)
                    goNext()
                }
            )
        case .toiletLocation:
            ContributeToiletLocationStepView(
                illustrationAssetName: "Toilet Survey Asset",
                locationText: $toiletLocationNote,
                onBack: goBackOneStep,
                onContinue: {
                    applyToiletLocationMapping()
                    goNext()
                }
            )
        case .toiletAnother:
            ContributeAccessFollowupStepView(
                navTitle: "Accessible Toilets",
                illustrationAssetName: "Toilet Survey Asset",
                eyebrow: "",
                questionTitle: "Review another accessible toilet?",
                progress: progress(for: screen),
                options: ["Yes", "No"],
                photoRevealOption: "",
                selection: $toiletAnotherAnswer,
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
                stepNumber: 3,
                subStepProgress: subProgress(for: screen),
                advancesOnSelect: true,
                onBack: goBackOneStep,
                onContinue: {
                    guard let answer = toiletAnotherAnswer else { return }
                    chooseAnotherToilet(answer)
                }
            )
        case .facilityQuestion(let kind):
            ContributeFacilityQuestionStepView(
                kind: kind,
                navTitle: navTitle(for: kind),
                questionTitle: questionTitle(for: kind),
                progress: progress(for: screen),
                selection: tagBinding(for: kind),
                onBack: goBackOneStep,
                onContinue: {
                    applyMapping(for: kind)
                    goNext()
                }
            )
        case .facilityPhotos(let kind):
            ContributePhotosNotesStepView(
                facilityName: kind.title,
                navTitle: navTitle(for: kind),
                progress: progress(for: screen),
                note: noteBinding(for: kind),
                isLastStep: screen == screens.last,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        }
    }

    private func goNext() {
        persistIfNeeded()
        if startingFacility == nil, let screen = screens[safe: screenIndex], isSectionTerminal(screen) {
            finishActiveSection()
            return
        }
        screenIndex += 1
        clampScreenIndex()
    }

    private func isSectionTerminal(_ screen: FlowScreen) -> Bool {
        switch screen {
        case .supplementalNotes:
            true
        default:
            false
        }
    }

    private func openCategory(_ category: ContributeReviewCategory) {
        activeCategory = category
        if let index = screens.firstIndex(where: { $0 != .category }) {
            screenIndex = index
        }
        persistIfNeeded()
    }

    private func finishActiveSection() {
        guard let activeCategory else { return }
        sectionStatus[activeCategory] = .complete
        self.activeCategory = nil
        screenIndex = 0
        persistIfNeeded()
    }

    private func leaveActiveSection() {
        guard let activeCategory else { return }
        sectionStatus[activeCategory] = .inProgress
        self.activeCategory = nil
        screenIndex = 0
        persistIfNeeded()
    }

    private func openCategoryNotes() {
        if let index = screens.firstIndex(where: {
            if case .supplementalNotes = $0 { return true }
            return false
        }) {
            screenIndex = index
        }
    }

    /// Keeps `screenIndex` valid when `screens` shrinks (branching answers,
    /// unfinished-draft restore missing toilet/elevator answers).
    private func clampScreenIndex() {
        let maxIndex = max(screens.count - 1, 0)
        guard screenIndex > maxIndex else { return }
        screenIndex = maxIndex
        persistIfNeeded()
    }

    private func goBackOneStep() {
        if screenIndex == 0 {
            requestExit()
            return
        }
        let screen = screens[safe: screenIndex]
        let previous = screens[safe: screenIndex - 1]
        if (screen == .elevatorPhotos || previous == .elevatorAnother) && currentElevatorPassIsEmpty && !completedElevatorPasses.isEmpty {
            restoreLastElevatorPass()
            return
        }
        if (screen == .entranceSectionPhotos || previous == .entranceAnother) && currentEntrancePassIsEmpty && !completedEntrancePasses.isEmpty {
            restoreLastEntrancePass()
            return
        }
        if (screen == .toiletPhotos || previous == .toiletAnother) && currentToiletPassIsEmpty && !completedToiletPasses.isEmpty {
            restoreLastToiletPass()
            return
        }
        if startingFacility == nil, previous == .category {
            leaveActiveSection()
            return
        }
        screenIndex -= 1
        persistIfNeeded()
    }

    private var currentEntrancePassIsEmpty: Bool {
        entranceLocations.isEmpty
            && entranceSectionPhotos.photos.isEmpty
            && lobbyEntranceTags.isEmpty
            && basementEntranceTags.isEmpty
            && lobbyRampAnswer == nil
            && basementRampAnswer == nil
            && lobbyHandrailAnswer == nil
            && basementHandrailAnswer == nil
            && draft.lobby.review.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.lobby.review.photos.isEmpty
            && lobbyRampPhotos.photos.isEmpty
            && lobbyHandrailPhotos.photos.isEmpty
            && basementRampPhotos.photos.isEmpty
            && basementHandrailPhotos.photos.isEmpty
            && draft.basement.review.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.basement.review.photos.isEmpty
            && draft.lobby.hasDropoffRamp == nil
            && draft.basement.hasDropoffRamp == nil
            && draft.lobby.hasRails == nil
            && draft.basement.hasRails == nil
            && draft.lobby.doorType == nil
            && draft.basement.doorType == nil
    }

    private func chooseAnotherEntrance(_ answer: String) {
        completedEntrancePasses.append(
            EntrancePassDraft(
                sectionPhotos: entranceSectionPhotos.photos,
                locations: entranceLocations,
                lobbyTags: lobbyEntranceTags,
                basementTags: basementEntranceTags,
                lobbyRampAnswer: lobbyRampAnswer,
                basementRampAnswer: basementRampAnswer,
                lobbyHandrailAnswer: lobbyHandrailAnswer,
                basementHandrailAnswer: basementHandrailAnswer,
                lobbyRampPhotos: lobbyRampPhotos.photos,
                lobbyHandrailPhotos: lobbyHandrailPhotos.photos,
                basementRampPhotos: basementRampPhotos.photos,
                basementHandrailPhotos: basementHandrailPhotos.photos,
                lobby: draft.lobby,
                basement: draft.basement
            )
        )
        entranceSectionPhotos = ReviewNoteDraft()
        entranceLocations = []
        lobbyEntranceTags = []
        basementEntranceTags = []
        lobbyRampAnswer = nil
        basementRampAnswer = nil
        lobbyHandrailAnswer = nil
        basementHandrailAnswer = nil
        lobbyRampPhotos = ReviewNoteDraft()
        lobbyHandrailPhotos = ReviewNoteDraft()
        basementRampPhotos = ReviewNoteDraft()
        basementHandrailPhotos = ReviewNoteDraft()
        entranceAnotherAnswer = nil
        draft.lobby = EntranceDraft(location: .lobby)
        draft.basement = EntranceDraft(location: .basement)
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .entranceSectionPhotos) {
                screenIndex = index
            }
        } else {
            openCategoryNotes()
        }
        persistIfNeeded()
    }

    private func restoreLastEntrancePass() {
        guard let last = completedEntrancePasses.popLast() else { return }
        entranceSectionPhotos.photos = last.sectionPhotos
        entranceLocations = last.locations
        lobbyEntranceTags = last.lobbyTags
        basementEntranceTags = last.basementTags
        lobbyRampAnswer = last.lobbyRampAnswer
        basementRampAnswer = last.basementRampAnswer
        lobbyHandrailAnswer = last.lobbyHandrailAnswer
        basementHandrailAnswer = last.basementHandrailAnswer
        lobbyRampPhotos.photos = last.lobbyRampPhotos
        lobbyHandrailPhotos.photos = last.lobbyHandrailPhotos
        basementRampPhotos.photos = last.basementRampPhotos
        basementHandrailPhotos.photos = last.basementHandrailPhotos
        entranceAnotherAnswer = nil
        draft.lobby = last.lobby
        draft.basement = last.basement
        if let index = screens.firstIndex(of: .entranceAnother) {
            screenIndex = index
        }
        persistIfNeeded()
    }

    private var currentElevatorPassIsEmpty: Bool {
        elevatorAnswers.isEmpty
            && draft.elevator.review.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.elevator.review.photos.isEmpty
            && elevatorEvidence.values.allSatisfy(\.photos.isEmpty)
    }

    private func chooseAnotherElevator(_ answer: String) {
        completedElevatorPasses.append(
            ElevatorPassDraft(
                answers: elevatorAnswers,
                location: draft.elevator.review.text,
                photos: draft.elevator.review.photos,
                evidence: elevatorEvidence.mapValues(\.photos)
            )
        )
        elevatorAnswers = [:]
        elevatorAnotherAnswer = nil
        elevatorEvidence = [:]
        draft.elevator.review = ReviewNoteDraft()
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .elevatorPhotos) {
                screenIndex = index
            }
        } else {
            openCategoryNotes()
        }
        applyElevatorMapping()
        persistIfNeeded()
    }

    private func restoreLastElevatorPass() {
        guard let last = completedElevatorPasses.popLast() else { return }
        elevatorAnswers = last.answers
        elevatorAnotherAnswer = nil
        draft.elevator.review.text = last.location
        draft.elevator.review.photos = last.photos
        elevatorEvidence = last.evidence.mapValues { photos in
            var note = ReviewNoteDraft()
            note.photos = photos
            return note
        }
        if let index = screens.firstIndex(of: .elevatorAnother) {
            screenIndex = index
        }
        applyElevatorMapping()
        persistIfNeeded()
    }

    private var currentToiletPassIsEmpty: Bool {
        toiletAnswers.isEmpty
            && toiletLocationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && draft.toilet.review.photos.isEmpty
            && toiletEvidence.values.allSatisfy(\.photos.isEmpty)
    }

    private func chooseAnotherToilet(_ answer: String) {
        completedToiletPasses.append(
            ToiletPassDraft(
                answers: toiletAnswers,
                location: toiletLocationNote,
                photos: draft.toilet.review.photos,
                evidence: toiletEvidence.mapValues(\.photos)
            )
        )
        toiletAnswers = [:]
        toiletLocationNote = ""
        toiletAnotherAnswer = nil
        toiletEvidence = [:]
        draft.toilet.review.photos = []
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .toiletPhotos) {
                screenIndex = index
            }
        } else {
            openCategoryNotes()
        }
        applyToiletTagsFromPasses()
        persistIfNeeded()
    }

    private func restoreLastToiletPass() {
        guard let last = completedToiletPasses.popLast() else { return }
        toiletAnswers = last.answers
        toiletLocationNote = last.location
        toiletAnotherAnswer = nil
        draft.toilet.review.photos = last.photos
        toiletEvidence = last.evidence.mapValues { photos in
            var note = ReviewNoteDraft()
            note.photos = photos
            return note
        }
        if let index = screens.firstIndex(of: .toiletAnother) {
            screenIndex = index
        }
        applyToiletTagsFromPasses()
        persistIfNeeded()
    }

    private func requestExit() {
        if hasProgress {
            showExitConfirmation = true
        } else {
            onFinished()
        }
    }

    private func persistIfNeeded() {
        guard hasProgress else { return }
        UnfinishedReviewStore.save(
            place: place,
            startingFacility: startingFacility,
            screenIndex: screenIndex,
            selectedFacilities: Set(sectionStatus.keys.compactMap(\.facilityKind)),
            entranceLocations: entranceLocations,
            lobbyEntranceTags: lobbyEntranceTags,
            basementEntranceTags: basementEntranceTags,
            elevatorTags: elevatorTags,
            toiletTags: toiletTags,
            draft: draft,
            completedCategories: sectionStatus.compactMap { $0.value == .complete ? $0.key.rawValue : nil },
            inProgressCategories: sectionStatus.compactMap { $0.value == .inProgress ? $0.key.rawValue : nil },
            categoryNotes: supplementalNotes.reduce(into: [:]) { notes, item in
                let text = item.value.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { notes[item.key.rawValue] = text }
            }
        )
    }

    private func navTitle(for kind: FacilityKind) -> String {
        switch kind {
        case .entrance: "Entrances"
        case .elevator: "Elevators"
        case .toilet: "Accessible Toilets"
        }
    }

    private func subProgress(for screen: FlowScreen) -> CGFloat {
        let stepNumber = progressBucket(for: screen)
        let stepScreens = screens.filter { progressBucket(for: $0) == stepNumber }
        guard let idx = stepScreens.firstIndex(of: screen), !stepScreens.isEmpty else { return 0.35 }
        return CGFloat(idx + 1) / CGFloat(stepScreens.count)
    }

    private func progressBucket(for screen: FlowScreen) -> Int {
        switch screen {
        case .category, .entranceSectionPhotos, .entranceLocation, .entranceQuestion, .entranceRampFollowup, .entranceHandrailFollowup, .entranceAnother, .entrancePhotos:
            1
        case .elevatorPhotos, .elevatorQuestion, .elevatorLocation, .elevatorAnother:
            2
        case .toiletPhotos, .toiletQuestion, .toiletLocation, .toiletAnother:
            3
        case .pathwayPhotos, .pathwayNotice, .seatingPhotos, .seatingQuestion, .parkingPhotos, .parkingQuestion, .facilityQuestion, .facilityPhotos:
            4
        case .supplementalNotes(let category):
            switch category {
            case .entrance: 1
            case .elevator: 2
            case .toilet: 3
            case .outdoorPathways, .seating, .parking: 4
            }
        }
    }

    private func questionTitle(for kind: FacilityKind) -> String {
        switch kind {
        case .entrance: "What did the entrance have?"
        case .elevator: "What do the elevators have?"
        case .toilet: "What does the toilet have?"
        }
    }

    private func questionTitle(forEntrance location: EntranceLocation) -> String {
        switch location {
        case .lobby: "What does the lobby have?"
        case .basement: "What does the basement have?"
        }
    }

    private func illustrationAssetName(for location: EntranceLocation) -> String {
        switch location {
        case .lobby: "Lobby Asset"
        case .basement: "Basement Asset"
        }
    }

    private func entranceTags(for location: EntranceLocation) -> Set<ContributeTagOption> {
        switch location {
        case .lobby: lobbyEntranceTags
        case .basement: basementEntranceTags
        }
    }

    private func entranceTagsBinding(for location: EntranceLocation) -> Binding<Set<ContributeTagOption>> {
        switch location {
        case .lobby: $lobbyEntranceTags
        case .basement: $basementEntranceTags
        }
    }

    private func rampAnswerBinding(for location: EntranceLocation) -> Binding<String?> {
        Binding(
            get: { location == .lobby ? lobbyRampAnswer : basementRampAnswer },
            set: { newValue in
                if location == .lobby {
                    lobbyRampAnswer = newValue
                    if newValue != "Not sure" { lobbyRampPhotos = ReviewNoteDraft() }
                } else {
                    basementRampAnswer = newValue
                    if newValue != "Not sure" { basementRampPhotos = ReviewNoteDraft() }
                }
            }
        )
    }

    private func handrailAnswerBinding(for location: EntranceLocation) -> Binding<String?> {
        Binding(
            get: { location == .lobby ? lobbyHandrailAnswer : basementHandrailAnswer },
            set: { newValue in
                if location == .lobby {
                    lobbyHandrailAnswer = newValue
                    if newValue != "Not sure" { lobbyHandrailPhotos = ReviewNoteDraft() }
                } else {
                    basementHandrailAnswer = newValue
                    if newValue != "Not sure" { basementHandrailPhotos = ReviewNoteDraft() }
                }
            }
        )
    }

    private func rampPhotos(for location: EntranceLocation) -> ReviewNoteDraft {
        location == .lobby ? lobbyRampPhotos : basementRampPhotos
    }

    private func handrailPhotos(for location: EntranceLocation) -> ReviewNoteDraft {
        location == .lobby ? lobbyHandrailPhotos : basementHandrailPhotos
    }

    private func rampPhotosBinding(for location: EntranceLocation) -> Binding<ReviewNoteDraft> {
        location == .lobby ? $lobbyRampPhotos : $basementRampPhotos
    }

    private func handrailPhotosBinding(for location: EntranceLocation) -> Binding<ReviewNoteDraft> {
        location == .lobby ? $lobbyHandrailPhotos : $basementHandrailPhotos
    }

    private var entranceEvidenceCount: Int {
        lobbyRampPhotos.photos.count + lobbyHandrailPhotos.photos.count
            + basementRampPhotos.photos.count + basementHandrailPhotos.photos.count
    }

    /// Absolute cap for one box: its current photos plus whatever remains of the pass limit of 3.
    private func evidencePhotoLimit(currentCount: Int, totalCount: Int) -> Int {
        currentCount + max(0, 3 - totalCount)
    }

    private func elevatorAnswerBinding(for question: ElevatorQuestion) -> Binding<String?> {
        Binding(
            get: { elevatorAnswers[question] },
            set: { newValue in
                elevatorAnswers[question] = newValue
                if newValue != "Not Sure" { elevatorEvidence[question] = ReviewNoteDraft() }
            }
        )
    }

    private func elevatorEvidenceBinding(for question: ElevatorQuestion) -> Binding<ReviewNoteDraft> {
        Binding(
            get: { elevatorEvidence[question] ?? ReviewNoteDraft() },
            set: { elevatorEvidence[question] = $0 }
        )
    }

    private func toiletEvidenceBinding(for question: ToiletQuestion) -> Binding<ReviewNoteDraft> {
        Binding(
            get: { toiletEvidence[question] ?? ReviewNoteDraft() },
            set: { toiletEvidence[question] = $0 }
        )
    }

    /// Unlike Lobby/Basement's ramps-rails/door questions in the real wizard
    /// (ReviewLobbyBasementStepView), this flow never mirrors one location's
    /// answers onto the other — each location now walks its own full
    /// question set (tag-select → ramp/handrail follow-ups → photos).
    private func entranceNoteBinding(for location: EntranceLocation) -> Binding<ReviewNoteDraft> {
        switch location {
        case .lobby: Binding(get: { draft.lobby.review }, set: { draft.lobby.review = $0 })
        case .basement: Binding(get: { draft.basement.review }, set: { draft.basement.review = $0 })
        }
    }

    private func tagBinding(for kind: FacilityKind) -> Binding<Set<ContributeTagOption>> {
        switch kind {
        // Entrance's tag screens go through entranceTagsBinding(for:) now —
        // this branch is unreachable but kept so the switch stays exhaustive.
        case .entrance: .constant([])
        case .elevator: $elevatorTags
        case .toilet: $toiletTags
        }
    }

    /// The photos the notes step shows: the section's own (last pass for entrance/elevator/toilet),
    /// so photos taken at the start of the section appear there and new ones join them.
    /// Same rule as the shared ContributeFlow.notesPhotos on Android.
    private func notesPhotosBinding(for category: ContributeReviewCategory) -> Binding<ReviewNoteDraft> {
        switch category {
        case .entrance:
            Binding(
                get: { ReviewNoteDraft(photos: completedEntrancePasses.last?.sectionPhotos ?? entranceSectionPhotos.photos) },
                set: { updated in
                    if completedEntrancePasses.isEmpty {
                        entranceSectionPhotos.photos = updated.photos
                    } else {
                        completedEntrancePasses[completedEntrancePasses.count - 1].sectionPhotos = updated.photos
                    }
                }
            )
        case .elevator:
            Binding(
                get: { ReviewNoteDraft(photos: completedElevatorPasses.last?.photos ?? draft.elevator.review.photos) },
                set: { updated in
                    if completedElevatorPasses.isEmpty {
                        draft.elevator.review.photos = updated.photos
                    } else {
                        completedElevatorPasses[completedElevatorPasses.count - 1].photos = updated.photos
                    }
                }
            )
        case .toilet:
            Binding(
                get: { ReviewNoteDraft(photos: completedToiletPasses.last?.photos ?? draft.toilet.review.photos) },
                set: { updated in
                    if completedToiletPasses.isEmpty {
                        draft.toilet.review.photos = updated.photos
                    } else {
                        completedToiletPasses[completedToiletPasses.count - 1].photos = updated.photos
                    }
                }
            )
        case .outdoorPathways:
            supplementalNoteBinding(for: .outdoorPathways)
        case .seating:
            $seatingNote
        case .parking:
            $parkingNote
        }
    }

    private func supplementalNoteBinding(for category: ContributeReviewCategory) -> Binding<ReviewNoteDraft> {
        Binding(
            get: { supplementalNotes[category] ?? ReviewNoteDraft() },
            set: { supplementalNotes[category] = $0 }
        )
    }

    private func noteBinding(for kind: FacilityKind) -> Binding<ReviewNoteDraft> {
        switch kind {
        // Entrance's photos/notes screens go through entranceNoteBinding(for:) now.
        case .entrance: .constant(ReviewNoteDraft())
        case .elevator:
            Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 })
        case .toilet:
            Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 })
        }
    }

    private func applyMapping(for kind: FacilityKind) {
        switch kind {
        // Entrance/elevator map from their own screen cases now
        // (applyEntranceMapping(for:) / applyElevatorMapping()).
        case .entrance, .elevator: break
        case .toilet: applyToiletMapping()
        }
    }

    private func applyEntranceSectionPhotos() {
        let sectionPhotos = entranceSectionPhotos.photos
        guard !sectionPhotos.isEmpty else { return }
        let target: EntranceLocation = entranceLocations.contains(.lobby) ? .lobby : .basement
        switch target {
        case .lobby:
            let existingIDs = Set(draft.lobby.review.photos.map(\.id))
            draft.lobby.review.photos.append(contentsOf: sectionPhotos.filter { !existingIDs.contains($0.id) })
        case .basement:
            let existingIDs = Set(draft.basement.review.photos.map(\.id))
            draft.basement.review.photos.append(contentsOf: sectionPhotos.filter { !existingIDs.contains($0.id) })
        }
    }

    private func applyEntranceMapping(for location: EntranceLocation) {
        let tags = entranceTags(for: location)
        let hasRamp = tags.contains { $0.label == "RAMP" }
        let hasRail = tags.contains { $0.label == "HANDRAIL" }
        let door: DoorType? =
            if tags.contains(where: { $0.label == "AUTOMATIC DOORS" }) { .automatic }
            else if tags.contains(where: { $0.label == "MANUAL DOORS" }) { .manual }
            else { nil }
        switch location {
        case .lobby:
            draft.lobby.hasDropoffRamp = hasRamp ? true : nil
            draft.lobby.hasRails = hasRail ? true : nil
            draft.lobby.doorType = door
        case .basement:
            draft.basement.hasDropoffRamp = hasRamp ? true : nil
            draft.basement.hasRails = hasRail ? true : nil
            draft.basement.doorType = door
        }
    }

    /// Maps the Ramp follow-up's 4-way answer onto `EntranceDraft.easeOfAccess`
    /// — a UI-only field already (see its declaration comment), same
    /// precedent applies here.
    private func applyRampAnswer(for location: EntranceLocation) {
        let answer = location == .lobby ? lobbyRampAnswer : basementRampAnswer
        let ease: EaseOfAccess? = switch answer {
        case "Yes": .easy
        case "With a push": .needsAssistance
        case "Too steep": .cantGoThrough
        default: nil
        }
        switch location {
        case .lobby: draft.lobby.easeOfAccess = ease
        case .basement: draft.basement.easeOfAccess = ease
        }
    }

    /// Each elevator question's "Yes" earns its matching chip; "No" on the
    /// width/space questions is a `.tooSmall` blocker, matching the
    /// contract's "blockers only when not accessible" rule.
    private func allElevatorPasses() -> [ElevatorPassDraft] {
        var passes = completedElevatorPasses
        let hasCurrent = !elevatorAnswers.isEmpty
            || !draft.elevator.review.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.elevator.review.photos.isEmpty
        if hasCurrent {
            passes.append(
                ElevatorPassDraft(
                    answers: elevatorAnswers,
                    location: draft.elevator.review.text,
                    photos: draft.elevator.review.photos,
                    evidence: elevatorEvidence.mapValues(\.photos)
                )
            )
        }
        return passes
    }

    private func applyElevatorMapping() {
        let passes = allElevatorPasses()
        let catalog = ContributeReviewTags.tags(for: .elevator)
        elevatorTags = Set(
            ElevatorQuestion.allCases
                .filter { question in passes.contains { $0.answers[question] == "Yes" } }
                .compactMap { question in catalog.first { $0.label == question.tagLabel } }
        )

        let anyAnswers = passes.contains { !$0.answers.isEmpty }
        draft.elevator.exists = anyAnswers ? true : nil
        let anyNo = passes.contains { $0.answers.values.contains("No") }
        let fullyAccessible = !passes.isEmpty && passes.allSatisfy { pass in
            ElevatorQuestion.allCases.allSatisfy { pass.answers[$0] != nil }
                && !pass.answers.values.contains("No")
        }
        if anyAnswers {
            draft.elevator.wheelchairAccessible = anyNo ? false : (fullyAccessible ? true : nil)
        }
        if draft.elevator.wheelchairAccessible == true {
            draft.elevator.blockers = []
        } else if passes.contains(where: { $0.answers[.wideEntrance] == "No" || $0.answers[.spaceToManeuver] == "No" }) {
            draft.elevator.blockers = [.tooSmall]
        }
    }

    /// Each saved entrance becomes its own report. The in-progress pass is included if it still has answers.
    private func foldEntrancePassesIntoDraft() {
        var passes = completedEntrancePasses
        if !currentEntrancePassIsEmpty {
            passes.append(
                EntrancePassDraft(
                    sectionPhotos: entranceSectionPhotos.photos,
                    locations: entranceLocations,
                    lobbyTags: lobbyEntranceTags,
                    basementTags: basementEntranceTags,
                    lobbyRampAnswer: lobbyRampAnswer,
                    basementRampAnswer: basementRampAnswer,
                    lobbyHandrailAnswer: lobbyHandrailAnswer,
                    basementHandrailAnswer: basementHandrailAnswer,
                    lobbyRampPhotos: lobbyRampPhotos.photos,
                    lobbyHandrailPhotos: lobbyHandrailPhotos.photos,
                    basementRampPhotos: basementRampPhotos.photos,
                    basementHandrailPhotos: basementHandrailPhotos.photos,
                    lobby: draft.lobby,
                    basement: draft.basement
                )
            )
        }
        guard !passes.isEmpty else { return }
        draft.entrancePassSnapshots = passes.map {
            EntrancePassSnapshot(
                sectionPhotos: $0.sectionPhotos,
                locations: $0.locations,
                lobby: $0.lobby,
                basement: $0.basement
            )
        }
    }

    /// The API stores one elevator. Every pass is written into that note before submit.
    private func foldElevatorPassesIntoDraft() {
        let passes = allElevatorPasses()
        guard !passes.isEmpty else { return }
        applyElevatorMapping()
        var blocks: [String] = []
        for (index, pass) in passes.enumerated() {
            var lines: [String] = []
            let location = pass.location.trimmingCharacters(in: .whitespacesAndNewlines)
            if !location.isEmpty { lines.append("Location: \(location)") }
            for question in ElevatorQuestion.allCases {
                if let answer = pass.answers[question] {
                    lines.append("\(question.eyebrow): \(answer)")
                }
            }
            guard !lines.isEmpty else { continue }
            if passes.count > 1 {
                blocks.append("[Elevator \(index + 1)]\n" + lines.joined(separator: "\n"))
            } else {
                blocks.append(lines.joined(separator: "\n"))
            }
        }
        draft.elevator.review.text = blocks.joined(separator: "\n\n")
        draft.elevator.review.photos = passes.flatMap(\.photos)
    }

    private func applyToiletMapping() {
        applyToiletTagsFromPasses()
    }

    private func allToiletPasses() -> [ToiletPassDraft] {
        var passes = completedToiletPasses
        let hasCurrent = !toiletAnswers.isEmpty
            || !toiletLocationNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || !draft.toilet.review.photos.isEmpty
        if hasCurrent {
            passes.append(
                ToiletPassDraft(
                    answers: toiletAnswers,
                    location: toiletLocationNote,
                    photos: draft.toilet.review.photos,
                    evidence: toiletEvidence.mapValues(\.photos)
                )
            )
        }
        return passes
    }

    private func applyToiletTagsFromPasses() {
        var tags = Set<ContributeTagOption>()
        for pass in allToiletPasses() {
            switch pass.answers[.doorKind] {
            case "Automatic":
                tags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "AUTOMATIC DOORS"))
            case "Sliding":
                tags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "SLIDING DOORS"))
            case "Manual":
                tags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "MANUAL DOORS"))
            default:
                break
            }
            if pass.answers[.grabBars] == "Yes" || pass.answers[.grabBars] == "Positioned awkwardly" {
                tags.insert(ContributeTagOption(symbol: "figure.roll", label: "GRAB BARS"))
            }
            if pass.answers[.space] == "Yes" {
                tags.insert(ContributeTagOption(symbol: "arrow.up.and.down.and.arrow.left.and.right", label: "SPACE TO MANEUVER"))
            }
            if pass.answers[.sink] == "Yes" {
                tags.insert(ContributeTagOption(symbol: "sink.fill", label: "REACHABLE SINK"))
            }
            if let emergency = pass.answers[.emergency], emergency != "There is no emergency button" {
                tags.insert(ContributeTagOption(symbol: "bell.fill", label: "EMERGENCY BUTTON"))
            }
        }
        toiletTags = tags
        let passes = allToiletPasses()
        if passes.contains(where: { !$0.answers.isEmpty || !$0.location.isEmpty || !$0.photos.isEmpty }) {
            draft.toilet.hasDisabledToilet = true
        }
    }

    /// The API stores one toilet. Every pass is written into that note before submit.
    private func foldToiletPassesIntoDraft() {
        let passes = allToiletPasses()
        guard !passes.isEmpty else { return }
        applyToiletTagsFromPasses()
        var blocks: [String] = []
        for (index, pass) in passes.enumerated() {
            var lines: [String] = []
            let location = pass.location.trimmingCharacters(in: .whitespacesAndNewlines)
            if !location.isEmpty { lines.append("Location: \(location)") }
            for question in ToiletQuestion.allCases {
                if let answer = pass.answers[question] {
                    lines.append("\(question.eyebrow): \(answer)")
                }
            }
            guard !lines.isEmpty else { continue }
            if passes.count > 1 {
                blocks.append("[Toilet \(index + 1)]\n" + lines.joined(separator: "\n"))
            } else {
                blocks.append(lines.joined(separator: "\n"))
            }
        }
        let existing = draft.toilet.review.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let passText = blocks.joined(separator: "\n\n")
        if passText.isEmpty {
            draft.toilet.review.text = existing
        } else if existing.isEmpty {
            draft.toilet.review.text = passText
        } else {
            draft.toilet.review.text = "\(passText)\n\n\(existing)"
        }
        let passPhotoIDs = Set(passes.flatMap(\.photos).map(\.id))
        let extras = draft.toilet.review.photos.filter { !passPhotoIDs.contains($0.id) }
        draft.toilet.review.photos = passes.flatMap(\.photos) + extras
    }

    private func toiletAnswerBinding(for question: ToiletQuestion) -> Binding<String?> {
        Binding(
            get: { toiletAnswers[question] },
            set: { newValue in
                toiletAnswers[question] = newValue
                if newValue != "Not sure" { toiletEvidence[question] = ReviewNoteDraft() }
            }
        )
    }

    private func applyToiletQuestionMapping(_ question: ToiletQuestion) {
        _ = question
        applyToiletTagsFromPasses()
    }

    private func applyToiletLocationMapping() {
        // Free-text toilet location note is kept in toiletLocationNote, not auto-populated into main review text
    }

    private func categoryNotesForSubmit() -> [String: String] {
        var notes: [String: String] = [:]
        for category in ContributeReviewCategory.allCases {
            let text = supplementalNotes[category]?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !text.isEmpty { notes[category.rawValue] = text }
        }
        return notes
    }

    private func assembledContribution() -> AssembledContribution {
        var passes = completedEntrancePasses
        if !currentEntrancePassIsEmpty {
            passes.append(
                EntrancePassDraft(
                    sectionPhotos: entranceSectionPhotos.photos,
                    locations: entranceLocations,
                    lobbyTags: lobbyEntranceTags,
                    basementTags: basementEntranceTags,
                    lobbyRampAnswer: lobbyRampAnswer,
                    basementRampAnswer: basementRampAnswer,
                    lobbyHandrailAnswer: lobbyHandrailAnswer,
                    basementHandrailAnswer: basementHandrailAnswer,
                    lobbyRampPhotos: lobbyRampPhotos.photos,
                    lobbyHandrailPhotos: lobbyHandrailPhotos.photos,
                    basementRampPhotos: basementRampPhotos.photos,
                    basementHandrailPhotos: basementHandrailPhotos.photos,
                    lobby: draft.lobby,
                    basement: draft.basement
                )
            )
        }
        var elevators = completedElevatorPasses
        if !currentElevatorPassIsEmpty {
            elevators.append(
                ElevatorPassDraft(
                    answers: elevatorAnswers,
                    location: draft.elevator.review.text,
                    photos: draft.elevator.review.photos,
                    evidence: elevatorEvidence.mapValues(\.photos)
                )
            )
        }
        var toilets = completedToiletPasses
        if !currentToiletPassIsEmpty {
            toilets.append(
                ToiletPassDraft(
                    answers: toiletAnswers,
                    location: toiletLocationNote,
                    photos: draft.toilet.review.photos,
                    evidence: toiletEvidence.mapValues(\.photos)
                )
            )
        }
        return ContributeFlowBridge.assemble(
            placeId: place.reviewPlaceId,
            submissionId: draft.submissionId.uuidString,
            wheelchair: reviewPersona == .wheelchair,
            entrances: passes,
            elevators: elevators,
            toilets: toilets,
            pathwayNotices: pathwayNotices,
            pathwayPhotos: supplementalNotes[.outdoorPathways]?.photos ?? [],
            seatingAnswer: seatingAnswer,
            seatingPhotos: seatingNote.photos,
            parkingAnswer: parkingAnswer,
            parkingPhotos: parkingNote.photos,
            categoryNotes: categoryNotesForSubmit()
        )
    }

    private func submit() async {
        guard !isSubmitting else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            try? await Task.sleep(nanoseconds: 500_000_000)
            UnfinishedReviewStore.clear(for: place)
            isSubmitted = true
            onSubmitted?(ContributeReviewSubmission(reviewId: nil, placeId: nil))
            return
        }
        #endif

        do {
            let response = try await ReviewService.shared.submit(contribution: assembledContribution())
            UnfinishedReviewStore.clear(for: place)
            isSubmitted = true
            onSubmitted?(ContributeReviewSubmission(
                reviewId: UUID(uuidString: response.reviewId),
                placeId: response.placeId
            ))
        } catch {
            print("[ContributeReviewFlow] Submit failed: \(error)")
            submitError = Self.submitErrorMessage(for: error)
            // A session that lapsed mid-flow is the one failure the user can
            // actually clear, and the draft is already persisted — send them
            // to sign-in rather than leaving them to guess.
            if Self.isAuthFailure(error) {
                showLogin = true
            }
        }
    }

    /// `submit-accessibility-review` answers 401 "sign in required" without a
    /// user JWT, and Storage rejects the photo upload that precedes it with a
    /// row-level-security error. Both used to surface as "check your
    /// connection", which sends the user to fix the one thing that is fine.
    private static func isAuthFailure(_ error: Error) -> Bool {
        let text = "\(error)".lowercased()
        return text.contains("sign in required")
            || text.contains("row-level security")
            || text.contains("unauthorized")
            || text.contains("401")
            || text.contains("403")
    }

    private static func submitErrorMessage(for error: Error) -> String {
        isAuthFailure(error)
            ? "You need to be signed in to post a review. Sign in and submit again — your answers are saved."
            : "Check your connection and try again."
    }
}

struct EntrancePassDraft {
    var sectionPhotos: [ReviewPhotoDraft]
    var locations: Set<EntranceLocation>
    var lobbyTags: Set<ContributeTagOption>
    var basementTags: Set<ContributeTagOption>
    var lobbyRampAnswer: String?
    var basementRampAnswer: String?
    var lobbyHandrailAnswer: String?
    var basementHandrailAnswer: String?
    var lobbyRampPhotos: [ReviewPhotoDraft]
    var lobbyHandrailPhotos: [ReviewPhotoDraft]
    var basementRampPhotos: [ReviewPhotoDraft]
    var basementHandrailPhotos: [ReviewPhotoDraft]
    var lobby: EntranceDraft
    var basement: EntranceDraft
}

struct ElevatorPassDraft {
    var answers: [ElevatorQuestion: String]
    var location: String
    var photos: [ReviewPhotoDraft]
    var evidence: [ElevatorQuestion: [ReviewPhotoDraft]]
}

struct ToiletPassDraft {
    var answers: [ToiletQuestion: String]
    var location: String
    var photos: [ReviewPhotoDraft]
    var evidence: [ToiletQuestion: [ReviewPhotoDraft]]
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    ContributeReviewFlowView(
        place: Place.fromSearchResult(name: "Park23 Mall", category: "Mall", coordinate: .init(latitude: 0, longitude: 0)),
        onFinished: {}
    )
    .environmentObject(AuthSessionStore())
}
