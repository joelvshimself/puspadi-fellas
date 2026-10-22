import SwiftUI

/// "Is there accessible parking?" — single-select Yes / No / Not sure.
struct ContributeParkingQuestionStepView: View {
    let progress: (current: Int, total: Int)
    var subStepProgress: CGFloat = 0.35
    @Binding var selection: String?
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var showInfo = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PhotoFlowHeader(title: "Accessible Parking".localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: 4, subStepProgress: subStepProgress)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image("Basement Asset")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)

                    Text("Is there accessible parking?".localized)
                        .font(.title2.bold())
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        showInfo = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Learn more about accessible parking".localized)
                                .font(.subheadline.weight(.semibold))
                                .underline()
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 12) {
                        ForEach(Self.options, id: \.self) { option in
                            optionRow(option)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: selection != nil, action: onContinue)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showInfo) {
            ParkingInfoSheet()
        }
    }

    private func optionRow(_ option: String) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
        } label: {
            Text(option.localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    static let options = ["Yes", "No", "Not sure"]
}

struct ParkingInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                PathwayVideoCard(resourceName: "PARKING_ACCESSIBLE_PARKING", isActive: true)
                    .frame(height: 210)

                Text("Accessible Parking")
                    .font(.title.bold())

                section(
                    title: "Space",
                    body: "Wider than a standard spot, with designated access aisle for a wheelchair to unload."
                )
                section(
                    title: "Distance",
                    body: "Ideally located on the shortest, most direct route to the entrance, not the far end of the lot."
                )
            }
            .padding(20)
        }
        .background(Color(.systemGroupedBackground))
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }

    private func section(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
