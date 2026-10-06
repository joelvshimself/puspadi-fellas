import Foundation

enum CloudflareConfig {
    /// Override these values with Info.plist keys in development or CI. No
    /// provider secret belongs in the app; only public client identifiers do.
    static let apiBaseURL: URL = {
        if let value = Bundle.main.object(forInfoDictionaryKey: "ROLLSPOT_API_BASE_URL") as? String,
           let url = URL(string: value), !value.isEmpty {
            return url
        }
        return URL(string: "https://api.rollspot.app")!
    }()

    static let googleClientID: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "GOOGLE_IOS_CLIENT_ID") as? String ?? ""
        return value.contains("REPLACE_WITH") ? "" : value
    }()

    static let authCallbackURL = URL(string: "puspadi://auth/callback")!
}
