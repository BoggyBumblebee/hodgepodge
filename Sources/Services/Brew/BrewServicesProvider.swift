import Foundation

protocol BrewServicesProviding: Sendable {
    func fetchServices() async throws -> [BrewService]
}

struct BrewServicesProvider: BrewServicesProviding, @unchecked Sendable {
    private let brewLocator: any BrewLocating
    private let runner: any CommandRunning
    private let decoder = JSONDecoder()

    init(
        brewLocator: any BrewLocating,
        runner: any CommandRunning
    ) {
        self.brewLocator = brewLocator
        self.runner = runner
    }

    func fetchServices() async throws -> [BrewService] {
        let installation = try await brewLocator.locate()
        try installation.compatibility.validateServicesJSONSupport()
        let listResult = try await runner.run(
            executable: installation.brewPath,
            arguments: ["services", "list", "--json"]
        )
        let infoResult = try await runner.run(
            executable: installation.brewPath,
            arguments: ["services", "info", "--all", "--json"]
        )

        let listEntries = try decode([ListEntry].self, from: listResult.stdout)
        let infoEntries = try decode([InfoEntry].self, from: infoResult.stdout)

        return mergeServices(listEntries: listEntries, infoEntries: infoEntries)
    }

    private func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        let data = Data(string.utf8)
        return try decoder.decode(type, from: data)
    }

    private func mergeServices(
        listEntries: [ListEntry],
        infoEntries: [InfoEntry]
    ) -> [BrewService] {
        let listByName = Dictionary(uniqueKeysWithValues: listEntries.map { ($0.name, $0) })
        let infoByName = Dictionary(uniqueKeysWithValues: infoEntries.map { ($0.name, $0) })
        let names = Set(listByName.keys).union(infoByName.keys).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        return names.compactMap { name in
            let listEntry = listByName[name]
            let infoEntry = infoByName[name]
            guard listEntry != nil || infoEntry != nil else {
                return nil
            }

            return BrewService(
                name: name,
                serviceName: infoEntry?.serviceName ?? "homebrew.mxcl.\(name)",
                status: infoEntry?.status ?? listEntry?.status ?? "unknown",
                isRunning: infoEntry?.running ?? false,
                isLoaded: infoEntry?.loaded ?? false,
                isSchedulable: infoEntry?.schedulable ?? false,
                pid: infoEntry?.pid,
                exitCode: infoEntry?.exitCode ?? listEntry?.exitCode,
                user: infoEntry?.user ?? listEntry?.user,
                file: infoEntry?.file ?? listEntry?.file,
                isRegistered: infoEntry?.registered ?? false,
                loadedFile: infoEntry?.loadedFile,
                command: infoEntry?.command,
                workingDirectory: infoEntry?.workingDirectory,
                rootDirectory: infoEntry?.rootDirectory,
                logPath: infoEntry?.logPath,
                errorLogPath: infoEntry?.errorLogPath,
                interval: infoEntry?.interval,
                cron: infoEntry?.cron
            )
        }
    }
}

private struct ListEntry: Decodable {
    let name: String
    let status: String?
    let user: String?
    let file: String?
    let exitCode: Int?

    private enum CodingKeys: String, CodingKey {
        case name
        case status
        case user
        case file
        case exitCode = "exit_code"
    }
}

private struct InfoEntry: Decodable {
    let name: String
    let serviceName: String?
    let running: Bool?
    let loaded: Bool?
    let schedulable: Bool?
    let pid: Int?
    let exitCode: Int?
    let user: String?
    let status: String?
    let file: String?
    let registered: Bool?
    let loadedFile: String?
    let command: String?
    let workingDirectory: String?
    let rootDirectory: String?
    let logPath: String?
    let errorLogPath: String?
    let interval: String?
    let cron: String?

    private enum CodingKeys: String, CodingKey {
        case name
        case serviceName = "service_name"
        case running
        case loaded
        case schedulable
        case pid
        case exitCode = "exit_code"
        case user
        case status
        case file
        case registered
        case loadedFile = "loaded_file"
        case command
        case workingDirectory = "working_dir"
        case rootDirectory = "root_dir"
        case logPath = "log_path"
        case errorLogPath = "error_log_path"
        case interval
        case cron
    }
}
