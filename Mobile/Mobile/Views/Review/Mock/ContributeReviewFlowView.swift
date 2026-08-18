import SwiftUI

/// New "Contribute a Review" flow matching the Figma mockup (facility
/// picker → per-facility tag questions → photos/notes → submitted), built
/// as fresh screens (Views/Review/Mock) rather than touching the existing
/// `ReviewWizardView` flow. Despite being new UI, submission is real: this
/// owns a genuine `ReviewDraft` and calls the real `ReviewService.submit()`
/// — same backend pipeline `ReviewWizardView` uses, just populated via a
/// best-effort mapping from this flow's tag-chip answers (see
/// `applyEntranceMapping`/etc.) since the mockup's tags don't line up 1:1
/// with the backend's existing structured fields. Confirmed with the user:
/// keep the mockup's exact tags, map what maps, drop what doesn't (e.g.
/// "Security Assistance" has no backend field).
struct ContributeReviewFlowView: View {
    let place: Place
    /// When set (reached from one specific facility's "Add Review"
    /// button), the category picker is skipped entirely and only that
    /// facility is walked.
    let startingFacility: FacilityKind?
    let onFinished: () -> Void

    @StateObject private var draft: ReviewDraft

    @State private var selectedFacilities: Set<FacilityKind>
    @State private var screenIndex = 0
    @State private var entranceLocation: EntranceLocation?
    @State private var entranceTags: Set<ContributeTagOption> = []
    @State private var elevatorTags: Set<ContributeTagOption> = []
    @State private var toiletTags: Set<ContributeTagOption> = []
    @State private var isSubmitting = false
    @State private var isSubmitted = false
    @State private var submitError: String?

    init(place: Place, startingFacility: FacilityKind? = nil, onFinished: @escaping () -> Void) {
        self.place = place
        self.startingFacility = startingFacility
        self.onFinished = onFinished
        _draft = StateObject(wrappedValue: ReviewDraft(appleMapsId: place.id.uuidString, coordinate: place.coordinate))
        _selectedFacilities = State(initialValue: startingFacility.map { [$0] } ?? [])
    }

    /// Fixed Entrance → Elevator → Toilet order, filtered to what's
    /// actually selected (or the single `startingFacility`).
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

    /// Progress bar only covers facility screens — the mockup's category
    /// picker has no progress bar at all.
    private var progressScreens: [FlowScreen] {
        screens.filter { $0 != .category }
    }

    private func progress(for screen: FlowScreen) -> (current: Int, total: Int) {
        (progressScreens.firstIndex(of: screen) ?? 0, max(progressScreens.count, 1))
    }

    var body: some View {
        Group {
            if isSubmitted {
                ContributeSubmittedView(onDone: onFinished)
            } else if let screen = screens[safe: screenIndex] {
                screenView(screen)
            } else {
                // Walked past the last screen — submitting.
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
            Button("OK") { submitError = nil; goBack() }
        } message: { message in
            Text(message)
        }
    }

    @ViewBuilder
    private func screenView(_ screen: FlowScreen) -> some View {
        switch screen {
        case .category:
            ContributeCategoryStepView(
                placeName: place.name,
                selection: $selectedFacilities,
                onBack: goBack,
                onContinue: goNext
            )
        case .entranceLocation:
            ContributeEntranceLocationStepView(
                facilityName: place.name,
                progress: progress(for: screen),
                selection: $entranceLocation,
                onBack: goBack,
                onContinue: goNext
            )
        case .facilityQuestion(let kind):
            ContributeFacilityQuestionStepView(
                kind: kind,
                navTitle: navTitle(for: kind),
                questionTitle: questionTitle(for: kind),
                progress: progress(for: screen),
                selection: tagBinding(for: kind),
                onBack: goBack,
                onContinue: {
                    applyMapping(for: kind)
                    goNext()
                }
            )
        case .facilityPhotos(let kind):
            let isLast = (screen == screens.last)
            ContributePhotosNotesStepView(
                facilityName: kind.title,
                navTitle: navTitle(for: kind),
                progress: progress(for: screen),
                note: noteBinding(for: kind),
                isLastStep: isLast,
                onBack: goBack,
                onContinue: goNext
            )
        }
    }

    // MARK: Navigation

    private func goNext() {
        screenIndex += 1
    }

    private func goBack() {
        if screenIndex == 0 {
            onFinished()
        } else {
            screenIndex -= 1
        }
    }

    // MARK: Per-facility copy

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

    // MARK: Bindings into the real ReviewDraft

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

    // MARK: Best-effort field mapping (mockup tags → real ReviewDraft fields)

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
        // SECURITY ASSISTANCE has no matching field on EntranceDraft — dropped.
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
        // Reaching this screen means the user is describing a real
        // elevator — WIDE ENTRANCE/REACHABLE BUTTONS are both positive
        // accessibility signals with no dedicated backend field, so their
        // presence best-effort implies wheelchairAccessible.
        draft.elevator.exists = true
        draft.elevator.wheelchairAccessible = elevatorTags.isEmpty ? nil : true
    }

    private func applyToiletMapping() {
        // GRAB BARS/EMERGENCY BUTTONS/AUTOMATIC DOORS have no matching
        // ToiletDraft field — only presence is sent.
        draft.toilet.hasDisabledToilet = true
    }

    // MARK: Submit

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ReviewService.shared.submit(draft)
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
