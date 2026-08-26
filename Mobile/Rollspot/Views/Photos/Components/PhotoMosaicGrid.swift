import SwiftUI

/// The tiled gallery from node 526:17129.
///
/// The mockup's tile sizes all fall out of a 3-column grid with a 4pt gutter:
/// a small tile is one column, a large tile spans two columns and two rows, and
/// the hero spans all three. The four block shapes repeat every ten photos:
///
///   1. hero            — one photo, full width, square
///   2. smallsLeading   — two stacked smalls on the left, one large on the right
///   3. smallRow        — three smalls side by side
///   4. largeLeading    — one large on the left, two stacked smalls on the right
///
/// `width` is the content width the grid should fill (the parent measures it
/// once, so the tiles size in a single layout pass instead of settling).
struct PhotoMosaicGrid: View {
    let photos: [FacilityPhoto]
    let width: CGFloat
    var onSelect: (FacilityPhoto) -> Void = { _ in }

    private var spacing: CGFloat { PhotoMetrics.mosaicSpacing }
    private var smallSize: CGFloat { max((width - spacing * 2) / 3, 0) }
    private var largeSize: CGFloat { smallSize * 2 + spacing }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(sections) { section in
                block(for: section)
            }
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func block(for section: MosaicSection) -> some View {
        switch section.kind {
        case .hero:
            tile(section.photos[0], size: width, cornerRadius: PhotoMetrics.heroCornerRadius)

        case .smallsLeading:
            HStack(spacing: spacing) {
                VStack(spacing: spacing) {
                    smallTile(section.photos[0])
                    smallTile(section.photos[1])
                }
                largeTile(section.photos[2])
            }

        case .smallRow:
            HStack(spacing: spacing) {
                ForEach(section.photos) { smallTile($0) }
                Spacer(minLength: 0)
            }

        case .largeLeading:
            HStack(spacing: spacing) {
                largeTile(section.photos[0])
                VStack(spacing: spacing) {
                    smallTile(section.photos[1])
                    smallTile(section.photos[2])
                }
            }
        }
    }

    private func smallTile(_ photo: FacilityPhoto) -> some View {
        tile(photo, size: smallSize, cornerRadius: PhotoMetrics.smallTileCornerRadius)
    }

    private func largeTile(_ photo: FacilityPhoto) -> some View {
        tile(photo, size: largeSize, cornerRadius: PhotoMetrics.largeTileCornerRadius)
    }

    private func tile(_ photo: FacilityPhoto, size: CGFloat, cornerRadius: CGFloat) -> some View {
        Button {
            onSelect(photo)
        } label: {
            ZStack(alignment: .bottom) {
                FacilityPhotoImage(photo: photo, cornerRadius: cornerRadius)
                if let caption = photo.caption {
                    PhotoCaptionOverlay(caption: caption)
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Photo")
    }

    // MARK: Block planning

    private struct MosaicSection: Identifiable {
        enum Kind {
            case hero, smallsLeading, smallRow, largeLeading

            /// Photos the block consumes.
            var capacity: Int { self == .hero ? 1 : 3 }
        }

        let id: Int
        let kind: Kind
        let photos: [FacilityPhoto]
    }

    private static let cycle: [MosaicSection.Kind] = [.hero, .smallsLeading, .smallRow, .largeLeading]

    private var sections: [MosaicSection] {
        var result: [MosaicSection] = []
        var index = 0

        while index < photos.count {
            let kind = Self.cycle[result.count % Self.cycle.count]
            let slice = Array(photos[index..<min(index + kind.capacity, photos.count)])
            // A short tail can't fill a two-row block, so it falls back to a
            // plain leading-aligned row rather than leaving a hole.
            let resolved = slice.count == kind.capacity ? kind : .smallRow
            result.append(MosaicSection(id: result.count, kind: resolved, photos: slice))
            index += slice.count
        }

        return result
    }
}

#Preview {
    ScrollView {
        PhotoMosaicGrid(photos: FacilityPhoto.samples, width: 386)
            .padding(PhotoMetrics.gutter)
    }
}
