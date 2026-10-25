import FirebaseCore
import OSLog
import FirebaseMessaging
import Shared
import SwiftUI
import UserNotifications

/// SwiftUI face of the shared `NotificationsModel`, plus the iOS-only parts: the system permission,
/// Firebase (push token and the announcements topic), the local unfinished-review reminder and taps.
/// What to send, to whom, and when the reminder is due is decided in shared code. Android: PushNotifications.kt.
@MainActor
final class PushNotificationsService: ObservableObject {
    static let shared = PushNotificationsService()

    @Published private(set) var state = NotificationsState(
        settings: NotificationSettings(savedPlaceReviews: true, announcements: true, reviewReminders: true),
        permission: .notAsked, isSignedIn: false, error: nil
    )

    private var model: NotificationsModel { RollspotServices.sdk.notifications }
    private let log = Logger(subsystem: "com.puspadifellas.app", category: "notifications")
    private var started = false
    private var subscribedToAnnouncements: Bool?

    /// Push needs GoogleService-Info.plist; without it the app runs with reminders only. Set at launch.
    nonisolated(unsafe) static var isFirebaseConfigured = false

    private init() {}

    /// Called once from the app delegate at launch.
    func start() {
        guard !started else { return }
        started = true
        Task { [weak self] in
            guard let states = self?.model.state else { return }
            for await state in states { self?.apply(state) }
        }
        Task { [weak self] in
            guard let plans = self?.model.reminder else { return }
            for await plan in plans { await self?.schedule(plan) }
        }
        Task { await refreshPermission() }
    }

    /// At launch and whenever the app comes back to the foreground (the user may have changed it in Settings).
    func refreshPermission() async {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        let permission: NotificationPermission = switch status {
        case .notDetermined: .notAsked
        case .denied: .denied
        default: .granted
        }
        model.setPermission(permission: permission)
        if permission == .granted { UIApplication.shared.registerForRemoteNotifications() }
    }

    /// Shows the system prompt (only ever once; afterwards iOS answers straight away).
    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        await refreshPermission()
        return granted
    }

    /// After the first place someone saves: the moment "new reviews here" makes sense to ask about.
    func askAfterFirstSave() {
        guard state.canAskPermission else { return }
        Task { await requestPermission() }
    }

    // MARK: Switches

    func setSavedPlaceReviews(_ on: Bool) async { await change(on) { try await self.model.setSavedPlaceReviews(on: on) } }
    func setReviewReminders(_ on: Bool) async { await change(on) { try await self.model.setReviewReminders(on: on) } }
    func setAnnouncements(_ on: Bool) async { await change(on) { try await self.model.setAnnouncements(on: on) } }

    /// Turning a switch on is the natural moment to ask for permission, if iOS hasn't asked yet.
    private func change(_ on: Bool, save: @escaping () async throws -> Void) async {
        if on, state.canAskPermission { await requestPermission() }
        // The shared model reverts the switch and sets `error` itself.
        try? await save()
    }

    // MARK: Firebase

    func didReceive(pushToken token: String) {
        Task { try? await model.setPushToken(token: token, platform: .ios) }
    }

    private func apply(_ state: NotificationsState) {
        self.state = state
        guard Self.isFirebaseConfigured, subscribedToAnnouncements != state.receivesAnnouncements else { return }
        subscribedToAnnouncements = state.receivesAnnouncements
        let topic = NotificationsModel.companion.ANNOUNCEMENTS_TOPIC
        if state.receivesAnnouncements {
            Messaging.messaging().subscribe(toTopic: topic)
        } else {
            Messaging.messaging().unsubscribe(fromTopic: topic)
        }
    }

    // MARK: Reminder

    private func schedule(_ plan: ReminderPlan?) async {
        let center = UNUserNotificationCenter.current()
        let id = ReminderPlan.companion.ID
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let plan else { return }
        let delay = Double(plan.fireAtMillis) / 1000 - Date().timeIntervalSince1970
        guard delay > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Finish your review".localized
        content.body = String(format: "You're part-way through reviewing %@. It only takes a minute.".localized, plan.placeName)
        content.sound = .default
        content.userInfo = [NotificationsModel.companion.PLACE_ID_KEY: plan.placeId]
        let request = UNNotificationRequest(
            identifier: id, content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        )
        do {
            try await center.add(request)
            log.info("Review reminder for \(plan.placeId, privacy: .public) in \(Int(delay), privacy: .public)s")
        } catch {
            log.error("Couldn't schedule the review reminder: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: Taps

    /// A push or the reminder was tapped: open its place the same way a shared link does.
    func open(placeId: String?) {
        guard let placeId, !placeId.isEmpty else { return }
        var components = URLComponents()
        components.scheme = DeepLinkRouter.scheme
        components.host = "place"
        components.queryItems = [URLQueryItem(name: "place_id", value: placeId)]
        if let url = components.url { DeepLinkRouter.shared.handle(url) }
    }
}

/// UIKit entry points SwiftUI doesn't have: APNs registration, Firebase's token, and notification taps.
final class RollspotAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            FirebaseApp.configure()
            Messaging.messaging().delegate = self
            PushNotificationsService.isFirebaseConfigured = true
        }
        UNUserNotificationCenter.current().delegate = self
        Task { @MainActor in PushNotificationsService.shared.start() }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard PushNotificationsService.isFirebaseConfigured else { return }
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // Simulators without push, or no aps-environment in the profile: reminders still work.
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in PushNotificationsService.shared.didReceive(pushToken: fcmToken) }
    }

    /// Pushes show as banners while the app is open too.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let placeId = response.notification.request.content.userInfo[NotificationsModel.companion.PLACE_ID_KEY] as? String
        await MainActor.run { PushNotificationsService.shared.open(placeId: placeId) }
    }
}
