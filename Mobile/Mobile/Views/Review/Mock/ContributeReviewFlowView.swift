import SwiftUI

/// New "Contribute a Review" flow — real Supabase submit with draft persistence.
struct ContributeReviewFlowView: View {
    let place: Place
    let startingFacility: FacilityKind?
    let initialScreenIndex: Int
    let onFinished: () -> Void

    @StateObject private var draft: ReviewDraft

    @State private var selectedFacilities: Set<FacilityKind>
    @State private var screenIndex: Int
    @State private var entranceLocation: EntranceLocation?
    @State private var entranceTags: Set<ContributeTagOption> = []
    @State private var elevatorTags: Set<ContributeTagOption> = []
    @State private var toiletTags: Set<ContributeTagOption> = []
    @State private var isSubmitted = false
    @State private var submitError: String?
    @State private var showExitConfirmation = false

    init(
        place: Place,
        startingFacility: FacilityKind? = nil,
        initialScreenIndex: Int = 0,
        onFinished: @escaping () -> Void
    ) {
        self.place = place
        self.startingFacility = startingFacility
        self.initialScreenIndex = initialScreenIndex
        self.onFinished = onFinished

        let draft = ReviewDraft(appleMapsId: place.id.uuidString, coordinate: place.coordinate)
        var startIndex = initialScreenIndex
        var facilities = startingFacility.map { Set([$0]) } ?? Set<FacilityKind>()
        var entranceLoc: EntranceLocation?
        var entTags = Set<ContributeTagOption>()
        var elevTags = Set<ContributeTagOption>()
        var toiletTagsInit = Set<ContributeTagOption>()

        if let snap = UnfinishedReviewStore.snapshot(for: place) {
            startIndex = snap.screenIndex
            facilities = Set(snap.selectedFacilities.compactMap(FacilityKind.init(rawValue:)))
            entranceLoc = snap.entranceLocation.flatMap(EntranceLocation.init(rawValue:))
            entTags = UnfinishedReviewStore.restoreTags(snap.entranceTags, for: .entrance)
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
        _entranceLocation = State(initialValue: entranceLoc)
        _entranceTags = State(initialValue: entTags)
        _elevatorTags = State(initialValue: elevTags)
        _toiletTags = State(initialValue: toiletTagsInit)
    }

    private var orderedFacilities: [FacilityKind] {
        [.entrance, .elevator, .toilet].filter { selectedFacilities.contains($0) }
    }

    private enum FlowScreen: Equatable {
        case category
        case entranceLocation
        case facilityQuestion(FacilityKind)
        case facilityPhotos(FacilityKind)
    }

    private var screens: [FlowScreen] {
        var list: [FlowScreen] = []
        if startingFacility == nil { list.append(.category) }
        for kind in orderedFacilities {
            if kind == .entrance { list.append(.entranceLocation) }
            list.append(.facilityQuestion(kind))
            list.append(.facilityPhotos(kind))
        }
        return list
    }

    private var progressScreens: [FlowScreen] {
        screens.filter { $0 != .category }
    }

    private func progress(for screen: FlowScreen) -> (current: Int, total: Int) {
        (progressScreens.firstIndex(of: screen) ?? 0, max(progressScreens.count, 1))
    }

    private var hasProgress: Bool {
        screenIndex > 0
            || !entranceTags.isEmpty || !elevatorTags.isEmpty || !toiletTags.isEmpty
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
        .alert(
            "Couldn't submit review",
            isPresented: Binding(get: { submitError != nil }, set: { if !$0 { submitError = nil } }),
            presenting: submitError
        ) { _ in
            Button("OK") { submitError = nil; goBackOneStep() }
        } message: { message in
            Text(message)
        }
        .confirmationDialog(
            "You haven't finished this review. Go back?",
            isPresented: $showExitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard", role: .destructive) {
                UnfinishedReviewStore.clear(for: place)
                onFinished()
            }
            Button("Resume", role: .cancel) {}
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
                selection: $entranceLocation,
                onBack: goBackOneStep,
                onContinue: goNext
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
            entranceLocation: entranceLocation,
            entranceTags: entranceTags,
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

    private func questionTitle(for kind: FacilityKind) -> String {
        switch kind {
        case .entrance: "What did the entrance have?"
        case .elevator: "What do the elevators have?"
        case .toilet: "What does the toilet have?"
        }
    }

    private func tagBinding(for kind: FacilityKind) -> Binding<Set<ContributeTagOption>> {
        switch kind {
        case .entrance: $entranceTags
        case .elevator: $elevatorTags
        case .toilet: $toiletTags
        }
    }

    private func noteBinding(for kind: FacilityKind) -> Binding<ReviewNoteDraft> {
        switch kind {
        case .entrance:
            Binding(
                get: { entranceLocation == .basement ? draft.basement.review : draft.lobby.review },
                set: { newValue in
                    if entranceLocation == .basement {
                        draft.basement.review = newValue
                    } else {
                        draft.lobby.review = newValue
                    }
                }
            )
        case .elevator:
            Binding(get: { draft.elevator.review }, set: { draft.elevator.review = $0 })
        case .toilet:
            Binding(get: { draft.toilet.review }, set: { draft.toilet.review = $0 })
        }
    }

    private func applyMapping(for kind: FacilityKind) {
        switch kind {
        case .entrance: applyEntranceMapping()
        case .elevator: applyElevatorMapping()
        case .toilet: applyToiletMapping()
        }
    }

    private func applyEntranceMapping() {
        let hasRamp = entranceTags.contains { $0.label == "RAMP" }
        let hasRail = entranceTags.contains { $0.label == "HANDRAIL" }
        let door: DoorType? =
            if entranceTags.contains(where: { $0.label == "AUTOMATIC DOORS" }) { .automatic }
            else if entranceTags.contains(where: { $0.label == "MANUAL DOORS" }) { .manual }
            else { nil }
        switch entranceLocation {
        case .basement:
            draft.basement.hasDropoffRamp = hasRamp ? true : nil
            draft.basement.hasRails = hasRail ? true : nil
            draft.basement.doorType = door
        default:
            draft.lobby.hasDropoffRamp = hasRamp ? true : nil
            draft.lobby.hasRails = hasRail ? true : nil
            draft.lobby.doorType = door
        }
    }

    private func applyElevatorMapping() {
        draft.elevator.exists = true
        draft.elevator.wheelchairAccessible = elevatorTags.isEmpty ? nil : true
    }

    private func applyToiletMapping() {
        draft.toilet.hasDisabledToilet = true
    }

    private func submit() async {
        do {
            try await ReviewService.shared.submit(draft)
            UnfinishedReviewStore.clear(for: place)
            isSubmitted = true
        } catch {
            submitError = "Check your connection and try again."
        }
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
}
