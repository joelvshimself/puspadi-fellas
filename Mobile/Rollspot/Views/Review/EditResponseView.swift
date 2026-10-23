import PhotosUI
import Shared
import SwiftUI

/// Edit Response (Figma "Edit Response Page"): every answer of a submitted review as a tappable row,
/// with section photos and notes. All rules (what a change implies, what can be saved) live in the
/// shared `ReviewEditModel`; this view only renders its state and sends taps back.
struct EditResponseView: View {
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: EditResponseStore
    @State private var showLeaveSheet = false

    init(reviewId: String, onSaved: @escaping () -> Void = {}) {
        self.onSaved = onSaved
        _store = StateObject(wrappedValue: EditResponseStore(reviewId: reviewId))
    }

    var body: some View {
        content
            .background(Color(uiColor: .systemBackground).ignoresSafeArea())
            .navigationTitle("Edit Response".localized)
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: leave) {
                        Image(systemName: "chevron.left")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Back".localized)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    saveButton
                }
            }
            // Swiping back would skip "Leave editing?", so it's off while there are changes.
            .interactiveDismissDisabled(store.ready?.isDirty == true)
            .sheet(isPresented: $showLeaveSheet) {
                leaveSheet
                    .presentationDetents([.height(200)])
                    .presentationCornerRadius(28)
                    .presentationDragIndicator(.visible)
            }
            .task {
                await store.load()
                #if DEBUG
                if DesignReview.is(.editResponseLeave) {
                    store.model.setNotes(notesKey: "entrance", text: "Ramp available but there's still a step to the main floor.")
                    showLeaveSheet = true
                }
                #endif
            }
            .onChange(of: store.didSave) { _, saved in
                guard saved else { return }
                onSaved()
                dismiss()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed(let message):
            VStack(spacing: 12) {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try again".localized) { Task { await store.load() } }
                    .font(.subheadline.weight(.semibold))
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .ready(let state):
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 28) {
                    if let message = state.error ?? state.problem {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(AuthPalette.errorRed)
                            .padding(.horizontal, 20)
                    }
                    ForEach(state.sections, id: \.id) { section in
                        EditResponseSectionView(section: section, store: store)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var saveButton: some View {
        let enabled = store.ready?.canSave == true
        return Button {
            Task { await store.save() }
        } label: {
            Group {
                if store.ready?.isSaving == true {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(enabled ? AuthPalette.brandBlue : Color.secondary.opacity(0.6))
                }
            }
        }
        .disabled(!enabled)
        .accessibilityLabel("Save changes".localized)
    }

    private func leave() {
        if store.ready?.isDirty == true {
            showLeaveSheet = true
        } else {
            dismiss()
        }
    }

    private var leaveSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Leave editing?".localized)
                    .font(.title3.weight(.bold))
                Text("Your progress won't be saved if you leave now.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Button {
                    showLeaveSheet = false
                } label: {
                    Text("Cancel".localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AuthPalette.brandBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Color(uiColor: .systemBackground)))
                        .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(PressableButtonStyle())
                Button {
                    showLeaveSheet = false
                    dismiss()
                } label: {
                    Text("Discard & Leave".localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Capsule().fill(Color.red.opacity(0.15)))
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// One block: title, "Tap any answer to change it", the answer rows, photos, notes.
private struct EditResponseSectionView: View {
    let section: EditSection
    @ObservedObject var store: EditResponseStore

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title.localized)
                    .font(.title3.weight(.bold))
                Text("Tap any answer to change it".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 20)

            rows
                .padding(.horizontal, 20)

            EditResponsePhotoStrip(section: section, store: store)

            if let notesKey = section.notesKey {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Notes".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField(
                        "None".localized,
                        text: Binding(get: { section.notes }, set: { store.model.setNotes(notesKey: notesKey, text: $0) }),
                        axis: .vertical
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1...6)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AuthPalette.fieldFill))
                }
                .padding(.horizontal, 20)
            }
        }
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                if let group = row.group, index == 0 || section.rows[index - 1].group != group {
                    Text(group.localized)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 14)
                        .padding(.top, index == 0 ? 10 : 14)
                        .padding(.bottom, 2)
                }
                EditResponseRowView(row: row, model: store.model)
                if index < section.rows.count - 1 {
                    Divider().padding(.leading, 14)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AuthPalette.fieldFill))
    }
}

private struct EditResponseRowView: View {
    let row: EditRow
    let model: ReviewEditModel

    var body: some View {
        HStack(spacing: 12) {
            Text(row.label.localized)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if row.isText {
                TextField(
                    row.placeholder.localized,
                    text: Binding(get: { row.text }, set: { model.setText(rowId: row.id, text: $0) })
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            } else {
                // The design's floating menu with a check on the current answer: a native Menu.
                Menu {
                    Picker(row.label.localized, selection: Binding(
                        get: { row.selected ?? "" },
                        set: { model.choose(rowId: row.id, optionId: $0) }
                    )) {
                        ForEach(row.options, id: \.id) { option in
                            Text(option.label.localized).tag(option.id)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(row.value.localized)
                            .font(.footnote)
                            .foregroundStyle(row.selected == nil ? AuthPalette.brandBlue : .secondary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                // Menus take the accent colour; the design keeps the value grey.
                .tint(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
    }
}

/// "Add Photos" tile, then the section's photos, each with a remove button.
private struct EditResponsePhotoStrip: View {
    let section: EditSection
    @ObservedObject var store: EditResponseStore
    @State private var picked: [PhotosPickerItem] = []

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if section.canAddPhoto {
                    PhotosPicker(selection: $picked, maxSelectionCount: 5, matching: .images) {
                        VStack(spacing: 6) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 20, weight: .semibold))
                            Text("Add Photos".localized)
                                .font(.caption2.weight(.medium))
                        }
                        .foregroundStyle(AuthPalette.brandBlue)
                        .frame(width: 100, height: 100)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AuthPalette.fieldFill))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                    .onChange(of: picked) { _, items in
                        guard !items.isEmpty else { return }
                        picked = []
                        Task { await store.addPhotos(items, to: section.id) }
                    }
                }
                ForEach(section.photos, id: \.id) { photo in
                    ZStack(alignment: .topTrailing) {
                        thumbnail(photo)
                            .frame(width: 100, height: 100)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                store.model.removePhoto(sectionId: section.id, photoId: photo.id)
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 20, height: 20)
                                .background(Circle().fill(.white.opacity(0.9)))
                        }
                        .padding(6)
                        .accessibilityLabel("Remove photo".localized)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func thumbnail(_ photo: EditPhoto) -> some View {
        if let jpeg = photo.jpeg, let image = UIImage(data: jpeg.asData()) {
            Image(uiImage: image).resizable().aspectRatio(contentMode: .fill)
        } else if let url = photo.url.flatMap(URL.init(string:)) {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    AuthPalette.fieldFill
                }
            }
        } else {
            AuthPalette.fieldFill
        }
    }
}

/// Bridges the shared `ReviewEditModel` state into SwiftUI.
@MainActor
final class EditResponseStore: ObservableObject {
    enum Phase {
        case loading
        case failed(String)
        case ready(ReviewEditStateReady)
    }

    let model: ReviewEditModel
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var didSave = false

    var ready: ReviewEditStateReady? {
        if case .ready(let state) = phase { return state }
        return nil
    }

    init(reviewId: String) {
        model = RollspotServices.sdk.reviewEditModel(reviewId: reviewId)
        Task { [weak self] in
            guard let states = self?.model.state else { return }
            for await state in states {
                self?.apply(state)
            }
        }
    }

    func load() async {
        try? await model.load()
    }

    func save() async {
        try? await model.save()
    }

    /// Same preparation as the contribute flow's photos.
    func addPhotos(_ items: [PhotosPickerItem], to sectionId: String) async {
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let encoded = PhotoEncoder.encode(image)
            else { continue }
            if !model.addPhoto(sectionId: sectionId, jpeg: encoded.jpeg.asKotlinByteArray(), caption: "") { break }
        }
    }

    private func apply(_ state: ReviewEditState) {
        switch onEnum(of: state) {
        case .loading:
            phase = .loading
        case .failed(let failed):
            phase = .failed(failed.message)
        case .ready(let ready):
            phase = .ready(ready)
        case .saved:
            didSave = true
        }
    }
}
