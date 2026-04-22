import Foundation

extension Notification.Name {
    static let appSettingsDidChange = Notification.Name("Hodgepodge.appSettingsDidChange")
}

enum AppSettingsNotificationUserInfoKey {
    static let snapshot = "snapshot"
}

protocol AppSettingsStoring: Sendable {
    func loadSettings() -> AppSettingsSnapshot
    func saveSettings(_ snapshot: AppSettingsSnapshot)
}

final class AppSettingsObserver {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping @MainActor (AppSettingsSnapshot) -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: .appSettingsDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let snapshot = notification.userInfo?[AppSettingsNotificationUserInfoKey.snapshot] as? AppSettingsSnapshot else {
                return
            }

            MainActor.assumeIsolated {
                onChange(snapshot)
            }
        }
    }

    deinit {
        if let token {
            notificationCenter.removeObserver(token)
        }
    }
}

struct AppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default,
        encoder: JSONEncoder = CatalogActionHistoryCodec.makeEncoder(),
        decoder: JSONDecoder = CatalogActionHistoryCodec.makeDecoder()
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadSettings() -> AppSettingsSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .standard
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppSettingsSnapshot.self, from: data)
        } catch {
            report(error, prefix: "Failed to load app settings")
            return .standard
        }
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            notificationCenter.post(
                name: .appSettingsDidChange,
                object: nil,
                userInfo: [AppSettingsNotificationUserInfoKey.snapshot: snapshot]
            )
        } catch {
            report(error, prefix: "Failed to save app settings")
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Hodgepodge", isDirectory: true)
            .appendingPathComponent("app-settings.json", isDirectory: false)
    }

    private func report(_ error: Error, prefix: String) {
#if DEBUG
        NSLog("%@: %@", prefix, error.localizedDescription)
#endif
    }
}
