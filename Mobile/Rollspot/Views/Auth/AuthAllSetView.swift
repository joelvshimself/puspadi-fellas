import MapKit
import SwiftUI

struct AuthAllSetView: View {
    var onExplore: () -> Void

    private let previewRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: -8.7200, longitude: 115.2000),
        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
    )

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(initialPosition: .region(previewRegion))
                .mapStyle(.standard)
                .ignoresSafeArea()
                .disabled(true)

            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.35))
                    .frame(width: 40, height: 5)
                    .padding(.top, 10)

                Image("All Set Mall")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 285.49, height: 135)
                    .padding(.top, 8)

                Text("You're all set!".localized)
                    .font(.title.weight(.bold))

                Text("Find accessible malls, save your favorites, or contribute a review to help others.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)

                // The design's button is narrower than the card, centred.
                AuthContinueButton(title: "Explore Malls".localized) {
                    onExplore()
                }
                .frame(maxWidth: 200)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            // A floating card inset from the edges with every corner rounded (design "Welcome Screen").
            .background(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Color.white)
                    .shadow(color: .black.opacity(0.12), radius: 16, y: 4)
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden(true)
    }
}
