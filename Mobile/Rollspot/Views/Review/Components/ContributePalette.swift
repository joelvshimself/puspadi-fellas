import SwiftUI

/// Colours of the contribute flow, sampled from the Figma frames ("Contribute Review Category
/// Menus", "Question 3 - Filled", "Contribution Submitted"). Android: ui/theme/ContributeColors.
enum ContributePalette {
    /// Buttons, "Add Photos", selected states.
    static let blue = Color(designHex: 0x0099FE)
    static let progressFill = Color(designHex: 0x0884EC)
    static let progressTrack = Color(designHex: 0xD7D7D7)
    /// Titles and labels.
    static let text = Color(designHex: 0x363636)
    static let secondaryText = Color(designHex: 0x5E5E5E)
    /// "(Optional)".
    static let optionalText = Color(designHex: 0x979797)
    static let placeholder = Color(designHex: 0xADAFB1)
    /// Cards, text fields, the Add Photos box.
    static let fill = Color(designHex: 0xF2F3F7)
    static let completeFill = Color(designHex: 0xE4F5FF)
    static let disabledFill = Color(designHex: 0xE8E8E8)
    static let disabledText = Color(designHex: 0x8F8F8F)
    static let dash = Color(designHex: 0xD5D9E0)
    static let chevron = Color(designHex: 0x74767A)
    static let circleButton = Color(designHex: 0xF5F5F5)
}
