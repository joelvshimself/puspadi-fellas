import Shared
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

/// "Learn more about accessible parking": same grey sheet as the card's "i" (copy from shared `ParkingInfo`).
struct ParkingInfoSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PathwayVideoCard(resourceName: "PARKING_ACCESSIBLE_PARKING", isActive: true)
                    .frame(height: ContributeQuestionMetrics.cardHeight)
                    .padding(.bottom, 6)

                Text(ParkingInfo.shared.title.localized)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ContributePalette.text)

                ForEach(ParkingInfo.shared.sections, id: \.title) { section in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title.localized)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(designHex: 0x575757))
                        Text(section.body.localized)
                            .font(.system(size: 13))
                            .foregroundStyle(Color(designHex: 0x5D5D5D))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .presentationBackground(Color(designHex: 0xE8E8E8))
        .presentationCornerRadius(34)
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
    }
}
