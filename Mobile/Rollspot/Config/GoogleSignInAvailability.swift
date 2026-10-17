import Foundation

/// Google Sign-In is optional at build time. Re-add the **GoogleSignIn** package product
/// in `Rollspot.xcodeproj` (Swift Package: https://github.com/google/GoogleSignIn-iOS)
/// and set this to `true`.
enum GoogleSignInAvailability {
    static let isLinked = false
}
