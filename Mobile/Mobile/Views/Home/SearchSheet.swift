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

/// Floating Liquid Glass home card (collapsed). Search mode uses `SearchPanel`.
struct SearchSheet: View {
    @Binding var searchText: String
    @Binding var selectedTab: HomeTab
    let onBeginSearch: () -> Void
    let onSelectTab: (HomeTab) -> Void

    private let categories: [(symbol: String, label: String, query: String?)] = [
        ("fork.knife", "Food", "Restaurant"),
        ("building.2.fill", "Stay", "Hotel"),
        ("tree.fill", "Parks", "Park"),
        ("cup.and.saucer.fill", "Cafe", "Restaurant"),
        ("plus", "More", nil)
    ]

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color.secondary.opacity(0.35))
                .frame(width: 36, height: 5)
                .padding(.top, 10)
                .padding(.bottom, 14)

            searchField
                .padding(.horizontal, 16)

            categoryRow
                .padding(.top, 14)
                .padding(.bottom, 4)

            sheetTabBar
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .frame(maxWidth: .infinity)
        .modifier(LiquidGlassCardModifier(cornerRadius: 32))
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Find a place")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
        .contentShape(Capsule())
        .onTapGesture(perform: onBeginSearch)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("Find a place")
    }

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.label) { item in
                    Button {
                        if let query = item.query {
                            searchText = query
                        }
                        onBeginSearch()
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
}

/// Full-screen search: top bar + results only (no glass card).
struct SearchPanel: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let places: [Place]
    let onSelectPlace: (Place) -> Void
    let onCancel: () -> Void

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
            HStack(spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField("Find a place", text: $searchText)
                        .focused(isSearchFocused)
                        .textInputAutocapitalization(.never)
                        .submitLabel(.search)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    Capsule()
                        .fill(Color(.secondarySystemBackground))
                )

                Button("Cancel", action: onCancel)
                    .font(.body)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            Divider()

            List {
                Section {
                    ForEach(results) { place in
                        Button {
                            onSelectPlace(place)
                        } label: {
                            resultRow(place)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                } header: {
                    Text("Recent")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .textCase(nil)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground).ignoresSafeArea())
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
        .contentShape(Rectangle())
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .shadow(color: .black.opacity(0.18), radius: 20, y: 6)
                }
        }
    }
}

#Preview("Home card") {
    struct PreviewHost: View {
        @State private var searchText = ""
        @State private var selectedTab: HomeTab = .explore

        var body: some View {
            ZStack(alignment: .bottom) {
                Color.gray.opacity(0.35).ignoresSafeArea()
                SearchSheet(
                    searchText: $searchText,
                    selectedTab: $selectedTab,
                    onBeginSearch: {},
                    onSelectTab: { selectedTab = $0 }
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
            }
        }
    }

    return PreviewHost()
}

#Preview("Search panel") {
    struct PreviewHost: View {
        @State private var searchText = ""
        @FocusState private var focused: Bool

        var body: some View {
            SearchPanel(
                searchText: $searchText,
                isSearchFocused: $focused,
                places: Place.samples,
                onSelectPlace: { _ in },
                onCancel: {}
            )
        }
    }

    return PreviewHost()
}
