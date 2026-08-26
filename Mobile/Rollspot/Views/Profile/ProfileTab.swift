import SwiftUI

enum ProfileTab: String, CaseIterable, Identifiable, Hashable {
    case reviews = "REVIEWS"
    case photos = "PHOTOS"
    case settings = "SETTINGS"

    var id: String { rawValue }
    
    var localizedTitle: String {
        rawValue.localized
    }
}
