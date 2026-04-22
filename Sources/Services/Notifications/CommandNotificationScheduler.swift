import Foundation
import UserNotifications

struct CommandNotification: Equatable, Sendable {
    let title: String
    let body: String
}

protocol CommandNotificationScheduling: Sendable {
    func schedule(_ notification: CommandNotification) async
}

struct NullCommandNotificationScheduler: CommandNotificationScheduling {
    func schedule(_ notification: CommandNotification) async {}
}

protocol UserNotificationCentering: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
}

private struct UserNotificationCenterAdapter: UserNotificationCentering, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter) {
        self.center = center
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }
}

actor CommandNotificationScheduler: CommandNotificationScheduling {
    static let shared = CommandNotificationScheduler(
        center: UserNotificationCenterAdapter(center: UNUserNotificationCenter.current())
    )

    private let center: any UserNotificationCentering
    private var authorizationChecked = false
    private var isAuthorized = false

    init(center: any UserNotificationCentering) {
        self.center = center
    }

    func schedule(_ notification: CommandNotification) async {
        guard await ensureAuthorization() else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        try? await center.add(request)
    }

    private func ensureAuthorization() async -> Bool {
        if authorizationChecked {
            return isAuthorized
        }

        authorizationChecked = true
        let status = await center.authorizationStatus()

        switch status {
        case .authorized, .provisional, .ephemeral:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        case .denied:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        return isAuthorized
    }
}
