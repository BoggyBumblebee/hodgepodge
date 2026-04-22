import Foundation

protocol BrewTapsProviding: Sendable {
    func fetchTaps() async throws -> [BrewTap]
}

struct BrewTapsProvider: BrewTapsProviding, @unchecked Sendable {
    private let brewLocator: any BrewLocating
    private let runner: any CommandRunning

    init(
        brewLocator: any BrewLocating,
        runner: any CommandRunning
    ) {
        self.brewLocator = brewLocator
        self.runner = runner
    }

    func fetchTaps() async throws -> [BrewTap] {
        let installation = try await brewLocator.locate()
        let executable = installation.brewPath

        let tapNames = try await trimmedOutput(
            executable: executable,
            arguments: ["tap"]
        )
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !tapNames.isEmpty else {
            return []
        }

        let infoOutput = try await trimmedOutput(
            executable: executable,
            arguments: ["tap-info", "--json=v1"] + tapNames
        )

        let decoder = JSONDecoder()
        let entries = try decoder.decode([TapInfoEntry].self, from: Data(infoOutput.utf8))
        let tapsByName = Dictionary(uniqueKeysWithValues: entries.map { ($0.name, $0) })

        return tapNames.compactMap { name in
            tapsByName[name].map(BrewTap.init(entry:))
        }
    }

    private func trimmedOutput(
        executable: String,
        arguments: [String]
    ) async throws -> String {
        let result = try await runner.run(executable: executable, arguments: arguments)
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct TapInfoEntry: Decodable {
    let name: String
    let user: String?
    let repo: String?
    let repository: String?
    let path: String
    let official: Bool
    let formulaNames: [String]
    let caskTokens: [String]
    let formulaFiles: [String]
    let caskFiles: [String]
    let commandFiles: [String]
    let remote: String?
    let customRemote: Bool
    let isPrivate: Bool
    let head: String?
    let lastCommit: String?
    let branch: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case user
        case repo
        case repository
        case path
        case official
        case formulaNames = "formula_names"
        case caskTokens = "cask_tokens"
        case formulaFiles = "formula_files"
        case caskFiles = "cask_files"
        case commandFiles = "command_files"
        case remote
        case customRemote = "custom_remote"
        case isPrivate = "private"
        case head = "HEAD"
        case lastCommit = "last_commit"
        case branch
    }
}

private extension BrewTap {
    init(entry: TapInfoEntry) {
        self.init(
            name: entry.name,
            user: entry.user,
            repo: entry.repo,
            repository: entry.repository,
            path: entry.path,
            isOfficial: entry.official,
            formulaNames: entry.formulaNames,
            caskTokens: entry.caskTokens,
            formulaFiles: entry.formulaFiles,
            caskFiles: entry.caskFiles,
            commandFiles: entry.commandFiles,
            remote: entry.remote,
            customRemote: entry.customRemote,
            isPrivate: entry.isPrivate,
            head: entry.head,
            lastCommit: entry.lastCommit,
            branch: entry.branch
        )
    }
}
