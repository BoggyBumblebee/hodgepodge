import Foundation

protocol BrewfileSelectionStoring {
    func loadSelection() -> URL?
    func saveSelection(_ url: URL?)
}

struct BrewfileSelectionStore: BrewfileSelectionStoring {
    private let fileURL: URL
    private let fileManager: FileManager

    init(
        fileURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileURL = fileURL ?? Self.defaultFileURL(fileManager: fileManager)
        self.fileManager = fileManager
    }

    func loadSelection() -> URL? {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            let path = try String(contentsOf: fileURL, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !path.isEmpty else {
                return nil
            }
            return URL(fileURLWithPath: path)
        } catch {
            report(error, prefix: "Failed to load Brewfile selection")
            return nil
        }
    }

    func saveSelection(_ url: URL?) {
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if let url {
                try url.path.write(to: fileURL, atomically: true, encoding: .utf8)
            } else if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            report(error, prefix: "Failed to save Brewfile selection")
        }
    }

    private static func defaultFileURL(fileManager: FileManager) -> URL {
        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)

        return baseURL
            .appendingPathComponent("Hodgepodge", isDirectory: true)
            .appendingPathComponent("selected-brewfile.txt", isDirectory: false)
    }

    private func report(_ error: Error, prefix: String) {
#if DEBUG
        NSLog("%@: %@", prefix, error.localizedDescription)
#endif
    }
}
