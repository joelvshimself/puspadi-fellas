import SwiftUI

enum HomeTab: Hashable {
    case explore
    case saved
    case contribute
}

enum HomeRoute: Hashable {
    case place(Place)
    case saved
    case contribute
}

/// Floating home card that expands into a top search UI on the same view.
struct SearchSheet: View {
    @Binding var isSearching: Bool
    @Binding var searchText: String
    @Binding var selectedTab: HomeTab
    var isSearchFocused: FocusState<Bool>.Binding
    let places: [Place]
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void
    let onSelectTab: (HomeTab) -> Void

    private let categories: [(symbol: String, label: String, query: String?)] = [
        ("fork.knife", "Food", "Restaurant"),
        ("building.2.fill", "Stay", "Hotel"),
        ("tree.fill", "Parks", "Park"),
        ("cup.and.saucer.fill", "Cafe", "Restaurant"),
        ("plus", "More", nil)
    ]

    private var results: [Place] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return places }
        let filtered = places.filter {
            $0.name.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
        return filtered.isEmpty ? places : filtered
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isSearching {
                Capsule()
                    .fill(Color.secondary.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, 10)
                    .padding(.bottom, 14)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            } else {
                Color.clear.frame(height: 8)
            }

            HStack(spacing: 10) {
                searchField

                if isSearching {
                    Button("Cancel") {
                        onCancelSearch()
                    }
                    .font(.body)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 16)

            if isSearching {
                resultsList
                    .padding(.top, 8)
                    .transition(.opacity)
            } else {
                categoryRow
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                sheetTabBar
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: isSearching ? .infinity : nil, alignment: .top)
        .background { sheetBackground }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: isSearching)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Find a place", text: $searchText)
                .focused(isSearchFocused)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)
                .onSubmit {
                    beginSearch()
                }

            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.primary.opacity(isSearching ? 0.08 : 0.06))
        )
        .contentShape(Capsule())
        .onTapGesture {
            beginSearch()
        }
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.label) { item in
                    Button {
                        if let query = item.query {
                            searchText = query
                        }
                        beginSearch()
                    } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 64, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var sheetTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 8)

            HStack(spacing: 0) {
                tabItem(.explore, title: "Explore", systemName: "map.fill")
                tabItem(.saved, title: "Saved", systemName: "bookmark.fill")
                tabItem(.contribute, title: "Contribute", systemName: "plus.circle.fill")
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private func tabItem(_ tab: HomeTab, title: String, systemName: String) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text("Recent")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
                    .padding(.horizontal, 16)

                ForEach(results) { place in
                    Button {
                        onSelectPlace(place)
                    } label: {
                        resultRow(place)
                    }
                    .buttonStyle(.plain)

                    Divider()
                        .padding(.leading, 72)
                }
            }
            .padding(.bottom, 24)
        }
    }

    private func resultRow(_ place: Place) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(place.accentColor.opacity(0.85))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: place.gallerySymbols.first ?? "mappin")
                        .foregroundStyle(.white)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(place.category) • \(place.distance)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var sheetBackground: some View {
        if isSearching {
            Rectangle()
                .fill(Color(.systemBackground))
                .ignoresSafeArea()
        } else {
            if #available(iOS 26.0, *) {
                Color.clear
                    .glassEffect(.regular, in: .rect(cornerRadius: 32))
            } else {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
            }
        }
    }

    private func beginSearch() {
        guard !isSearching else {
            isSearchFocused.wrappedValue = true
            return
        }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            isSearching = true
        }
        isSearchFocused.wrappedValue = true
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var isSearching = false
        @State private var searchText = ""
        @State private var selectedTab: HomeTab = .explore
        @FocusState private var focused: Bool

        var body: some View {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.35).ignoresSafeArea()
                SearchSheet(
                    isSearching: $isSearching,
                    searchText: $searchText,
                    selectedTab: $selectedTab,
                    isSearchFocused: $focused,
                    places: Place.samples,
                    onSelectPlace: { _ in },
                    onCancelSearch: {
                        focused = false
                        searchText = ""
                        isSearching = false
                    },
                    onSelectTab: { selectedTab = $0 }
                )
                .padding(.horizontal, isSearching ? 0 : 12)
                .padding(.bottom, isSearching ? 0 : 10)
                .frame(maxHeight: isSearching ? .infinity : nil, alignment: .top)
            }
        }
    }

    return PreviewHost()
}
