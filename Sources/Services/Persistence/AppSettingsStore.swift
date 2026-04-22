import Foundation

protocol AppSettingsStoring: Sendable {
    func loadSettings() -> AppSettingsSnapshot
    func saveSettings(_ snapshot: AppSettingsSnapshot)
}

struct AppSettingsStore: AppSettingsStoring, @unchecked Sendable {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = CatalogActionHistoryCodec.makeEncoder(),
        decoder: JSONDecoder = CatalogActionHistoryCodec.makeDecoder()
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    func loadSettings() -> AppSettingsSnapshot {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .default
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(AppSettingsSnapshot.self, from: data)
        } catch {
            report(error, prefix: "Failed to load app settings")
            return .default
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
