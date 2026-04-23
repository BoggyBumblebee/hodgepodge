@preconcurrency import UserNotifications
import XCTest
@testable import Hodgepodge

final class CommandNotificationSchedulerTests: XCTestCase {
    func testScheduleRequestsAuthorizationAndAddsNotificationWhenAllowed() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(snapshot: .standard)
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully."
            )
        )

        let requests = center.addedRequests
        let requestAuthorizationCallCount = center.requestAuthorizationCallCount
        let requestedOptions = center.requestedOptions
        XCTAssertEqual(requestAuthorizationCallCount, 1)
        XCTAssertEqual(requestedOptions, [.alert, .sound])
        XCTAssertEqual(requests.count, 1)
        XCTAssertEqual(requests.first?.content.title, "Install Complete")
        XCTAssertEqual(requests.first?.content.body, "wget completed successfully.")
    }

    func testScheduleSkipsNotificationWhenAuthorizationIsDenied() async {
        let center = TestUserNotificationCenter(authorizationStatus: .denied)
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(snapshot: .standard)
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Upgrade Failed",
                body: "htop couldn’t be completed."
            )
        )

        let requestAuthorizationCallCount = center.requestAuthorizationCallCount
        let addedRequests = center.addedRequests
        XCTAssertEqual(requestAuthorizationCallCount, 0)
        XCTAssertTrue(addedRequests.isEmpty)
    }

    func testScheduleCachesAuthorizationAfterFirstSuccessfulRequest() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .notDetermined,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(snapshot: .standard)
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Fetch Complete",
                body: "wget completed successfully."
            )
        )
        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully."
            )
        )

        let requestAuthorizationCallCount = center.requestAuthorizationCallCount
        let addedRequests = center.addedRequests
        XCTAssertEqual(requestAuthorizationCallCount, 1)
        XCTAssertEqual(addedRequests.count, 2)
    }

    func testScheduleSkipsNotificationWhenDisabledInSettings() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    defaultLaunchSection: .catalog,
                    notifications: .init(isEnabled: false)
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully."
            )
        )

        XCTAssertEqual(center.requestAuthorizationCallCount, 0)
        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testScheduleOmitsSoundWhenDisabledInSettings() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    defaultLaunchSection: .catalog,
                    notifications: .init(soundEnabled: false)
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully."
            )
        )

        XCTAssertEqual(center.addedRequests.count, 1)
        XCTAssertNil(center.addedRequests.first?.content.sound)
    }

    func testScheduleSkipsShortNotificationsWhenScopeIsLongRunningOnly() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    notifications: .init(scope: .longRunningOnly)
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully.",
                elapsedTime: 3
            )
        )

        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testScheduleAllowsLongRunningNotificationsWhenScopeIsLongRunningOnly() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    notifications: .init(scope: .longRunningOnly)
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Upgrade Complete",
                body: "wget completed successfully.",
                elapsedTime: 12
            )
        )

        XCTAssertEqual(center.addedRequests.count, 1)
    }

    func testScheduleSkipsNotificationWhenCategoryIsDisabledInSettings() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    notifications: .init(categories: [.services])
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Install Complete",
                body: "wget completed successfully.",
                category: .packageActions
            )
        )

        XCTAssertTrue(center.addedRequests.isEmpty)
    }

    func testScheduleAllowsNotificationWhenCategoryIsEnabledInSettings() async {
        let center = TestUserNotificationCenter(
            authorizationStatus: .authorized,
            requestAuthorizationResult: true
        )
        let scheduler = CommandNotificationScheduler(
            center: center,
            settingsStore: TestAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    notifications: .init(categories: [.services])
                )
            )
        )

        await scheduler.schedule(
            CommandNotification(
                title: "Restart Complete",
                body: "postgresql@17 completed successfully.",
                category: .services
            )
        )

        XCTAssertEqual(center.addedRequests.count, 1)
    }
}

private struct TestAppSettingsStore: AppSettingsStoring {
    let snapshot: AppSettingsSnapshot

    func loadSettings() -> AppSettingsSnapshot {
        snapshot
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {}
}

private final class TestUserNotificationCenter: @unchecked Sendable, UserNotificationCentering {
    private let currentAuthorizationStatus: UNAuthorizationStatus
    private let requestAuthorizationResult: Bool

    private(set) var requestedOptions: UNAuthorizationOptions?
    private(set) var requestAuthorizationCallCount = 0
    private(set) var addedRequests: [UNNotificationRequest] = []

    init(
        authorizationStatus: UNAuthorizationStatus,
        requestAuthorizationResult: Bool = false
    ) {
        self.currentAuthorizationStatus = authorizationStatus
        self.requestAuthorizationResult = requestAuthorizationResult
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        currentAuthorizationStatus
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestedOptions = options
        requestAuthorizationCallCount += 1
        return requestAuthorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }
}
