import Foundation

extension Notification.Name {
    static let favoritePackageIDsDidChange = Notification.Name("Hodgepodge.favoritePackageIDsDidChange")
}

enum FavoritePackageNotificationUserInfoKey {
    static let ids = "ids"
}

protocol FavoritePackageStoring {
    func loadFavoritePackageIDs() -> [String]
    func saveFavoritePackageIDs(_ ids: [String])
}

protocol CatalogPreferencesStoring: FavoritePackageStoring {
    func loadPreferences() -> CatalogPreferencesSnapshot
    func savePreferences(_ snapshot: CatalogPreferencesSnapshot)
}

final class FavoritePackageIDsObserver {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping @MainActor ([String]) -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: .favoritePackageIDsDidChange,
            object: nil,
            queue: .main
        ) { notification in
            guard let ids = notification.userInfo?[FavoritePackageNotificationUserInfoKey.ids] as? [String] else {
                return
            }

            MainActor.assumeIsolated {
                onChange(ids)
            }
        }
    }

    deinit {
        if let token {
            notificationCenter.removeObserver(token)
        }
    }
}

struct CatalogPreferencesStore: CatalogPreferencesStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let notificationCenter: NotificationCenter

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

    func loadPreferences() -> CatalogPreferencesSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(CatalogPreferencesSnapshot.self, from: data)
        } catch {
            report(error, prefix: "Failed to load catalog preferences")
            return .empty
        }
    }

    func savePreferences(_ snapshot: CatalogPreferencesSnapshot) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(snapshot)
            try data.write(to: fileURL, options: .atomic)
            notifyFavoritePackageIDsChanged(snapshot.favoritePackageIDs)
        } catch {
            report(error, prefix: "Failed to save catalog preferences")
        }
    }

    func loadFavoritePackageIDs() -> [String] {
        loadPreferences().favoritePackageIDs
    }

    func saveFavoritePackageIDs(_ ids: [String]) {
        let snapshot = loadPreferences()
        savePreferences(
            CatalogPreferencesSnapshot(
                favoritePackageIDs: ids,
                savedSearches: snapshot.savedSearches
            )
        )
    }

    private func notifyFavoritePackageIDsChanged(_ ids: [String]) {
        notificationCenter.post(
            name: .favoritePackageIDsDidChange,
            object: nil,
            userInfo: [FavoritePackageNotificationUserInfoKey.ids: ids]
        )
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Hodgepodge", isDirectory: true)
            .appendingPathComponent("catalog-preferences.json", isDirectory: false)
    }

    private func report(_ error: Error, prefix: String) {
#if DEBUG
        NSLog("%@: %@", prefix, error.localizedDescription)
#endif
    }
}
