import SwiftUI

/// Fired when the backend accepts a contribute review — before the user taps Done.
struct ContributeReviewSubmission {
    let reviewId: UUID?
    let placeId: String?
}

/// Contribute flow backed by the Cloudflare API, with local draft persistence.
/// Primary-user (wheelchair) screen sequence. Question copy still follows
/// `ReviewPersona`; the secondary-user flow is not built yet.
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

    @State private var selectedFacilities: Set<FacilityKind>
    @State private var selectedCategories: Set<ContributeReviewCategory>
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
        var categories = Set<ContributeReviewCategory>()
        var facilities = Set<FacilityKind>()
        var entranceLocs = Set<EntranceLocation>()
        var lobbyTags = Set<ContributeTagOption>()
        var basementTags = Set<ContributeTagOption>()
        var elevTags = Set<ContributeTagOption>()
        var toiletTagsInit = Set<ContributeTagOption>()

        if !ignoreDraftRestore, let snap = UnfinishedReviewStore.snapshot(for: place) {
            startIndex = snap.screenIndex
            facilities = Set(snap.selectedFacilities.compactMap(FacilityKind.init(rawValue:)))
            categories = Set(facilities.compactMap(ContributeReviewCategory.init(facilityKind:)))
            entranceLocs = Set(snap.entranceLocations.compactMap(EntranceLocation.init(rawValue:)))
            lobbyTags = UnfinishedReviewStore.restoreTags(snap.lobbyEntranceTags, forEntrance: .lobby)
            basementTags = UnfinishedReviewStore.restoreTags(snap.basementEntranceTags, forEntrance: .basement)
            elevTags = UnfinishedReviewStore.restoreTags(snap.elevatorTags, for: .elevator)
            toiletTagsInit = UnfinishedReviewStore.restoreTags(snap.toiletTags, for: .toilet)
            draft.lobby.review.text = snap.lobbyNote
            draft.basement.review.text = snap.basementNote
            draft.elevator.review.text = snap.elevatorNote
            draft.toilet.review.text = snap.toiletNote
        }

        if let start = startingFacility, let cat = ContributeReviewCategory(facilityKind: start) {
            categories = [cat]
            facilities = [start]
        }

        _draft = StateObject(wrappedValue: draft)
        _selectedFacilities = State(initialValue: facilities)
        _selectedCategories = State(initialValue: categories)
        _supplementalNotes = State(initialValue: [:])
        _screenIndex = State(initialValue: startIndex)
        _entranceLocations = State(initialValue: entranceLocs)
        _lobbyEntranceTags = State(initialValue: lobbyTags)
        _basementEntranceTags = State(initialValue: basementTags)
        _elevatorTags = State(initialValue: elevTags)
        _toiletTags = State(initialValue: toiletTagsInit)
    }

    private var orderedFacilities: [FacilityKind] {
        [FacilityKind.entrance, .elevator, .toilet].compactMap { kind in
            guard let cat = ContributeReviewCategory(facilityKind: kind),
                  selectedCategories.contains(cat) else { return nil }
            return kind
        }
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
        case finalReview
    }

    private var screens: [FlowScreen] {
        var list: [FlowScreen] = []
        if startingFacility == nil {
            list.append(.category)
        }
        for kind in orderedFacilities {
            switch kind {
            case .entrance:
                list.append(.entranceSectionPhotos)
                list.append(.entranceLocation)
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
            case .elevator:
                list.append(.elevatorPhotos)
                list.append(.elevatorQuestion(.wideEntrance))
                if elevatorAnswers[.wideEntrance] != "No" {
                    list.append(.elevatorQuestion(.spaceToManeuver))
                    list.append(.elevatorQuestion(.reachableButtons))
                }
                list.append(.elevatorLocation)
                list.append(.elevatorAnother)
            case .toilet:
                list.append(.toiletPhotos)
                for question in ToiletQuestion.allCases {
                    list.append(.toiletQuestion(question))
                }
                list.append(.toiletLocation)
                list.append(.toiletAnother)
            }
        }
        for category in ContributeReviewCategory.supplemental where selectedCategories.contains(category) {
            switch category {
            case .outdoorPathways:
                list.append(.pathwayPhotos)
                list.append(.pathwayNotice)
            case .seating:
                list.append(.seatingPhotos)
                list.append(.seatingQuestion)
            case .parking:
                list.append(.parkingPhotos)
                list.append(.parkingQuestion)
            case .entrance, .elevator, .toilet:
                list.append(.supplementalNotes(category))
            }
        }
        list.append(.finalReview)
        return list
    }

    private var progressScreens: [FlowScreen] { screens }

    private func progress(for screen: FlowScreen) -> (current: Int, total: Int) {
        (progressScreens.firstIndex(of: screen) ?? 0, max(progressScreens.count, 1))
    }

    private var hasProgress: Bool {
        screenIndex > 0
            || !selectedCategories.isEmpty
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
                selection: $selectedCategories,
                onBack: requestExit,
                onContinue: {
                    selectedFacilities = Set(orderedFacilities)
                    goNext()
                }
            )
            .onChange(of: selectedCategories) { _, _ in
                selectedFacilities = Set(orderedFacilities)
                clampScreenIndex()
            }
        case .pathwayPhotos:
            ContributeEntrancePhotosStepView(
                navTitle: "Outdoor Pathways",
                illustrationAssetName: "pathwayicon",
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
                onBack: goBackOneStep,
                onContinue: goNext
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
                note: entranceNoteBinding(for: location),
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
                note: entranceNoteBinding(for: location),
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
                note: Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 }),
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
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
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
        case .finalReview:
            ContributePhotosNotesStepView(
                facilityName: "Review",
                navTitle: "Final Review",
                progress: progress(for: screen),
                note: finalReviewNoteBinding(),
                remainingPhotoSlots: max(0, ReviewNoteDraft.maxPhotos - draft.allReviewPhotos.count),
                isLastStep: true,
                isSubmitting: isSubmitting,
                onBack: goBackOneStep,
                onContinue: {
                    Task { await submit() }
                }
            )
        }
    }

    private func goNext() {
        persistIfNeeded()
        screenIndex += 1
        clampScreenIndex()
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
        entranceAnotherAnswer = nil
        draft.lobby = EntranceDraft(location: .lobby)
        draft.basement = EntranceDraft(location: .basement)
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .entranceSectionPhotos) {
                screenIndex = index
            }
        } else if let index = screens.firstIndex(of: .entranceAnother) {
            screenIndex = index + 1
            clampScreenIndex()
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
    }

    private func chooseAnotherElevator(_ answer: String) {
        completedElevatorPasses.append(
            ElevatorPassDraft(
                answers: elevatorAnswers,
                location: draft.elevator.review.text,
                photos: draft.elevator.review.photos
            )
        )
        elevatorAnswers = [:]
        elevatorAnotherAnswer = nil
        draft.elevator.review = ReviewNoteDraft()
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .elevatorPhotos) {
                screenIndex = index
            }
        } else if let index = screens.firstIndex(of: .elevatorAnother) {
            screenIndex = index + 1
            clampScreenIndex()
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
    }

    private func chooseAnotherToilet(_ answer: String) {
        completedToiletPasses.append(
            ToiletPassDraft(
                answers: toiletAnswers,
                location: toiletLocationNote,
                photos: draft.toilet.review.photos
            )
        )
        toiletAnswers = [:]
        toiletLocationNote = ""
        toiletAnotherAnswer = nil
        draft.toilet.review.photos = []
        if answer == "Yes" {
            if let index = screens.firstIndex(of: .toiletPhotos) {
                screenIndex = index
            }
        } else if let index = screens.firstIndex(of: .toiletAnother) {
            screenIndex = index + 1
            clampScreenIndex()
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
            selectedFacilities: selectedFacilities,
            entranceLocations: entranceLocations,
            lobbyEntranceTags: lobbyEntranceTags,
            basementEntranceTags: basementEntranceTags,
            elevatorTags: elevatorTags,
            toiletTags: toiletTags,
            draft: draft
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
        let stepNumber: Int = switch screen {
        case .category, .entranceSectionPhotos, .entranceLocation, .entranceQuestion, .entranceRampFollowup, .entranceHandrailFollowup, .entranceAnother, .entrancePhotos: 1
        case .elevatorPhotos, .elevatorQuestion, .elevatorLocation, .elevatorAnother: 2
        case .toiletPhotos, .toiletQuestion, .toiletLocation, .toiletAnother: 3
        case .pathwayPhotos, .pathwayNotice, .seatingPhotos, .seatingQuestion, .parkingPhotos, .parkingQuestion, .facilityQuestion, .facilityPhotos, .supplementalNotes, .finalReview: 4
        }

        let stepScreens = screens.filter { s in
            switch s {
            case .category, .entranceSectionPhotos, .entranceLocation, .entranceQuestion, .entranceRampFollowup, .entranceHandrailFollowup, .entranceAnother, .entrancePhotos: stepNumber == 1
            case .elevatorPhotos, .elevatorQuestion, .elevatorLocation, .elevatorAnother: stepNumber == 2
            case .toiletPhotos, .toiletQuestion, .toiletLocation, .toiletAnother: stepNumber == 3
            case .pathwayPhotos, .pathwayNotice, .seatingPhotos, .seatingQuestion, .parkingPhotos, .parkingQuestion, .facilityQuestion, .facilityPhotos, .supplementalNotes, .finalReview: stepNumber == 4
            }
        }

        guard let idx = stepScreens.firstIndex(of: screen), !stepScreens.isEmpty else { return 0.35 }
        return CGFloat(idx + 1) / CGFloat(stepScreens.count)
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
        switch location {
        case .lobby: $lobbyRampAnswer
        case .basement: $basementRampAnswer
        }
    }

    private func handrailAnswerBinding(for location: EntranceLocation) -> Binding<String?> {
        switch location {
        case .lobby: $lobbyHandrailAnswer
        case .basement: $basementHandrailAnswer
        }
    }

    private func elevatorAnswerBinding(for question: ElevatorQuestion) -> Binding<String?> {
        Binding(
            get: { elevatorAnswers[question] },
            set: { elevatorAnswers[question] = $0 }
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

    /// Final Review shows every photo from earlier steps in one strip while
    /// keeping per-facility ownership for submit. New photos land on the
    /// last facility the user actually contributed to in this flow.
    private func finalReviewNoteBinding() -> Binding<ReviewNoteDraft> {
        Binding(
            get: {
                var merged = ReviewNoteDraft()
                merged.text = draft.toilet.review.text
                merged.photos = draft.allReviewPhotos + seatingNote.photos + parkingNote.photos
                return merged
            },
            set: { newValue in
                let facilityPhotos = draft.allReviewPhotos
                let seatingPhotos = seatingNote.photos
                let parkingPhotos = parkingNote.photos
                let facilityIDs = Set(facilityPhotos.map(\.id))
                let seatingIDs = Set(seatingPhotos.map(\.id))
                let parkingIDs = Set(parkingPhotos.map(\.id))
                let newIDs = Set(newValue.photos.map(\.id))

                draft.toilet.review.text = newValue.text

                for id in facilityIDs.subtracting(newIDs) {
                    draft.removeReviewPhoto(id: id)
                }
                for id in seatingIDs.subtracting(newIDs) {
                    seatingNote.removePhoto(id: id)
                }
                for id in parkingIDs.subtracting(newIDs) {
                    parkingNote.removePhoto(id: id)
                }

                for photo in newValue.photos {
                    if facilityIDs.contains(photo.id) {
                        draft.updateReviewPhotoCaption(id: photo.id, caption: photo.caption)
                    }
                    if seatingIDs.contains(photo.id) {
                        seatingNote.updatePhotoCaption(id: photo.id, caption: photo.caption)
                    }
                    if parkingIDs.contains(photo.id) {
                        parkingNote.updatePhotoCaption(id: photo.id, caption: photo.caption)
                    }
                }

                for photo in newValue.photos where !facilityIDs.contains(photo.id) && !seatingIDs.contains(photo.id) && !parkingIDs.contains(photo.id) {
                    appendFinalReviewPhoto(photo)
                }
            }
        )
    }

    /// Last facility in the walk that carries any structured answers, notes,
    /// or photos — where Final Review additions should be filed.
    private var lastContributedFacility: FacilityKind {
        for kind in orderedFacilities.reversed() {
            if facilityHasContribution(kind) { return kind }
        }
        return orderedFacilities.last ?? .toilet
    }

    private func facilityHasContribution(_ kind: FacilityKind) -> Bool {
        switch kind {
        case .entrance:
            if !completedEntrancePasses.isEmpty { return true }
            return entranceLocations.contains { location in
                let entrance = location == .lobby ? draft.lobby : draft.basement
                return !entranceTags(for: location).isEmpty
                    || !entrance.review.text.isEmpty
                    || !entrance.review.photos.isEmpty
                    || entrance.hasDropoffRamp != nil
                    || entrance.hasRails != nil
                    || entrance.doorType != nil
            }
        case .elevator:
            return !elevatorAnswers.isEmpty
                || !completedElevatorPasses.isEmpty
                || !draft.elevator.review.text.isEmpty
                || !draft.elevator.review.photos.isEmpty
                || draft.elevator.exists != nil
                || draft.elevator.wheelchairAccessible != nil
        case .toilet:
            return !toiletAnswers.isEmpty
                || !completedToiletPasses.isEmpty
                || !toiletLocationNote.isEmpty
                || !toiletTags.isEmpty
                || !draft.toilet.review.text.isEmpty
                || !draft.toilet.review.photos.isEmpty
                || draft.toilet.hasDisabledToilet != nil
        }
    }

    private var lastContributedEntranceLocation: EntranceLocation {
        for location in EntranceLocation.allCases.reversed() where entranceLocations.contains(location) {
            let entrance = location == .lobby ? draft.lobby : draft.basement
            if !entranceTags(for: location).isEmpty
                || !entrance.review.text.isEmpty
                || !entrance.review.photos.isEmpty
                || entrance.hasDropoffRamp != nil
                || entrance.hasRails != nil
                || entrance.doorType != nil {
                return location
            }
        }
        return entranceLocations.sorted { $0.rawValue < $1.rawValue }.last ?? .lobby
    }

    private func appendFinalReviewPhoto(_ photo: ReviewPhotoDraft) {
        switch lastContributedFacility {
        case .entrance:
            switch lastContributedEntranceLocation {
            case .lobby: draft.lobby.review.photos.append(photo)
            case .basement: draft.basement.review.photos.append(photo)
            }
        case .elevator:
            draft.elevator.review.photos.append(photo)
        case .toilet:
            draft.toilet.review.photos.append(photo)
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
                    photos: draft.elevator.review.photos
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
                    photos: draft.toilet.review.photos
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
            set: { toiletAnswers[question] = $0 }
        )
    }

    private func applyToiletQuestionMapping(_ question: ToiletQuestion) {
        _ = question
        applyToiletTagsFromPasses()
    }

    private func applyToiletLocationMapping() {
        // Free-text toilet location note is kept in toiletLocationNote, not auto-populated into main review text
    }

    private func appendSupplementalNotesToDraft() {
        var blocks: [String] = []
        for category in ContributeReviewCategory.supplemental {
            if category == .outdoorPathways, !pathwayNotices.isEmpty {
                let noticed = ContributePathwayNoticeStepView.options.filter { pathwayNotices.contains($0) }
                blocks.append("[Outdoor Pathways]\nNoticed: \(noticed.joined(separator: ", "))")
            }
            if category == .seating || category == .parking { continue }
            guard let note = supplementalNotes[category], !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            blocks.append("[\(category.menuTitle)]\n\(note.text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        if let answer = seatingAnswer {
            blocks.append("[Seating]\nWheelchair friendly seating: \(answer)")
        }
        if let answer = parkingAnswer {
            blocks.append("[Parking]\nAccessible parking: \(answer)")
        }
        if !blocks.isEmpty {
            let prefix = blocks.joined(separator: "\n\n")
            if draft.toilet.review.text.isEmpty {
                draft.toilet.review.text = prefix
            } else {
                draft.toilet.review.text = "\(prefix)\n\n\(draft.toilet.review.text)"
            }
        }
        let existingIDs = Set(draft.toilet.review.photos.map(\.id))
        draft.toilet.review.photos.append(contentsOf: seatingNote.photos.filter { !existingIDs.contains($0.id) })
        let afterSeating = Set(draft.toilet.review.photos.map(\.id))
        draft.toilet.review.photos.append(contentsOf: parkingNote.photos.filter { !afterSeating.contains($0.id) })
    }

    private func submit() async {
        guard !isSubmitting else { return }
        foldEntrancePassesIntoDraft()
        foldElevatorPassesIntoDraft()
        foldToiletPassesIntoDraft()
        appendSupplementalNotesToDraft()
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
            let response = try await ReviewService.shared.submit(draft)
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

private struct EntrancePassDraft {
    var sectionPhotos: [ReviewPhotoDraft]
    var locations: Set<EntranceLocation>
    var lobbyTags: Set<ContributeTagOption>
    var basementTags: Set<ContributeTagOption>
    var lobbyRampAnswer: String?
    var basementRampAnswer: String?
    var lobbyHandrailAnswer: String?
    var basementHandrailAnswer: String?
    var lobby: EntranceDraft
    var basement: EntranceDraft
}

private struct ElevatorPassDraft {
    var answers: [ElevatorQuestion: String]
    var location: String
    var photos: [ReviewPhotoDraft]
}

private struct ToiletPassDraft {
    var answers: [ToiletQuestion: String]
    var location: String
    var photos: [ReviewPhotoDraft]
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
