import Foundation
import Shared

/// The shared Kotlin module (Mobile/shared) holds Rollspot's business logic for
/// both apps. iOS creates it once here; views and services use `RollspotServices.sdk`.
enum RollspotServices {
    static let sdk = RollspotSdk(
        baseUrl: CloudflareConfig.apiBaseURL.absoluteString,
        tokenStore: KeychainTokenStore(),
        engine: nil
    )
}

/// The shared module's token storage, backed by the same Keychain item the app
/// has always used, so existing sign-ins survive the move to shared code.
final class KeychainTokenStore: NSObject, TokenStore {
    func load() -> String? { AuthTokenStore.load() }
    func save(token: String) { try? AuthTokenStore.save(token) }
    func clear() { AuthTokenStore.clear() }
}
