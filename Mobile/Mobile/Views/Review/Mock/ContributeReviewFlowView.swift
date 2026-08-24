import SwiftUI

/// New "Contribute a Review" flow — real Supabase submit with draft persistence.
struct ContributeReviewFlowView: View {
    let place: Place
    let startingFacility: FacilityKind?
    let initialScreenIndex: Int
    /// Fired the moment the backend accepts the review — BEFORE the user taps
    /// Done on the confirmation screen — so the presenting page can stage its
    /// "Your review submitted!" state. `onFinished` alone can't tell a
    /// submission from a cancel.
    let onSubmitted: (() -> Void)?
    let onFinished: () -> Void

    @StateObject private var draft: ReviewDraft

    @State private var selectedFacilities: Set<FacilityKind>
    @State private var screenIndex: Int
    @State private var entranceLocations: Set<EntranceLocation>
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
    /// One answer per `ElevatorQuestion` — the elevator section asks these
    /// instead of showing a chip multi-select; `applyElevatorMapping()`
    /// turns them back into `elevatorTags`.
    @State private var elevatorAnswers: [ElevatorQuestion: String] = [:]
    @State private var elevatorTags: Set<ContributeTagOption> = []
    @State private var toiletInitialAnswer: String?
    @State private var toiletAnswers: [ToiletQuestion: String] = [:]
    @State private var toiletLocationNote: String = ""
    @State private var toiletTags: Set<ContributeTagOption> = []
    @State private var isSubmitted = false
    @State private var submitError: String?
    @State private var showExitConfirmation = false
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var showLogin = false

    init(
        place: Place,
        startingFacility: FacilityKind? = nil,
        initialScreenIndex: Int = 0,
        onSubmitted: (() -> Void)? = nil,
        onFinished: @escaping () -> Void
    ) {
        self.place = place
        self.startingFacility = startingFacility
        self.initialScreenIndex = initialScreenIndex
        self.onSubmitted = onSubmitted
        self.onFinished = onFinished

        let draft = ReviewDraft(appleMapsId: place.id.uuidString, coordinate: place.coordinate, name: place.name)
        var startIndex = initialScreenIndex
        // Category picker is skipped in this flow, so every facility is
        // always walked (unless entering from one facility's own "Add
        // Review" button via startingFacility).
        var facilities = startingFacility.map { Set([$0]) } ?? Set(FacilityKind.allCases)
        var entranceLocs = Set<EntranceLocation>()
        var lobbyTags = Set<ContributeTagOption>()
        var basementTags = Set<ContributeTagOption>()
        var elevTags = Set<ContributeTagOption>()
        var toiletTagsInit = Set<ContributeTagOption>()

        if let snap = UnfinishedReviewStore.snapshot(for: place) {
            startIndex = snap.screenIndex
            facilities = Set(snap.selectedFacilities.compactMap(FacilityKind.init(rawValue:)))
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

        _draft = StateObject(wrappedValue: draft)
        _selectedFacilities = State(initialValue: facilities)
        _screenIndex = State(initialValue: startIndex)
        _entranceLocations = State(initialValue: entranceLocs)
        _lobbyEntranceTags = State(initialValue: lobbyTags)
        _basementEntranceTags = State(initialValue: basementTags)
        _elevatorTags = State(initialValue: elevTags)
        _toiletTags = State(initialValue: toiletTagsInit)
    }

    private var orderedFacilities: [FacilityKind] {
        [.entrance, .elevator, .toilet].filter { selectedFacilities.contains($0) }
    }

    private enum FlowScreen: Equatable {
        case category
        case entranceLocation
        case entranceQuestion(EntranceLocation)
        case entranceRampFollowup(EntranceLocation)
        case entranceHandrailFollowup(EntranceLocation)
        case entrancePhotos(EntranceLocation)
        case elevatorQuestion(ElevatorQuestion)
        case toiletInitial
        case toiletQuestion(ToiletQuestion)
        case toiletLocation
        case facilityQuestion(FacilityKind)
        case facilityPhotos(FacilityKind)
        case finalReview
    }

    private var screens: [FlowScreen] {
        var list: [FlowScreen] = []
        for kind in orderedFacilities {
            switch kind {
            case .entrance:
                list.append(.entranceLocation)
                // Lobby before Basement when both are picked — matches
                // EntranceLocation.allCases order.
                for location in EntranceLocation.allCases where entranceLocations.contains(location) {
                    list.append(.entranceQuestion(location))
                    let tags = entranceTags(for: location)
                    if tags.contains(where: { $0.label == "RAMP" }) {
                        list.append(.entranceRampFollowup(location))
                    }
                    if tags.contains(where: { $0.label == "HANDRAIL" }) {
                        list.append(.entranceHandrailFollowup(location))
                    }
                }
            case .elevator:
                // No chip screen here — the three questions ARE the answers
                // (see ElevatorQuestion.tagLabel).
                list.append(contentsOf: ElevatorQuestion.allCases.map(FlowScreen.elevatorQuestion))
            case .toilet:
                list.append(.toiletInitial)
                if toiletInitialAnswer == "Yes" {
                    list.append(contentsOf: [
                        .toiletQuestion(.doorKind),
                        .toiletQuestion(.seat),
                        .toiletQuestion(.grabBars),
                        .toiletQuestion(.space),
                        .toiletQuestion(.sink),
                        .toiletQuestion(.emergency),
                        .toiletLocation
                    ])
                }
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
            || !entranceLocations.isEmpty
            || !lobbyEntranceTags.isEmpty || !basementEntranceTags.isEmpty || !toiletTags.isEmpty
            || !elevatorAnswers.isEmpty || toiletInitialAnswer != nil
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
                Color(.systemBackground)
                    .overlay { ProgressView() }
                    .task { await submit() }
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
            Button("OK") { submitError = nil; goBackOneStep() }
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
        .onChange(of: screenIndex) { _, _ in persistIfNeeded() }
    }

    @ViewBuilder
    private func screenView(_ screen: FlowScreen) -> some View {
        switch screen {
        case .category:
            ContributeCategoryStepView(
                placeName: place.name,
                selection: $selectedFacilities,
                onBack: requestExit,
                onContinue: goNext
            )
        case .entranceLocation:
            ContributeEntranceLocationStepView(
                facilityName: place.name,
                progress: progress(for: screen),
                selection: $entranceLocations,
                onBack: goBackOneStep,
                onContinue: goNext
            )
        case .entranceQuestion(let location):
            ContributeFacilityQuestionStepView(
                kind: .entrance,
                navTitle: "Entrances",
                questionTitle: questionTitle(forEntrance: location),
                progress: progress(for: screen),
                selection: entranceTagsBinding(for: location),
                illustrationAssetName: illustrationAssetName(for: location),
                optionsOverride: ContributeReviewTags.tags(forEntrance: location),
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
                questionTitle: "Could you push your wheelchair up the ramp without help?",
                progress: progress(for: screen),
                options: ["Yes", "With a push", "Too steep", "Not sure"],
                photoRevealOption: "Not sure",
                selection: rampAnswerBinding(for: location),
                note: entranceNoteBinding(for: location),
                stepNumber: 1,
                subStepProgress: subProgress(for: screen),
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
                questionTitle: "Could you reach and grip the handrail from your wheelchair?",
                progress: progress(for: screen),
                options: ["Yes", "With effort", "No", "Not sure"],
                photoRevealOption: "Not sure",
                selection: handrailAnswerBinding(for: location),
                note: entranceNoteBinding(for: location),
                stepNumber: 1,
                subStepProgress: subProgress(for: screen),
                onBack: goBackOneStep,
                onContinue: goNext
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
        case .elevatorQuestion(let question):
            ContributeAccessFollowupStepView(
                navTitle: "Elevators",
                illustrationAssetName: "Elevator Question Asset",
                eyebrow: question.eyebrow,
                questionTitle: question.title,
                progress: progress(for: screen),
                options: ["Yes", "No", "Not sure"],
                photoRevealOption: "Not sure",
                selection: elevatorAnswerBinding(for: question),
                note: Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 }),
                stepNumber: 2,
                subStepProgress: subProgress(for: screen),
                onBack: goBackOneStep,
                onContinue: {
                    applyElevatorMapping()
                    goNext()
                }
            )
        case .toiletInitial:
            ContributeAccessFollowupStepView(
                navTitle: "Accessible Toilets",
                illustrationAssetName: "Toilet Survey Asset",
                eyebrow: "",
                questionTitle: "Does the mall have accessible toilets?",
                progress: progress(for: screen),
                options: ["Yes", "No", "Not sure"],
                photoRevealOption: "",
                selection: $toiletInitialAnswer,
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
                stepNumber: 3,
                subStepProgress: subProgress(for: screen),
                onBack: goBackOneStep,
                onContinue: {
                    applyToiletInitialMapping()
                    goNext()
                }
            )
        case .toiletQuestion(let question):
            ContributeAccessFollowupStepView(
                navTitle: "Accessible Toilets",
                illustrationAssetName: "Toilet Survey Asset",
                eyebrow: question.eyebrow,
                questionTitle: question.title,
                progress: progress(for: screen),
                options: question.options,
                photoRevealOption: question.photoRevealOption ?? "",
                selection: toiletAnswerBinding(for: question),
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
                stepNumber: 3,
                subStepProgress: subProgress(for: screen),
                onBack: goBackOneStep,
                onContinue: {
                    applyToiletQuestionMapping(question)
                    goNext()
                }
            )
        case .toiletLocation:
            ContributeToiletLocationStepView(
                locationText: $toiletLocationNote,
                onBack: goBackOneStep,
                onContinue: {
                    applyToiletLocationMapping()
                    goNext()
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
                note: Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 }),
                isLastStep: true,
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
    }

    private func goBackOneStep() {
        if screenIndex == 0 {
            requestExit()
        } else {
            screenIndex -= 1
            persistIfNeeded()
        }
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
        case .category, .entranceLocation, .entranceQuestion, .entranceRampFollowup, .entranceHandrailFollowup, .entrancePhotos: 1
        case .elevatorQuestion: 2
        case .toiletInitial, .toiletQuestion, .toiletLocation: 3
        case .facilityQuestion, .facilityPhotos, .finalReview: 4
        }

        let stepScreens = screens.filter { s in
            switch s {
            case .category, .entranceLocation, .entranceQuestion, .entranceRampFollowup, .entranceHandrailFollowup, .entrancePhotos: stepNumber == 1
            case .elevatorQuestion: stepNumber == 2
            case .toiletInitial, .toiletQuestion, .toiletLocation: stepNumber == 3
            case .facilityQuestion, .facilityPhotos, .finalReview: stepNumber == 4
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
    private func applyElevatorMapping() {
        let catalog = ContributeReviewTags.tags(for: .elevator)
        elevatorTags = Set(
            ElevatorQuestion.allCases
                .filter { elevatorAnswers[$0] == "Yes" }
                .compactMap { question in catalog.first { $0.label == question.tagLabel } }
        )

        draft.elevator.exists = true

        let answered = ElevatorQuestion.allCases.compactMap { elevatorAnswers[$0] }
        draft.elevator.wheelchairAccessible =
            if answered.contains("No") { false }
            else if answered.count == ElevatorQuestion.allCases.count { true }
            else { nil }

        if draft.elevator.wheelchairAccessible == true {
            draft.elevator.blockers = []
        } else if elevatorAnswers[.wideEntrance] == "No" || elevatorAnswers[.spaceToManeuver] == "No" {
            draft.elevator.blockers = [.tooSmall]
        }
    }

    private func applyToiletMapping() {
        draft.toilet.hasDisabledToilet = true
    }

    private func toiletAnswerBinding(for question: ToiletQuestion) -> Binding<String?> {
        Binding(
            get: { toiletAnswers[question] },
            set: { toiletAnswers[question] = $0 }
        )
    }

    private func applyToiletInitialMapping() {
        if toiletInitialAnswer == "Yes" {
            draft.toilet.hasDisabledToilet = true
        } else if toiletInitialAnswer == "No" {
            draft.toilet.hasDisabledToilet = false
        } else {
            draft.toilet.hasDisabledToilet = nil
        }
    }

    private func applyToiletQuestionMapping(_ question: ToiletQuestion) {
        let answer = toiletAnswers[question]

        switch question {
        case .doorKind:
            if answer == "Automatic" {
                toiletTags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "AUTOMATIC DOORS"))
            } else if answer == "Sliding" {
                toiletTags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "SLIDING DOORS"))
            } else if answer == "Manual" {
                toiletTags.insert(ContributeTagOption(symbol: "door.left.hand.open", label: "MANUAL DOORS"))
            }
        case .grabBars:
            if answer == "Yes" || answer == "Positioned awkwardly" {
                toiletTags.insert(ContributeTagOption(symbol: "figure.roll", label: "GRAB BARS"))
            }
        case .space:
            if answer == "Yes" {
                toiletTags.insert(ContributeTagOption(symbol: "arrow.up.and.down.and.arrow.left.and.right", label: "SPACE TO MANEUVER"))
            }
        case .sink:
            if answer == "Yes" {
                toiletTags.insert(ContributeTagOption(symbol: "sink.fill", label: "REACHABLE SINK"))
            }
        case .emergency:
            if answer == "Yes" || answer == "No" || answer == "Not sure" {
                toiletTags.insert(ContributeTagOption(symbol: "bell.fill", label: "EMERGENCY BUTTON"))
            }
        default: break
        }
    }

    private func applyToiletLocationMapping() {
        // Free-text toilet location note is kept in toiletLocationNote, not auto-populated into main review text
    }

    private func submit() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            try? await Task.sleep(nanoseconds: 500_000_000)
            UnfinishedReviewStore.clear(for: place)
            isSubmitted = true
            return
        }
        #endif

        do {
            try await ReviewService.shared.submit(draft)
            UnfinishedReviewStore.clear(for: place)
            isSubmitted = true
            onSubmitted?()
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
