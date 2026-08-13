import SwiftUI

/// Multi-step "Add Review" wizard, presented as a fullScreenCover from
/// PlaceDetailView (modal task flow, not a browsing destination — matches
/// the existing AnalysingView precedent rather than pushing onto the shared
/// NavigationPath).
struct ReviewWizardView: View {
    let place: Place
    let onFinished: () -> Void

    @StateObject private var draft: ReviewDraft
    @State private var step: ReviewStep = .lobbyRampsRails
    @State private var hasInteracted = false
    @State private var showDiscardConfirm = false
    @State private var isSubmitting = false
    @State private var submitError: String?

    init(place: Place, onFinished: @escaping () -> Void) {
        self.place = place
        self.onFinished = onFinished
        // TODO(backend): placeholder appleMapsId — see ReviewDraft.
        _draft = StateObject(wrappedValue: ReviewDraft(appleMapsId: place.id.uuidString, coordinate: place.coordinate))
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .submitted {
                header
            }

            ScrollView {
                content
                    .padding(20)
            }

            if step != .submitted {
                footer
            }
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .onChange(of: draftFingerprint) { _, _ in
            hasInteracted = true
        }
        .alert("Discard this review?", isPresented: $showDiscardConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Discard Review", role: .destructive) { onFinished() }
        } message: {
            Text("Your answers won't be saved.")
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
    }

    // MARK: Header / footer

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button {
                    requestClose()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            ReviewProgressBar(
                currentIndex: ReviewStep.answerableSteps.firstIndex(of: step) ?? 0,
                totalSteps: ReviewStep.answerableSteps.count
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .lobbyRampsRails {
                Button {
                    goBack()
                } label: {
                    Text("Back")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 14)
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
                .disabled(isSubmitting)
            }

            Button {
                goNext()
            } label: {
                Group {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == .toiletNote ? "Submit Review" : "Next")
                    }
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(isSubmitting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: Step content

    @ViewBuilder
    private var content: some View {
        switch step {
        case .lobbyRampsRails:
            ReviewLobbyBasementStepView(phase: .rampsRails, entrance: $draft.lobby)
        case .lobbyDoor:
            ReviewLobbyBasementStepView(phase: .door, entrance: $draft.lobby)
        case .lobbyNote:
            ReviewAddNoteStepView(title: "Lobby entrance", context: "tell us more about the lobby entrance", note: $draft.lobby.review)
        case .basementRampsRails:
            ReviewLobbyBasementStepView(phase: .rampsRails, entrance: $draft.basement)
        case .basementDoor:
            ReviewLobbyBasementStepView(phase: .door, entrance: $draft.basement)
        case .basementNote:
            ReviewAddNoteStepView(title: "Basement entrance", context: "tell us more about the basement entrance", note: $draft.basement.review)
        case .elevatorPresence:
            ReviewElevatorStepView(phase: .presence, elevator: $draft.elevator)
        case .elevatorWheelchair:
            ReviewElevatorStepView(phase: .wheelchairFit, elevator: $draft.elevator)
        case .elevatorNote:
            ReviewAddNoteStepView(title: "Elevator", context: "tell us more about the elevator", note: $draft.elevator.review)
        case .toiletPresence:
            ReviewToiletStepView(toilet: $draft.toilet)
        case .toiletNote:
            ReviewAddNoteStepView(title: "Toilet", context: "tell us more about the toilet", note: $draft.toilet.review)
        case .submitted:
            ReviewSubmittedView(placeName: place.name, onDone: onFinished)
        }
    }

    // MARK: Navigation

    private func goNext() {
        switch step {
        case .elevatorPresence:
            // Contract: wheelchairAccessible is only meaningful/asked when
            // exists == true — skip the follow-up question otherwise, but
            // still offer the elevator note step either way.
            step = draft.elevator.exists == true ? .elevatorWheelchair : .elevatorNote
        case .toiletNote:
            Task { await submit() }
        default:
            if let next = ReviewStep(rawValue: step.rawValue + 1) {
                step = next
            }
        }
    }

    private func goBack() {
        switch step {
        case .elevatorNote:
            step = draft.elevator.exists == true ? .elevatorWheelchair : .elevatorPresence
        default:
            if let previous = ReviewStep(rawValue: step.rawValue - 1) {
                step = previous
            }
        }
    }

    private func requestClose() {
        if hasInteracted {
            showDiscardConfirm = true
        } else {
            onFinished()
        }
    }

    private func submit() async {
        isSubmitting = true
        defer { isSubmitting = false }
        do {
            try await ReviewService.shared.submit(draft)
            step = .submitted
        } catch {
            submitError = "Check your connection and try again."
        }
    }

    /// Cheap change-detection surface for the discard-confirmation flag —
    /// combines the fields most likely to be touched first. Not exhaustive;
    /// good enough for a "did the user start filling this out" heuristic.
    private var draftFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(draft.lobby.hasDropoffRamp)
        hasher.combine(draft.lobby.hasRails)
        hasher.combine(draft.lobby.review.text)
        hasher.combine(draft.lobby.review.photos.count)
        hasher.combine(draft.basement.hasDropoffRamp)
        hasher.combine(draft.basement.review.text)
        hasher.combine(draft.basement.review.photos.count)
        hasher.combine(draft.elevator.exists)
        hasher.combine(draft.elevator.wheelchairAccessible)
        hasher.combine(draft.elevator.review.text)
        hasher.combine(draft.elevator.review.photos.count)
        hasher.combine(draft.toilet.hasDisabledToilet)
        hasher.combine(draft.toilet.review.text)
        hasher.combine(draft.toilet.review.photos.count)
        return hasher.finalize()
    }
}

#Preview {
    ReviewWizardView(place: Place.samples[0], onFinished: {})
}
