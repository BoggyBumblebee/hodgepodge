import Foundation

protocol CatalogActionHistoryStoring {
    func loadHistory() -> [CatalogPackageActionHistoryEntry]
    func saveHistory(_ entries: [CatalogPackageActionHistoryEntry])
}

struct CatalogActionHistoryStore: CatalogActionHistoryStoring {
    private let fileURL: URL
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadHistory() -> [CatalogPackageActionHistoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode([CatalogPackageActionHistoryEntry].self, from: data)
        } catch {
            report(error, prefix: "Failed to load catalog action history")
            return []
        }
    }

    func saveHistory(_ entries: [CatalogPackageActionHistoryEntry]) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            report(error, prefix: "Failed to save catalog action history")
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Hodgepodge", isDirectory: true)
            .appendingPathComponent("catalog-action-history.json", isDirectory: false)
    }

    private func report(_ error: Error, prefix: String) {
#if DEBUG
        NSLog("%@: %@", prefix, error.localizedDescription)
#endif
    }
}
