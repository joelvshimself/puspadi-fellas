import Foundation

enum CloudflareConfig {
    /// Override these values with Info.plist keys in development or CI. No
    /// provider secret belongs in the app; only public client identifiers do.
    static let apiBaseURL: URL = {
        #if DEBUG
        // Xcode scheme → Run → Environment: ROLLSPOT_API_BASE_URL=http://192.168.x.x:8787
        if let value = ProcessInfo.processInfo.environment["ROLLSPOT_API_BASE_URL"],
           let url = URL(string: value) {
            return url
        }
        // Gitignored: Mobile/scripts/write-ios-local-api-url.sh — see Mobile/LOCAL_DEV_API.md
        if let url = localDevURLFromBundleFile() {
            return url
        }
        #endif
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

    #if DEBUG
    private static func localDevURLFromBundleFile() -> URL? {
        guard let fileURL = Bundle.main.url(forResource: "LocalAPIBaseURL", withExtension: "txt") else {
            return nil
        }
        guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains("REPLACE_WITH") else { return nil }
        return URL(string: text)
    }
    #endif
}
