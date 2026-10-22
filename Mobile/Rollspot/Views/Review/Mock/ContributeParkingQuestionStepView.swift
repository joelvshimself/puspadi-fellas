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
                ContributeStepProgressBar(currentStep: 4, subStepProgress: subStepProgress)
                PhotoFlowHeader(title: "Accessible Parking".localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    RampLoopVideoCard(
                        resourceName: "PARKING_ACCESSIBLE_PARKING",
                        infoTitle: "Accessible Parking",
                        infoSections: Self.infoSections,
                        infoVideoName: "PARKING_ACCESSIBLE_PARKING"
                    )
                    .padding(.top, 14)

                    ContributeQuestionHeading(title: "Is there accessible parking?")
                        .padding(.top, 34)

                    Button {
                        showInfo = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle.fill")
                                .font(.system(size: 12, weight: .semibold))
                            Text("Learn more about accessible parking".localized)
                                .font(.system(size: 13, weight: .medium))
                                .underline()
                        }
                        .foregroundStyle(ContributePalette.blue)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    VStack(spacing: ContributeQuestionMetrics.optionSpacing) {
                        ForEach(Self.options, id: \.self) { option in
                            ContributeOptionRow(title: option, isSelected: selection == option) { selection = option }
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }

            ContributeContinueButton(isEnabled: selection != nil, action: onContinue)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showInfo) {
            ParkingInfoSheet()
        }
    }

    static let infoSections: [(title: String, body: String)] = [
        ("Space", "Wider than a standard spot, with designated access aisle for a wheelchair to unload."),
        ("Distance", "Ideally located on the shortest, most direct route to the entrance, not the far end of the lot."),
    ]

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
