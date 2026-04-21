import Foundation

@MainActor
protocol BrewLocating {
    func locate() async throws -> HomebrewInstallation
}

enum BrewLocatorError: LocalizedError, Equatable {
    case brewNotFound
    case invalidVersionOutput(String)

    var errorDescription: String? {
        switch self {
        case .brewNotFound:
            "Homebrew was not found. Install Homebrew or point the app at a valid brew executable."
        case .invalidVersionOutput(let output):
            "Homebrew returned an unexpected version string: \(output)"
        }
    }
}

struct BrewLocator: BrewLocating {
    private let runner: any CommandRunning
    private let fileManager: FileManager
    private let clock: () -> Date
    private let executableCandidates: [String]

    init(
        runner: any CommandRunning,
        fileManager: FileManager = .default,
        clock: @escaping () -> Date = Date.init,
        executableCandidates: [String]? = nil
    ) {
        self.runner = runner
        self.fileManager = fileManager
        self.clock = clock
        self.executableCandidates = executableCandidates ?? Self.defaultExecutableCandidates(using: fileManager)
    }

    func locate() async throws -> HomebrewInstallation {
        let brewPath = try await locateExecutable()
        let versionOutput = try await runner.run(executable: brewPath, arguments: ["--version"])
        let version = try parseVersion(from: versionOutput.stdout)
        let prefix = try await trimmedOutput(executable: brewPath, arguments: ["--prefix"])
        let cellar = try await trimmedOutput(executable: brewPath, arguments: ["--cellar"])
        let repository = try await trimmedOutput(executable: brewPath, arguments: ["--repository"])
        let tapsOutput = try await trimmedOutput(executable: brewPath, arguments: ["tap"])
        let taps = tapsOutput
            .split(separator: "\n")
            .map(String.init)

        return HomebrewInstallation(
            brewPath: brewPath,
            version: version,
            prefix: prefix,
            cellar: cellar,
            repository: repository,
            taps: taps,
            detectedAt: clock()
        )
    }

    private func locateExecutable() async throws -> String {
        for candidate in executableCandidates {
            let isPathCandidate = candidate != (candidate as NSString).lastPathComponent
            if isPathCandidate && !fileManager.isExecutableFile(atPath: candidate) {
                continue
            }

            do {
                _ = try await runner.run(executable: candidate, arguments: ["--version"])
                return candidate
            } catch {
                continue
            }
        }

        throw BrewLocatorError.brewNotFound
    }

    private func parseVersion(from output: String) throws -> String {
        guard
            let line = output.split(separator: "\n").first,
            let version = line.split(separator: " ").last
        else {
            throw BrewLocatorError.invalidVersionOutput(output)
        }

        return String(version)
    }

    private func trimmedOutput(executable: String, arguments: [String]) async throws -> String {
        let result = try await runner.run(executable: executable, arguments: arguments)
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func defaultExecutableCandidates(using fileManager: FileManager) -> [String] {
        let rootDirectory = fileManager.homeDirectoryForCurrentUser.pathComponents.first ?? ""

        return [
            NSString.path(withComponents: [rootDirectory, "opt", "homebrew", "bin", "brew"]),
            NSString.path(withComponents: [rootDirectory, "usr", "local", "bin", "brew"]),
            "brew"
        ]
    }
}
