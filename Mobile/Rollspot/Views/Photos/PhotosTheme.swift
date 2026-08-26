import SwiftUI

/// Colors and measurements lifted straight from the Figma "Facilities Details
/// - Photos" frames (nodes 518:16038 default, 572:6900 add-photo menu,
/// 553:22988 confirm, 572:7071 photo-added). Kept in one place so the flow can
/// be checked against the mockup without hunting through the view bodies —
/// same approach as SearchSheet's `SheetMetrics`.
enum PhotoPalette {
    /// `grey` — segmented-control track.
    static let segmentedTrack = Color(designHex: 0xE7E7E7)
    /// `black/primary` — segmented-control labels.
    static let primaryLabel = Color(designHex: 0x3B3B3B)
    /// `background-1` — Add Photos pill, Browse tile, remove-button chips.
    static let background1 = Color(designHex: 0xF2F4F7)
    /// `background-2` — Add Photos pill while its menu is open.
    static let background2 = Color(designHex: 0xE9EDF1)
    /// `blue/brand-blue` — Add Photos / Browse labels, Submit fill.
    static let brandBlue = Color(designHex: 0x0099FF)
    /// `blue/tetriary-blue` — dashed border on the Browse tile.
    static let tertiaryBlue = Color(designHex: 0xD0DBE6)
    /// `green/background` — success toast fill.
    static let toastBackground = Color(designHex: 0xDFF5E2)
    /// `green/foreground` — success toast icon, copy, and dismiss glyph.
    static let toastForeground = Color(designHex: 0x0A6E17)
}

enum PhotoMetrics {
    // MARK: Toolbar (Header block, 116pt tall: 62pt status bar + 54pt toolbar)

    static let toolbarHeight: CGFloat = 54
    static let toolbarHorizontalPadding: CGFloat = 22
    static let backButtonSize: CGFloat = 44
    static let backChevronSize: CGFloat = 21
    static let titleSize: CGFloat = 17

    // MARK: Segmented control (node 526:17120)

    static let segmentedPadding: CGFloat = 4
    static let segmentedSpacing: CGFloat = 8
    static let segmentedItemHeight: CGFloat = 32
    static let segmentedLabelSize: CGFloat = 12
    static let segmentedTracking: CGFloat = -0.08

    // MARK: Add Photos pill (node 526:17128)

    static let addPhotosHeight: CGFloat = 48
    static let addPhotosSpacing: CGFloat = 16
    static let addPhotosLabelSize: CGFloat = 17

    /// The gallery block sits in an 8pt gutter; the pill/segments share it.
    static let gutter: CGFloat = 8
    /// pt-[16px] between the segmented control and the Add Photos pill.
    static let addPhotosTopPadding: CGFloat = 16

    // MARK: Mosaic gallery (node 526:17129)

    static let mosaicSpacing: CGFloat = 4
    static let heroCornerRadius: CGFloat = 11.2
    static let largeTileCornerRadius: CGFloat = 14.844
    static let smallTileCornerRadius: CGFloat = 8.016

    // MARK: Add Photos screen (node 572:6875)

    static let composerHorizontalPadding: CGFloat = 22
    static let composerSpacing: CGFloat = 8
    static let browseCornerRadius: CGFloat = 16
    static let browseBorderWidth: CGFloat = 2
    static let composerTileCornerRadius: CGFloat = 11.2
    static let removeButtonSize: CGFloat = 24
    static let removeButtonInset: CGFloat = 8
    static let submitHeight: CGFloat = 56
    /// gap-[24px] between the tile grid and the Submit button.
    static let submitTopSpacing: CGFloat = 24

    // MARK: Success toast (node 572:7180)

    static let toastPadding: CGFloat = 14
    static let toastSpacing: CGFloat = 14
    static let toastCornerRadius: CGFloat = 16
    static let toastTextSize: CGFloat = 15
    /// The toast sits flush with the top of the content block (top-[114px]
    /// against content at top-[116px]), i.e. 2pt above it.
    static let toastTopOffset: CGFloat = -2
    /// Auto-dismiss window; the toast also has an explicit close button.
    static let toastDuration: Duration = .seconds(4)
}

extension Color {
    /// 0xRRGGBB literal from a Figma color variable.
    init(designHex hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}

#Preview("Photo palette") {
    HStack(spacing: 8) {
        Circle().fill(PhotoPalette.brandBlue).frame(width: 24, height: 24)
        Circle().fill(PhotoPalette.background1).frame(width: 24, height: 24)
        Circle().fill(PhotoPalette.toastBackground).frame(width: 24, height: 24)
    }
    .padding()
}
