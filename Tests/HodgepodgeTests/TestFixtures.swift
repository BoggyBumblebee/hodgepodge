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

extension BrewConfigSnapshot {
    static func fixture(
        values: [String: String] = [
            "HOMEBREW_VERSION": "5.1.7",
            "HOMEBREW_PREFIX": "/opt/homebrew",
            "macOS": "26.4.1-arm64",
            "Xcode": "26.4.1",
            "Branch": "stable",
            "Core tap JSON": "21 Apr 20:33 UTC"
        ],
        rawOutput: String = """
        HOMEBREW_VERSION: 5.1.7
        HOMEBREW_PREFIX: /opt/homebrew
        macOS: 26.4.1-arm64
        Xcode: 26.4.1
        Branch: stable
        Core tap JSON: 21 Apr 20:33 UTC
        """
    ) -> BrewConfigSnapshot {
        BrewConfigSnapshot(values: values, rawOutput: rawOutput)
    }
}

extension BrewDoctorSnapshot {
    static func fixture(
        warningCount: Int = 2,
        warnings: [String] = [
            "The following directories are not writable by your user.",
            "Some installed casks are deprecated or disabled."
        ],
        rawOutput: String = """
        Warning: The following directories are not writable by your user.
        Warning: Some installed casks are deprecated or disabled.
        """
    ) -> BrewDoctorSnapshot {
        BrewDoctorSnapshot(warningCount: warningCount, warnings: warnings, rawOutput: rawOutput)
    }
}

extension BrewMaintenanceDryRunSnapshot {
    static func fixture(
        task: BrewMaintenanceTask = .cleanup,
        itemCount: Int = 1,
        spaceFreedEstimate: String? = "2.3KB",
        warnings: [String] = [],
        items: [String] = ["/Users/cmb/Library/Caches/Homebrew/example.tar.gz"],
        rawOutput: String = """
        Would remove: /Users/cmb/Library/Caches/Homebrew/example.tar.gz
        ==> This operation would free approximately 2.3KB of disk space.
        """
    ) -> BrewMaintenanceDryRunSnapshot {
        BrewMaintenanceDryRunSnapshot(
            task: task,
            itemCount: itemCount,
            spaceFreedEstimate: spaceFreedEstimate,
            warnings: warnings,
            items: items,
            rawOutput: rawOutput
        )
    }
}

extension BrewMaintenanceDashboard {
    static func fixture(
        config: BrewConfigSnapshot = .fixture(),
        doctor: BrewDoctorSnapshot = .fixture(),
        cleanup: BrewMaintenanceDryRunSnapshot = .fixture(task: .cleanup),
        autoremove: BrewMaintenanceDryRunSnapshot = .fixture(
            task: .autoremove,
            itemCount: 0,
            spaceFreedEstimate: nil,
            items: [],
            rawOutput: ""
        ),
        capturedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> BrewMaintenanceDashboard {
        BrewMaintenanceDashboard(
            config: config,
            doctor: doctor,
            cleanup: cleanup,
            autoremove: autoremove,
            capturedAt: capturedAt
        )
    }
}
