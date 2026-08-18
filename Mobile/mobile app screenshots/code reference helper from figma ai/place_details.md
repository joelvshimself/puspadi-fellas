> default
import SwiftUI

// MARK: - Models

struct Facility: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let tags: [String]
    let extraCount: Int?
    let description: String?
}

struct Reviewer: Identifiable {
    let id = UUID()
    let imageName: String
}

// MARK: - Place Details View

struct PlaceDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let placeName = "Park23 Mall"
    let isAccessible = true

    let facilities: [Facility] = [
        Facility(
            name: "Entrance",
            icon: "door.left.hand.open",
            tags: ["Ramp", "Handrail", "Automatic Doors"],
            extraCount: 5,
            description: nil
        ),
        Facility(
            name: "Elevator",
            icon: "arrow.up.arrow.down",
            tags: ["Wide entrance", "Reachable buttons"],
            extraCount: nil,
            description: nil
        ),
        Facility(
            name: "Toilet",
            icon: "toilet",
            tags: [],
            extraCount: nil,
            description: "This place doesn't have an accessible toilet yet"
        ),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroImageSection
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.white)
    }

    // MARK: - Hero Image

    private var heroImageSection: some View {
        ZStack(alignment: .top) {
            // Background image
            Image("park23_hero")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 253)
                .clipped()
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.3)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 86)
                }

            // Navigation controls
            navigationOverlay
                .padding(.top, 62) // Below status bar

            // Bottom indicators
            VStack {
                Spacer()
                HStack {
                    imageIndicators
                    Spacer()
                    galleryChip
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
            }
            .frame(height: 253)
        }
    }

    private var navigationOverlay: some View {
        HStack {
            // Back button
            CircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            // Right button group
            HStack(spacing: 20) {
                CircleButton(icon: "bookmark") {}
                CircleButton(icon: "square.and.arrow.up") {}
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
    }

    private var imageIndicators: some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(.white)
                .frame(width: 27, height: 4)
            ForEach(0..<3, id: \.self) { _ in
                Circle()
                    .fill(.white)
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var galleryChip: some View {
        HStack(spacing: 6) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 12))
            Text("Gallery")
                .font(.system(size: 12))
        }
        .foregroundStyle(Color(red: 59/255, green: 59/255, blue: 59/255))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 242/255, green: 244/255, blue: 247/255), in: Capsule())
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: 0) {
            // Header card
            headerCard
                .padding(.horizontal, 22)
                .padding(.top, 22)

            // Divider
            Rectangle()
                .fill(Color(red: 224/255, green: 224/255, blue: 224/255))
                .frame(height: 1)
                .padding(.top, 16)

            // Facilities header
            facilitiesHeader
                .padding(.horizontal, 22)
                .padding(.top, 16)

            // Facility cards
            VStack(spacing: 16) {
                ForEach(facilities) { facility in
                    FacilityCard(facility: facility)
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Header Card

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Accessible badge
            if isAccessible {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 12))
                    Text("Accessible")
                        .font(.system(size: 12))
                }
                .foregroundStyle(Color(red: 10/255, green: 110/255, blue: 23/255))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Color(red: 223/255, green: 245/255, blue: 226/255),
                    in: Capsule()
                )
            }

            // Title row
            HStack {
                Text(placeName)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color(red: 26/255, green: 26/255, blue: 26/255))

                Spacer()

                HStack(spacing: 8) {
                    ActionCircle(
                        icon: "location.north.fill",
                        color: Color(red: 213/255, green: 234/255, blue: 255/255)
                    )
                    ActionCircle(
                        icon: "phone.fill",
                        color: Color(red: 213/255, green: 234/255, blue: 255/255)
                    )
                }
            }

            // Add Review button
            Button(action: {}) {
                Text("Add New Review")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(Color(red: 0, green: 153/255, blue: 1), in: Capsule())
            }
        }
    }

    // MARK: - Facilities Header

    private var facilitiesHeader: some View {
        HStack {
            Label {
                Text("Facilities")
                    .font(.system(size: 20, weight: .medium))
            } icon: {
                Image(systemName: "info.circle")
                    .font(.system(size: 16))
            }
            .foregroundStyle(Color(red: 59/255, green: 59/255, blue: 59/255))

            Spacer()

            // Reviewer avatars
            HStack(spacing: -8) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(.white, lineWidth: 1)
                        )
                }
                Text("+10")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(red: 114/255, green: 114/255, blue: 114/255))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Color(red: 242/255, green: 244/255, blue: 247/255),
                        in: Capsule()
                    )
            }

            // Source badge
            Text("Google Maps +2")
                .font(.system(size: 10))
                .foregroundStyle(Color(red: 114/255, green: 114/255, blue: 114/255))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(
                    Color(red: 242/255, green: 244/255, blue: 247/255),
                    in: Capsule()
                )
        }
    }
}

// MARK: - Facility Card

struct FacilityCard: View {
    let facility: Facility

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Illustration placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 230/255, green: 240/255, blue: 250/255))
                .frame(width: 80, height: 72)
                .overlay {
                    Image(systemName: facility.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(.gray)
                }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(facility.name)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Color(red: 59/255, green: 59/255, blue: 59/255))

                if let description = facility.description {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(Color(red: 26/255, green: 26/255, blue: 26/255))
                        .lineLimit(2)
                }

                if !facility.tags.isEmpty {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(facility.tags, id: \.self) { tag in
                            TagChip(text: tag)
                        }
                        if let extra = facility.extraCount {
                            TagChip(text: "+\(extra)")
                        }
                    }
                }
            }

            Spacer()

            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color(red: 95/255, green: 95/255, blue: 95/255))
                .padding(.top: 40)
        }
        .padding(14)
        .background(
            Color(red: 242/255, green: 244/255, blue: 247/255),
            in: RoundedRectangle(cornerRadius: 16)
        )
    }
}

// MARK: - Supporting Views

struct CircleButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color(red: 26/255, green: 26/255, blue: 26/255))
                .frame(width: 36, height: 36)
        }
    }
}

struct ActionCircle: View {
    let icon: String
    let color: Color

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 14))
            .foregroundStyle(Color(red: 0, green: 153/255, blue: 1))
            .frame(width: 40, height: 40)
            .background(color, in: Circle())
    }
}

struct TagChip: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "accessibility")
                .font(.system(size: 10))
            Text(text)
                .font(.system(size: 10))
        }
        .foregroundStyle(Color(red: 59/255, green: 59/255, blue: 59/255))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(.white, in: Capsule())
    }
}

// MARK: - Flow Layout (for wrapping tags)

struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let result = arrange(
            proposal: proposal,
            subviews: subviews
        )
        return result.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = arrange(
            proposal: proposal,
            subviews: subviews
        )
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(
                    x: bounds.minX + position.x,
                    y: bounds.minY + position.y
                ),
                proposal: .unspecified
            )
        }
    }

    private func arrange(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + lineSpacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlaceDetailsView()
            .navigationBarHidden(true)
    }
}

There's a small typo — let me fix one line. The .padding(.top: 40) on the chevron should be .padding(.top, 40):

.padding(.top, 40)


> no review yet
import SwiftUI

// MARK: - Models

struct Facility: Identifiable {
    let id = UUID()
    let name: String
    let icon: Image
    let tags: [String]
    let extraCount: Int
    let subtitle: String?
}

// MARK: - Place Details View

struct PlaceDetailsView: View {
    @Environment(\.dismiss) private var dismiss

    let placeName = "Park23 Mall"
    let isAccessible = true
    let reviewCount = 0

    let facilities: [Facility] = [
        Facility(name: "Entrance", icon: Image(systemName: "door.left.hand.open"), tags: ["Ramp", "Handrail", "Automatic Doors"], extraCount: 5, subtitle: nil),
        Facility(name: "Elevator", icon: Image(systemName: "elevator.fill"), tags: ["Wide entrance", "reachable buttons"], extraCount: 0, subtitle: nil),
        Facility(name: "Toilet", icon: Image(systemName: "toilet.fill"), tags: [], extraCount: 0, subtitle: "This place doesn't has an accessible toilet yet")
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                heroSection
                contentSection
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.white)
    }

    // MARK: - Hero Image Section

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Hero image
            Image("park23_hero") // Replace with your asset
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 253)
                .clipped()

            // Bottom gradient overlay
            LinearGradient(
                colors: [.clear, .black.opacity(0.4)],
                startPoint: .center,
                endPoint: .bottom
            )

            // Controls overlay
            VStack {
                controlsBar
                Spacer()
                bottomOverlay
            }
            .padding(.top, 60)
        }
        .frame(height: 253)
    }

    private var controlsBar: some View {
        HStack {
            // Back button
            GlassButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            // Share + Bookmark group
            HStack(spacing: 0) {
                GlassButton(icon: "square.and.arrow.up") {}
                GlassButton(icon: "bookmark.fill") {}
            }
            .background(.ultraThinMaterial, in: Capsule())
        }
        .padding(.horizontal, 16)
    }

    private var bottomOverlay: some View {
        HStack {
            // Page indicator dots
            HStack(spacing: 4) {
                Capsule().fill(.white).frame(width: 27, height: 4)
                Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
                Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
            }

            Spacer()

            // Gallery chip
            GalleryChip()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: 16) {
            placeInfoCard
            Divider()
            facilitiesHeader
            ForEach(facilities) { facility in
                FacilityCard(facility: facility)
            }
        }
        .padding(.top, 16)
        .padding(.horizontal, 22)
        .padding(.bottom, 32)
    }

    // MARK: - Place Info

    private var placeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Accessible badge
            if isAccessible {
                AccessibleBadge()
            }

            // Name + action buttons
            HStack {
                Text(placeName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))

                Spacer()

                HStack(spacing: 8) {
                    CircleActionButton(icon: "location.fill", color: Color(red: 0, green: 0.53, blue: 1))
                    CircleActionButton(icon: "phone.fill", color: Color(red: 0, green: 0.53, blue: 1))
                }
            }

            // Review section
            VStack(alignment: .leading, spacing: 12) {
                Text("No one review this place yet")
                    .font(.system(size: 15))
                    .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.23))

                Button(action: {}) {
                    Text("Be the first reviewer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color(red: 0, green: 0.6, blue: 1))
                        .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Facilities Header

    private var facilitiesHeader: some View {
        HStack(alignment: .center) {
            Label {
                Text("Facilities")
                    .font(.system(size: 20, weight: .bold))
            } icon: {
                Image(systemName: "info.circle.fill")
            }
            .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.23))

            Spacer()

            // Source avatars
            HStack(spacing: -8) {
                ForEach(0..<3) { _ in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 20, height: 20)
                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                }
                Text("+10")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.gray.opacity(0.2), lineWidth: 1))
            }

            Text("Google Maps +2")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color(red: 0.45, green: 0.45, blue: 0.45))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(red: 0.95, green: 0.96, blue: 0.97))
                .clipShape(Capsule())
        }
    }
}

// MARK: - Supporting Components

struct GlassButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                .frame(width: 44, height: 44)
        }
        .background(.ultraThinMaterial, in: Circle())
    }
}

struct GalleryChip: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Gallery")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.23))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 0.95, green: 0.96, blue: 0.97))
        .clipShape(Capsule())
    }
}

struct AccessibleBadge: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("Accessible")
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.04, green: 0.43, blue: 0.09))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Color(red: 0.87, green: 0.96, blue: 0.89))
        .clipShape(Capsule())
    }
}

struct CircleActionButton: View {
    let icon: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.15))
                .clipShape(Circle())
        }
    }
}

struct FacilityCard: View {
    let facility: Facility

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Illustration placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(red: 0.95, green: 0.96, blue: 0.97).opacity(0.6))
                .frame(width: 80, height: 72)
                .overlay {
                    facility.icon
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 36, height: 36)
                        .foregroundColor(.gray)
                }

            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(facility.name)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.23))

                if let subtitle = facility.subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.1, green: 0.1, blue: 0.1))
                        .lineLimit(2)
                } else {
                    // Tags
                    FlowLayout(spacing: 8) {
                        ForEach(facility.tags, id: \.self) { tag in
                            FacilityTag(text: tag)
                        }
                        if facility.extraCount > 0 {
                            FacilityTag(text: "+\(facility.extraCount)")
                        }
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(Color(red: 0.37, green: 0.37, blue: 0.37))
                .padding(.top, 8)
        }
        .padding(16)
        .background(Color(red: 0.95, green: 0.96, blue: 0.97))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct FacilityTag: View {
    let text: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(Color(red: 0.23, green: 0.23, blue: 0.23))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Color.white)
        .clipShape(Capsule())
    }
}

// MARK: - Flow Layout (for wrapping tags)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PlaceDetailsView()
            .navigationBarHidden(true)
    }
}

>reviewed
import SwiftUI

struct PlaceDetailsView: View {
    var body: some View {
        ZStack(alignment: .top) {
            // Background
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Hero Image
                ZStack(alignment: .top) {
                    Image("park23_hero")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 253)
                        .clipped()
                    
                    // Top Controls
                    HStack {
                        // Back Button
                        Button(action: {}) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        
                        Spacer()
                        
                        // Action Buttons
                        HStack(spacing: 12) {
                            Button(action: {}) {
                                Image(systemName: "hand.thumbsup.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                            Button(action: {}) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 60)
                    
                    // Gallery Chip
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {}) {
                                HStack(spacing: 6) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 12))
                                    Text("Gallery")
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .foregroundColor(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                            }
                            .padding(.trailing, 16)
                            .padding(.bottom, 16)
                        }
                    }
                    .frame(height: 253)
                }
                .frame(height: 253)
                
                // Content
                ScrollView {
                    VStack(spacing: 0) {
                        // Drag Indicator & Gallery
                        HStack {
                            // Drag indicators
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(.systemGray3))
                                    .frame(width: 27, height: 4)
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 4, height: 4)
                                Circle()
                                    .fill(Color(.systemGray4))
                                    .frame(width: 4, height: 4)
                            }
                            Spacer()
                        }
                        .padding(.top, 12)
                        .padding(.horizontal, 22)
                        
                        // Place Info Section
                        VStack(alignment: .leading, spacing: 12) {
                            // Accessible Badge
                            HStack(spacing: 6) {
                                Image(systemName: "accessibility.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                Text("Accessible")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.green.opacity(0.1), in: Capsule())
                            
                            // Title & Actions
                            HStack {
                                Text("Park23 Mall")
                                    .font(.system(size: 24, weight: .bold))
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                        .frame(width: 36, height: 36)
                                        .background(Color.blue, in: Circle())
                                }
                                
                                Button(action: {}) {
                                    Image(systemName: "phone.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.green)
                                        .frame(width: 36, height: 36)
                                        .background(Color.green.opacity(0.15), in: Circle())
                                }
                            }
                            
                            // Review Banner
                            Button(action: {}) {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                    Text("Thank you for the review!")
                                        .font(.system(size: 14))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        
                        // Divider
                        Divider()
                            .padding(.top, 16)
                        
                        // Facilities Header
                        HStack {
                            Text("🏛 Facilities")
                                .font(.system(size: 18, weight: .semibold))
                            
                            Spacer()
                            
                            // Avatars
                            HStack(spacing: -6) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(Color(.systemGray4))
                                        .frame(width: 20, height: 20)
                                        .overlay(Circle().stroke(.white, lineWidth: 1.5))
                                }
                                Text("+10")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.leading, 4)
                            }
                            
                            Text("Google Maps +2")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 16)
                        
                        // Facility Cards
                        VStack(spacing: 12) {
                            FacilityCard(
                                title: "Entrance",
                                image: "entrance_graphic",
                                tags: ["Ramp", "Handrail", "Automatic Doors", "+5"]
                            )
                            
                            FacilityCard(
                                title: "Elevator",
                                image: "elevator_graphic",
                                tags: ["Wide entrance", "reachable buttons"]
                            )
                            
                            FacilityCard(
                                title: "Toilet",
                                image: "toilet_graphic",
                                subtitle: "This place doesn't has an accessible toilet yet",
                                tags: []
                            )
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
}

// MARK: - Facility Card

struct FacilityCard: View {
    let title: String
    let image: String
    var subtitle: String? = nil
    let tags: [String]
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Illustration
            Image(image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 72)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    // Tags
                    FlowLayout(spacing: 6) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 4) {
                                if !tag.hasPrefix("+") {
                                    Image(systemName: "door.left.hand.open")
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                                Text(tag)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Color(.systemGray6), in: Capsule())
                        }
                    }
                }
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding(16)
        .background(Color(.systemGray6).opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Flow Layout for Tags

struct FlowLayout: Layout {
    var spacing: CGFloat = 6
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }
        
        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}

// MARK: - Preview

#Preview {
    PlaceDetailsView()
}

>gallery
import SwiftUI

// MARK: - Gallery View

struct GalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: GalleryTab = .all

    enum GalleryTab: String, CaseIterable {
        case all = "All"
        case entrance = "Entrance"
        case elevator = "Elevator"
        case toilet = "Toilet"
    }

    // Sample photo data — replace with your actual image sources
    let photos: [String] = (1...12).map { "photo_\($0)" }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented tabs
            segmentedControl
                .padding(.horizontal, 8)

            // Add Photos button
            addPhotosButton
                .padding(.horizontal, 8)
                .padding(.vertical, 16)

            // Photo grid
            ScrollView(.vertical, showsIndicators: false) {
                photoGrid
                    .padding(.horizontal, 8)
            }
        }
        .background(.white)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle("Gallery")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                }
            }
        }
    }

    // MARK: - Segmented Control

    private var segmentedControl: some View {
        HStack(spacing: 4) {
            ForEach(GalleryTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            selectedTab == tab
                                ? Color.white
                                : Color(.systemGray6),
                            in: Capsule()
                        )
                }
            }
        }
        .padding(4)
        .background(Color(red: 0.91, green: 0.91, blue: 0.91), in: Capsule())
    }

    // MARK: - Add Photos Button

    private var addPhotosButton: some View {
        Button {
            // Add photos action
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16))
                Text("Add Photos")
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundStyle(.blue)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(red: 0.95, green: 0.96, blue: 0.97), in: Capsule())
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        VStack(spacing: 4) {
            // Row 1: Large hero image
            photoCell(index: 0)
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .frame(height: 387)
                .clipShape(RoundedRectangle(cornerRadius: 11))

            // Row 2: Two stacked small + one large
            HStack(spacing: 4) {
                VStack(spacing: 4) {
                    photoCell(index: 1)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    photoCell(index: 2)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(width: 125)

                photoCell(index: 3)
                    .frame(maxWidth: .infinity)
                    .frame(height: 254)
                    .clipShape(RoundedRectangle(cornerRadius: 15))
            }
            .frame(height: 254)

            // Row 3: Three equal small photos
            HStack(spacing: 4) {
                ForEach(4..<7, id: \.self) { i in
                    photoCell(index: i)
                        .aspectRatio(1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            // Row 4: One large + two stacked small
            HStack(spacing: 4) {
                photoCell(index: 7)
                    .frame(maxWidth: .infinity)
                    .frame(height: 254)
                    .clipShape(RoundedRectangle(cornerRadius: 15))

                VStack(spacing: 4) {
                    photoCell(index: 8)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    photoCell(index: 9)
                        .frame(height: 125)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .frame(width: 125)
            }
            .frame(height: 254)
        }
    }

    // MARK: - Photo Cell

    @ViewBuilder
    private func photoCell(index: Int) -> some View {
        if index < photos.count {
            // Replace with Image(photos[index]) for real assets
            Image(photos[index])
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color(.systemGray5))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GalleryView()
    }
}

>My review
import SwiftUI

// MARK: - Models

struct ReviewPlace {
    let name: String
    let reviewDate: String
    let facilities: [String]
    let photos: [String] // image names
    let additionalPhotosCount: Int
    let notes: [String]
    let additionalNotesCount: Int
}

enum ReviewTab: String, CaseIterable {
    case entrance = "Entrance"
    case elevator = "Elevator"
    case toilet = "Toilet"
}

// MARK: - Main View

struct MyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: ReviewTab = .entrance
    
    let place = ReviewPlace(
        name: "Park23 Mall",
        reviewDate: "26 January 2026",
        facilities: ["Ramp", "Handrail", "Automatic Doors", "Manual Doors", "Security Assistance"],
        photos: ["photo1", "photo2", "photo3", "photo4"],
        additionalPhotosCount: 10,
        notes: ["The entrance is quite hard to find. When I went there, there's a lot of stairs and it is very hard too see the signage and need to ask the security."],
        additionalNotesCount: 10
    )
    
    var body: some View {
        VStack(spacing: 0) {
            // Content
            ScrollView {
                VStack(spacing: 0) {
                    // Place Info Section
                    placeInfoSection
                    
                    // Tab Section + Content
                    reviewContentSection
                }
            }
            
            // Bottom Bar
            bottomBar
        }
        .background(Color.white)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Your Review")
                    .font(.system(size: 17, weight: .semibold))
            }
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color(hex: "1A1A1A"))
                }
            }
        }
    }
    
    // MARK: - Place Info Section
    
    private var placeInfoSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(place.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "1A1A1A"))
                
                Text("Reviewed at \(place.reviewDate)")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "5F5F5F"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Update Review Button
            Button(action: {}) {
                Text("Update Review")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(Color(hex: "0099FF"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "F2F4F7"))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
    
    // MARK: - Review Content Section
    
    private var reviewContentSection: some View {
        VStack(spacing: 0) {
            // Tab Bar
            tabBar
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            
            // Content based on selected tab
            VStack(spacing: 24) {
                whatProvidedSection
                photosSection
                notesSection
            }
            .padding(.horizontal, 22)
        }
        .background(Color(hex: "F2F4F7"))
    }
    
    // MARK: - Tab Bar
    
    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(ReviewTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    Text(tab.rawValue.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(
                            selectedTab == tab
                            ? Color(hex: "3B3B3B")
                            : Color(hex: "5F5F5F")
                        )
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                            ? Color.white
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(Color.white)
        .clipShape(Capsule())
    }
    
    // MARK: - What Provided Section
    
    private var whatProvidedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What provided")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "3B3B3B"))
            
            FlowLayout(spacing: 8) {
                ForEach(place.facilities, id: \.self) { facility in
                    FacilityChip(title: facility)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Photos Section
    
    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(hex: "3B3B3B"))
            
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { index in
                    if index < 3 {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 80, height: 80)
                            .overlay(
                                // Placeholder for actual images
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    } else {
                        // Last image with "+10" overlay
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 80, height: 80)
                            
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 80, height: 80)
                            
                            Text("+\(place.additionalPhotosCount)")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Notes Section
    
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Notes")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Color(hex: "3B3B3B"))
                
                Spacer()
                
                Text("Link")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(Color(hex: "0099FF"))
            }
            
            // Note Card
            VStack(alignment: .leading, spacing: 8) {
                Text(place.notes.first ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "5F5F5F"))
                    .lineSpacing(4)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .cornerRadius(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Bottom Bar
    
    private var bottomBar: some View {
        HStack {
            Text("Any changes in the entrance?")
                .font(.system(size: 15))
                .foregroundColor(Color(hex: "3B3B3B"))
            
            Spacer()
            
            Button(action: {}) {
                Text("Update Review")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Color(hex: "0099FF"))
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(height: 0.5),
            alignment: .top
        )
    }
}

// MARK: - Facility Chip

struct FacilityChip: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.square.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(hex: "3B3B3B"))
            
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(hex: "3B3B3B"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout (for wrapping chips)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }
    
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        MyReviewView()
    }
}
