import Foundation
@testable import Hodgepodge

extension HomebrewInstallation {
    static func fixture(version: String = "5.1.7") -> HomebrewInstallation {
        HomebrewInstallation(
            brewPath: "/opt/homebrew/bin/brew",
            version: version,
            prefix: "/opt/homebrew",
            cellar: "/opt/homebrew/Cellar",
            repository: "/opt/homebrew/Homebrew",
            taps: ["homebrew/core"],
            detectedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}

extension CatalogPackageSummary {
    static func fixture(
        kind: CatalogPackageKind = .formula,
        slug: String = "wget",
        title: String = "wget",
        subtitle: String = "Internet file retriever",
        version: String = "1.25.0",
        homepage: URL? = URL(string: "https://example.com/wget"),
        tap: String = "homebrew/core",
        hasCaveats: Bool = false,
        isDeprecated: Bool = false,
        isDisabled: Bool = false,
        autoUpdates: Bool = false
    ) -> CatalogPackageSummary {
        CatalogPackageSummary(
            kind: kind,
            slug: slug,
            title: title,
            subtitle: subtitle,
            version: version,
            homepage: homepage,
            tap: tap,
            hasCaveats: hasCaveats,
            isDeprecated: isDeprecated,
            isDisabled: isDisabled,
            autoUpdates: autoUpdates
        )
    }
}

extension CatalogPackageDetail {
    static func fixture(
        kind: CatalogPackageKind = .formula,
        slug: String = "wget",
        title: String = "wget",
        fullName: String? = nil,
        aliases: [String] = [],
        oldNames: [String] = [],
        description: String = "Internet file retriever",
        homepage: URL? = URL(string: "https://example.com/wget"),
        version: String = "1.25.0",
        tap: String = "homebrew/core",
        license: String? = "GPL-3.0-or-later",
        downloadURL: URL? = nil,
        checksum: String? = nil,
        autoUpdates: Bool? = nil,
        versionDetails: [CatalogDetailMetric] = [
            CatalogDetailMetric(title: "Current", value: "1.25.0"),
            CatalogDetailMetric(title: "Stable", value: "1.25.0")
        ],
        dependencies: [String] = [],
        dependencySections: [CatalogDetailSection] = [],
        conflicts: [String] = [],
        lifecycleSections: [CatalogDetailSection] = [],
        platformSections: [CatalogDetailSection] = [],
        caveats: String? = nil,
        artifacts: [String] = [],
        artifactSections: [CatalogDetailSection] = [],
        analytics: [CatalogDetailMetric] = []
    ) -> CatalogPackageDetail {
        CatalogPackageDetail(
            kind: kind,
            slug: slug,
            title: title,
            fullName: fullName ?? title,
            aliases: aliases,
            oldNames: oldNames,
            description: description,
            homepage: homepage,
            version: version,
            tap: tap,
            license: license,
            downloadURL: downloadURL,
            checksum: checksum,
            autoUpdates: autoUpdates,
            versionDetails: versionDetails,
            dependencies: dependencies,
            dependencySections: dependencySections,
            conflicts: conflicts,
            lifecycleSections: lifecycleSections,
            platformSections: platformSections,
            caveats: caveats,
            artifacts: artifacts,
            artifactSections: artifactSections,
            analytics: analytics
        )
    }
}

extension OutdatedPackage {
    static func fixture(
        kind: CatalogPackageKind = .formula,
        slug: String = "wget",
        title: String = "wget",
        fullName: String? = nil,
        installedVersions: [String] = ["1.24.5"],
        currentVersion: String = "1.25.0",
        isPinned: Bool = false,
        pinnedVersion: String? = nil
    ) -> OutdatedPackage {
        OutdatedPackage(
            kind: kind,
            slug: slug,
            title: title,
            fullName: fullName ?? slug,
            installedVersions: installedVersions,
            currentVersion: currentVersion,
            isPinned: isPinned,
            pinnedVersion: pinnedVersion
        )
    }
}

extension BrewService {
    static func fixture(
        name: String = "postgresql@17",
        serviceName: String = "homebrew.mxcl.postgresql@17",
        status: String = "started",
        isRunning: Bool = true,
        isLoaded: Bool = true,
        isSchedulable: Bool = false,
        pid: Int? = 2043,
        exitCode: Int? = nil,
        user: String? = "cmb",
        file: String? = "/Users/cmb/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist",
        isRegistered: Bool = true,
        loadedFile: String? = "/Users/cmb/Library/LaunchAgents/homebrew.mxcl.postgresql@17.plist",
        command: String? = "/opt/homebrew/opt/postgresql@17/bin/postgres -D /opt/homebrew/var/postgresql@17",
        workingDirectory: String? = "/opt/homebrew",
        rootDirectory: String? = nil,
        logPath: String? = "/opt/homebrew/var/log/postgresql@17.log",
        errorLogPath: String? = "/opt/homebrew/var/log/postgresql@17.log",
        interval: String? = nil,
        cron: String? = nil
    ) -> BrewService {
        BrewService(
            name: name,
            serviceName: serviceName,
            status: status,
            isRunning: isRunning,
            isLoaded: isLoaded,
            isSchedulable: isSchedulable,
            pid: pid,
            exitCode: exitCode,
            user: user,
            file: file,
            isRegistered: isRegistered,
            loadedFile: loadedFile,
            command: command,
            workingDirectory: workingDirectory,
            rootDirectory: rootDirectory,
            logPath: logPath,
            errorLogPath: errorLogPath,
            interval: interval,
            cron: cron
        )
    }
}
