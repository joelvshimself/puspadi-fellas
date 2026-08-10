import MapKit
import SwiftUI

struct HomeMapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    @State private var isSearching = false
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab: HomeTab = .explore
    @State private var showAnalysing = false
    @State private var path = NavigationPath()

    private let places = Place.samples

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottom) {
                mapLayer
                    .ignoresSafeArea()
                    .opacity(isSearching ? 0 : 1)
                    .allowsHitTesting(!isSearching)

                VStack(spacing: 0) {
                    if !isSearching {
                        topBar
                            .padding(.horizontal, 16)
                            .padding(.top, 8)
                            .transition(.opacity)

                        Spacer(minLength: 0)

                        HStack {
                            Spacer()
                            locationButton
                                .padding(.trailing, 16)
                                .padding(.bottom, 10)
                        }
                        .transition(.opacity)
                    }

                    SearchSheet(
                        isSearching: $isSearching,
                        searchText: $searchText,
                        selectedTab: $selectedTab,
                        isSearchFocused: $isSearchFocused,
                        places: places,
                        onSelectPlace: openPlace,
                        onCancelSearch: dismissSearch,
                        onSelectTab: handleTabSelection
                    )
                    .padding(.horizontal, isSearching ? 0 : 12)
                    .padding(.bottom, isSearching ? 0 : 10)
                    .frame(maxHeight: isSearching ? .infinity : nil, alignment: .top)
                }
            }
            .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isSearching)
            .toolbar(path.isEmpty ? .hidden : .automatic, for: .navigationBar)
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .place(let place):
                    PlaceDetailView(place: place)
                case .saved:
                    SavedView()
                case .contribute:
                    ContributeView()
                }
            }
            .fullScreenCover(isPresented: $showAnalysing) {
                AnalysingView(onDismiss: { showAnalysing = false })
            }
            .onChange(of: path.count) { _, count in
                if count == 0 {
                    selectedTab = .explore
                }
            }
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition) {
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 18, height: 18)
                        )
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    private var topBar: some View {
        HStack {
            circularButton(systemName: "line.3.horizontal.decrease") {}

            Spacer()

            circularButton(systemName: "person.fill") {}
                .onLongPressGesture(minimumDuration: 0.5) {
                    showAnalysing = true
                }
                .accessibilityHint("Long press to open Analysing demo")
        }
    }

    private var locationButton: some View {
        Button {
            withAnimation {
                cameraPosition = .region(
                    MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                        span: MKCoordinateSpan(latitudeDelta: 0.04, longitudeDelta: 0.04)
                    )
                )
            }
        } label: {
            Image(systemName: "location")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("My location")
    }

    private func circularButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func dismissSearch() {
        isSearchFocused = false
        searchText = ""
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isSearching = false
        }
    }

    private func openPlace(_ place: Place) {
        isSearchFocused = false
        path.append(HomeRoute.place(place))
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isSearching = false
        }
    }

    private func handleTabSelection(_ tab: HomeTab) {
        selectedTab = tab
        switch tab {
        case .explore:
            break
        case .saved:
            path.append(HomeRoute.saved)
        case .contribute:
            path.append(HomeRoute.contribute)
        }
    }
}

#Preview {
    HomeMapView()
}
