import AppKit
import SwiftUI
import XCTest
@testable import Hodgepodge

@MainActor
final class ViewRenderingTests: XCTestCase {
    func testOverviewViewRendersLoadingFailureAndLoadedStates() {
        let model = makeModel()

        model.installationState = .loading
        XCTAssertNotNil(render(OverviewView(model: model)))

        model.installationState = .failed("Broken")
        XCTAssertNotNil(render(OverviewView(model: model)))

        model.installationState = .loaded(.fixture())
        XCTAssertNotNil(render(OverviewView(model: model)))
    }

    func testRootViewRendersAvailableSections() {
        let model = makeModel()
        let catalogModel = makeCatalogModel()
        let installedPackagesModel = makeInstalledPackagesModel()
        let outdatedPackagesModel = makeOutdatedPackagesModel()
        let servicesModel = makeServicesModel()
        let maintenanceModel = makeMaintenanceModel()
        let tapsModel = makeTapsModel()
        let brewfileModel = makeBrewfileModel()

        model.selectedSection = .overview
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .catalog
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .catalogAnalytics
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .installed
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .outdated
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .services
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .taps
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .brewfile
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))

        model.selectedSection = .maintenance
        XCTAssertNotNil(render(
            RootView(
                model: model,
                catalogModel: catalogModel,
                installedPackagesModel: installedPackagesModel,
                outdatedPackagesModel: outdatedPackagesModel,
                servicesModel: servicesModel,
                maintenanceModel: maintenanceModel,
                tapsModel: tapsModel,
                brewfileModel: brewfileModel
            )
        ))
    }

    func testSettingsViewRenders() {
        let model = AppSettingsModel(
            store: PreviewAppSettingsStore(
                snapshot: AppSettingsSnapshot(
                    defaultLaunchSection: .installed,
                    completionNotificationsEnabled: true,
                    notificationSoundEnabled: false,
                    restoreLastSelectedBrewfile: true
                )
            )
        )

        XCTAssertNotNil(render(SettingsView(model: model)))
    }

    func testCommandOutputDisclosureRendersEmptyAndPopulatedStates() {
        XCTAssertNotNil(
            render(
                CommandOutputDisclosure(
                    entries: [],
                    isRunning: true,
                    emptyMessage: "No output yet.",
                    initiallyExpanded: true
                )
            )
        )

        XCTAssertNotNil(
            render(
                CommandOutputDisclosure(
                    entries: [
                        CommandLogEntry(
                            id: 1,
                            kind: .stdout,
                            text: "Downloading...",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
                        )
                    ],
                    isRunning: false,
                    emptyMessage: "No output yet.",
                    initiallyExpanded: true
                )
            )
        )
    }

    func testCommandLogConsoleViewRendersAllLogKinds() {
        XCTAssertNotNil(
            render(
                CommandLogConsoleView(
                    entries: [
                        CommandLogEntry(
                            id: 1,
                            kind: .system,
                            text: "Preparing install",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_000)
                        ),
                        CommandLogEntry(
                            id: 2,
                            kind: .stdout,
                            text: "Downloading...",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_001)
                        ),
                        CommandLogEntry(
                            id: 3,
                            kind: .stderr,
                            text: "Warning...",
                            timestamp: Date(timeIntervalSince1970: 1_700_000_002)
                        )
                    ]
                )
            )
        )
    }

    func testCommandPreviewFieldRenders() {
        XCTAssertNotNil(
            render(
                CommandPreviewField(
                    title: "Install Command",
                    command: "brew install wget",
                    copyAccessibilityLabel: "Copy install command",
                    lineLimit: 1
                )
            )
        )
    }

    func testHomepageLinkIconRenders() {
        XCTAssertNotNil(
            render(
                HomepageLinkIcon(
                    url: URL(string: "https://example.com")!,
                    accessibilityLabel: "Open package homepage"
                )
            )
        )
    }

    func testDownloadLinkIconRenders() {
        XCTAssertNotNil(
            render(
                DownloadLinkIcon(
                    url: URL(string: "https://example.com/archive.tar.gz")!,
                    accessibilityLabel: "Open package download URL"
                )
            )
        )
    }

    func testHodgepodgeCommandsBuildsMenuCommands() {
        let commands = HodgepodgeCommands(model: makeModel())

        _ = commands.body

        XCTAssertTrue(true)
    }

    func testCatalogViewRendersLoadedAndDetailStates() {
        let package = CatalogPackageSummary.fixture(
            homepage: nil,
            hasCaveats: true
        )
        let detail = CatalogPackageDetail(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            aliases: ["wget2"],
            oldNames: ["gnu-wget"],
            description: "Internet file retriever",
            homepage: URL(string: "https://example.com/wget"),
            version: "1.25.0",
            tap: "homebrew/core",
            license: "GPL-3.0-or-later",
            downloadURL: URL(string: "https://example.com/wget.tar.gz"),
            checksum: "abc123",
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: "1.25.0"),
                CatalogDetailMetric(title: "Stable", value: "1.25.0"),
                CatalogDetailMetric(title: "Head", value: "HEAD")
            ],
            dependencies: ["openssl@3"],
            dependencySections: [
                CatalogDetailSection(title: "Runtime Dependencies", items: ["openssl@3"], style: .tags),
                CatalogDetailSection(title: "Build Dependencies", items: ["pkgconf"], style: .tags)
            ],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [
                CatalogDetailSection(title: "Bottle Platforms", items: ["arm64_sonoma", "sonoma"], style: .tags)
            ],
            caveats: "IPv6 support is optional.",
            artifacts: [],
            artifactSections: [],
            analytics: [
                CatalogDetailMetric(title: "Installs (30d)", value: "26,952")
            ]
        )
        let viewModel = makeCatalogModel()
        viewModel.packagesState = .loaded([package])
        viewModel.activeFilters = [.hasCaveats]
        viewModel.sortOption = .tap
        viewModel.favoritePackageIDs = [package.id]
        viewModel.savedSearches = [
            CatalogSavedSearch(
                id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa") ?? UUID(),
                name: "Caveats",
                searchText: "wget",
                scope: .formula,
                activeFilters: [.hasCaveats],
                sortOption: .tap
            )
        ]
        viewModel.analyticsState = .loaded(
            CatalogAnalyticsSnapshot(
                period: .days30,
                leaderboards: [
                    CatalogAnalyticsLeaderboard(
                        kind: .formulaInstalls,
                        period: .days30,
                        startDate: "2026-03-01",
                        endDate: "2026-03-30",
                        totalItems: 10,
                        totalCount: "12,345",
                        items: [
                            CatalogAnalyticsItem(
                                kind: .formula,
                                slug: "wget",
                                rank: 1,
                                count: "1,200",
                                percent: "9.72"
                            )
                        ]
                    ),
                    CatalogAnalyticsLeaderboard(
                        kind: .caskInstalls,
                        period: .days30,
                        startDate: "2026-03-01",
                        endDate: "2026-03-30",
                        totalItems: 8,
                        totalCount: "4,500",
                        items: [
                            CatalogAnalyticsItem(
                                kind: .cask,
                                slug: "docker-desktop",
                                rank: 1,
                                count: "900",
                                percent: "20.00"
                            )
                        ]
                    )
                ]
            )
        )
        viewModel.selectedPackage = package
        viewModel.detailState = .loaded(detail)
        let command = detail.actionCommand(for: .fetch)
        viewModel.actionState = .running(
            CatalogPackageActionProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CatalogPackageActionLogEntry(
                id: 0,
                kind: .system,
                text: "Preparing fetch for wget.",
                timestamp: Date(timeIntervalSince1970: 1_001)
            ),
            CatalogPackageActionLogEntry(
                id: 1,
                kind: .stdout,
                text: "Downloading...",
                timestamp: Date(timeIntervalSince1970: 1_002)
            )
        ]
        viewModel.actionHistory = [
            CatalogPackageActionHistoryEntry(
                id: 0,
                command: command,
                startedAt: Date(timeIntervalSince1970: 900),
                finishedAt: Date(timeIntervalSince1970: 950),
                outcome: .succeeded(0),
                outputLineCount: 4
            )
        ]

        XCTAssertNotNil(
            render(
                CatalogView(
                    viewModel: viewModel,
                    installedPackagesViewModel: makeInstalledPackagesModel()
                )
            )
        )
    }

    func testCatalogViewRendersInstalledPrimaryActionState() {
        let package = CatalogPackageSummary.fixture()
        let detail = CatalogPackageDetail.fixture()
        let viewModel = makeCatalogModel()
        let installedPackagesViewModel = makeInstalledPackagesModel()
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package
        viewModel.detailState = .loaded(detail)
        installedPackagesViewModel.packagesState = .loaded([
            InstalledPackage(
                kind: .formula,
                slug: package.slug,
                title: package.title,
                fullName: "homebrew/core/\(package.slug)",
                subtitle: package.subtitle,
                version: package.version,
                homepage: package.homepage,
                tap: package.tap,
                installedVersions: [package.version],
                installedAt: Date(timeIntervalSince1970: 1_700_000_000),
                linkedVersion: package.version,
                isPinned: false,
                isLinked: true,
                isLeaf: true,
                isOutdated: false,
                isInstalledOnRequest: true,
                isInstalledAsDependency: false,
                autoUpdates: false,
                isDeprecated: false,
                isDisabled: false,
                directDependencies: [],
                buildDependencies: [],
                testDependencies: [],
                recommendedDependencies: [],
                optionalDependencies: [],
                requirements: [],
                directRuntimeDependencies: [],
                runtimeDependencies: []
            )
        ])

        XCTAssertNotNil(
            render(
                CatalogView(
                    viewModel: viewModel,
                    installedPackagesViewModel: installedPackagesViewModel
                )
            )
        )
    }

    func testCatalogAnalyticsViewRendersLoadedState() {
        let package = CatalogPackageSummary.fixture()
        let viewModel = makeCatalogModel()
        let installedPackagesViewModel = makeInstalledPackagesModel()
        viewModel.packagesState = .loaded([package])
        installedPackagesViewModel.packagesState = .loaded([
            InstalledPackage(
                kind: .formula,
                slug: package.slug,
                title: package.title,
                fullName: package.slug,
                subtitle: package.subtitle,
                version: package.version,
                homepage: package.homepage,
                tap: package.tap,
                installedVersions: [package.version],
                installedAt: Date(timeIntervalSince1970: 1_700_000_000),
                linkedVersion: package.version,
                isPinned: false,
                isLinked: true,
                isLeaf: true,
                isOutdated: false,
                isInstalledOnRequest: true,
                isInstalledAsDependency: false,
                autoUpdates: false,
                isDeprecated: false,
                isDisabled: false,
                directDependencies: [],
                buildDependencies: [],
                testDependencies: [],
                recommendedDependencies: [],
                optionalDependencies: [],
                requirements: [],
                directRuntimeDependencies: [],
                runtimeDependencies: []
            )
        ])
        viewModel.analyticsState = .loaded(
            CatalogAnalyticsSnapshot(
                period: .days30,
                leaderboards: [
                    CatalogAnalyticsLeaderboard(
                        kind: .formulaInstalls,
                        period: .days30,
                        startDate: "2026-03-01",
                        endDate: "2026-03-30",
                        totalItems: 10,
                        totalCount: "12,345",
                        items: [
                            CatalogAnalyticsItem(
                                kind: .formula,
                                slug: package.slug,
                                rank: 1,
                                count: "1,200",
                                percent: "9.72"
                            )
                        ]
                    )
                ]
            )
        )

        XCTAssertNotNil(
            render(
                CatalogAnalyticsView(
                    viewModel: viewModel,
                    installedPackagesViewModel: installedPackagesViewModel,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )
    }

    func testCatalogAnalyticsViewRendersLoadingAndFailureStates() {
        let viewModel = makeCatalogModel()
        let installedPackagesViewModel = makeInstalledPackagesModel()

        viewModel.analyticsState = .loading(.days30)
        XCTAssertNotNil(
            render(
                CatalogAnalyticsView(
                    viewModel: viewModel,
                    installedPackagesViewModel: installedPackagesViewModel,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )

        viewModel.analyticsState = .failed(.days30, "Broken")
        XCTAssertNotNil(
            render(
                CatalogAnalyticsView(
                    viewModel: viewModel,
                    installedPackagesViewModel: installedPackagesViewModel,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )
    }

    func testCatalogAnalyticsLeaderboardCardRendersEmptyAndPopulatedStates() {
        let installedPackagesViewModel = makeInstalledPackagesModel()
        let emptyLeaderboard = CatalogAnalyticsLeaderboard(
            kind: .formulaInstalls,
            period: .days30,
            startDate: "2026-03-01",
            endDate: "2026-03-30",
            totalItems: 0,
            totalCount: "0",
            items: []
        )
        let populatedLeaderboard = CatalogAnalyticsLeaderboard(
            kind: .formulaInstalls,
            period: .days30,
            startDate: "2026-03-01",
            endDate: "2026-03-30",
            totalItems: 10,
            totalCount: "12,345",
            items: [
                CatalogAnalyticsItem(
                    kind: .formula,
                    slug: "wget",
                    rank: 1,
                    count: "1,200",
                    percent: "9.72"
                )
            ]
        )

        XCTAssertNotNil(
            render(
                CatalogAnalyticsLeaderboardCard(
                    leaderboard: emptyLeaderboard,
                    installedPackagesViewModel: installedPackagesViewModel,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )

        XCTAssertNotNil(
            render(
                CatalogAnalyticsLeaderboardCard(
                    leaderboard: populatedLeaderboard,
                    installedPackagesViewModel: installedPackagesViewModel,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )
    }

    func testCatalogAnalyticsItemRowRendersInstalledAndUninstalledStates() {
        let item = CatalogAnalyticsItem(
            kind: .formula,
            slug: "wget",
            rank: 1,
            count: "1,200",
            percent: "9.72"
        )

        XCTAssertNotNil(
            render(
                CatalogAnalyticsItemRow(
                    item: item,
                    isInstalled: true,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )

        XCTAssertNotNil(
            render(
                CatalogAnalyticsItemRow(
                    item: item,
                    isInstalled: false,
                    openInstalledPackage: { _ in },
                    openPackageInCatalog: { _ in }
                )
            )
        )
    }

    func testInstalledPackagesViewRendersLoadedState() {
        let package = InstalledPackage(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            subtitle: "Internet file retriever",
            version: "1.25.0",
            homepage: URL(string: "https://example.com/wget"),
            tap: "homebrew/core",
            installedVersions: ["1.25.0"],
            installedAt: Date(timeIntervalSince1970: 1_700_000_000),
            linkedVersion: "1.25.0",
            isPinned: true,
            isLinked: true,
            isLeaf: true,
            isOutdated: false,
            isInstalledOnRequest: true,
            isInstalledAsDependency: false,
            autoUpdates: false,
            isDeprecated: false,
            isDisabled: false,
            directDependencies: ["openssl@3"],
            buildDependencies: ["pkgconf"],
            testDependencies: [],
            recommendedDependencies: [],
            optionalDependencies: [],
            requirements: ["xcode 15.3 (build)"],
            directRuntimeDependencies: ["openssl@3"],
            runtimeDependencies: ["openssl@3"]
        )
        let viewModel = makeInstalledPackagesModel()
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package
        viewModel.favoritePackageIDs = [package.id]
        let exportCommand = InstalledPackagesBrewfileExportCommand(
            scope: .formula,
            destinationURL: URL(fileURLWithPath: "/tmp/Brewfile-formulae")
        )
        viewModel.exportState = .running(
            InstalledPackagesBrewfileExportProgress(
                command: exportCommand,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.exportLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Dumping Brewfile...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]
        viewModel.actionState = .running(
            InstalledPackageActionProgress(
                command: package.actionCommand(for: .unpin),
                startedAt: Date(timeIntervalSince1970: 1_010)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Pinning wget...",
                timestamp: Date(timeIntervalSince1970: 1_011)
            )
        ]

        XCTAssertNotNil(render(InstalledPackagesView(viewModel: viewModel)))
    }

    func testOutdatedPackagesViewRendersLoadedState() {
        let package = OutdatedPackage(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            installedVersions: ["1.24.5"],
            currentVersion: "1.25.0",
            isPinned: true,
            pinnedVersion: "1.24.5"
        )
        let viewModel = makeOutdatedPackagesModel()
        viewModel.packagesState = .loaded([package])
        viewModel.selectedPackage = package
        viewModel.actionState = .running(
            OutdatedPackageActionProgress(
                command: package.actionCommand(for: .upgrade),
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Pouring...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(OutdatedPackagesView(viewModel: viewModel)))
    }

    func testOutdatedPackagesViewRendersBulkUpgradeState() {
        let first = OutdatedPackage(
            kind: .formula,
            slug: "wget",
            title: "wget",
            fullName: "homebrew/core/wget",
            installedVersions: ["1.24.5"],
            currentVersion: "1.25.0",
            isPinned: false,
            pinnedVersion: nil
        )
        let second = OutdatedPackage(
            kind: .cask,
            slug: "docker-desktop",
            title: "Docker Desktop",
            fullName: "homebrew/cask/docker-desktop",
            installedVersions: ["4.67.0"],
            currentVersion: "4.68.0",
            isPinned: false,
            pinnedVersion: nil
        )
        let viewModel = makeOutdatedPackagesModel()
        viewModel.packagesState = .loaded([first, second])
        viewModel.selectedPackage = first
        let command = OutdatedPackageActionCommand.upgradeAll(packages: [first, second])!
        viewModel.actionState = .running(
            OutdatedPackageActionProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Upgrading visible packages...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(OutdatedPackagesView(viewModel: viewModel)))
    }

    func testServicesViewRendersLoadedState() {
        let service = BrewService.fixture()
        let viewModel = makeServicesModel()
        viewModel.servicesState = .loaded([service])
        viewModel.selectedService = service
        viewModel.actionState = .running(
            BrewServiceActionProgress(
                command: service.command(for: .restart),
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Restarting...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]
        viewModel.clearActionOutput()
        viewModel.actionState = .running(
            BrewServiceActionProgress(
                command: .cleanupAll(),
                startedAt: Date(timeIntervalSince1970: 1_010)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Cleaning up unused services...",
                timestamp: Date(timeIntervalSince1970: 1_011)
            )
        ]

        XCTAssertNotNil(render(ServicesView(viewModel: viewModel)))
    }

    func testServicesViewRendersIdleLoadedStateWithoutActionOutput() {
        let service = BrewService.fixture(
            status: "none",
            isRunning: false,
            isLoaded: false,
            pid: nil,
            command: nil
        )
        let viewModel = makeServicesModel()
        viewModel.servicesState = .loaded([service])
        viewModel.selectedService = service
        viewModel.actionState = .idle
        viewModel.actionLogs = []

        XCTAssertNotNil(render(ServicesView(viewModel: viewModel)))
    }

    func testServicesViewRendersSucceededActionState() {
        let service = BrewService.fixture()
        let viewModel = makeServicesModel()
        viewModel.servicesState = .loaded([service])
        viewModel.selectedService = service
        let progress = BrewServiceActionProgress(
            command: service.command(for: .restart),
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        viewModel.actionState = .succeeded(
            progress,
            CommandResult(
                stdout: "Restarted successfully.",
                stderr: "",
                exitCode: 0
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Restarted successfully.",
                timestamp: Date(timeIntervalSince1970: 1_006)
            )
        ]

        XCTAssertNotNil(render(ServicesView(viewModel: viewModel)))
    }

    func testMaintenanceViewRendersLoadedState() {
        let viewModel = makeMaintenanceModel()
        viewModel.dashboardState = .loaded(.fixture())
        viewModel.selectedOutputSource = .liveAction
        viewModel.actionState = .running(
            BrewMaintenanceActionProgress(
                command: BrewMaintenanceActionCommand(task: .cleanup, arguments: ["cleanup"]),
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Removing...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(MaintenanceView(viewModel: viewModel)))
    }

    func testTapsViewRendersLoadedState() {
        let tap = BrewTap.fixture(
            name: "timescale/tap",
            remote: "https://github.com/timescale/homebrew-tap",
            customRemote: true,
            isPrivate: false,
            lastCommit: "2 hours ago",
            branch: "main"
        )
        let viewModel = makeTapsModel()
        viewModel.tapsState = .loaded([tap])
        viewModel.selectedTap = tap
        viewModel.addTapName = "timescale/tap"
        viewModel.actionState = .running(
            BrewTapActionProgress(
                command: .add(name: tap.name, remoteURL: tap.remote),
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Cloning...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(TapsView(viewModel: viewModel)))
    }

    func testBrewfileViewRendersLoadedState() {
        let document = BrewfileDocument.fixture()
        let viewModel = makeBrewfileModel()
        viewModel.documentState = .loaded(document)
        viewModel.selectedFileURL = document.fileURL
        viewModel.selectedLine = document.lines.first
        let command = BrewfileActionCommand(kind: .check, fileURL: document.fileURL)
        viewModel.actionState = .running(
            BrewfileActionProgress(
                command: command,
                startedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .system,
                text: "Preparing bundle check.",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))
    }

    func testBrewfileViewRendersIdleLoadingAndFailureStates() {
        let viewModel = makeBrewfileModel()

        viewModel.documentState = .idle
        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))

        viewModel.documentState = .loading
        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))

        viewModel.documentState = .failed("Broken")
        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))
    }

    func testBrewfileViewRendersActionDetailsWhenLogsExist() {
        let document = BrewfileDocument.fixture()
        let viewModel = makeBrewfileModel()
        viewModel.documentState = .loaded(document)
        viewModel.selectedFileURL = document.fileURL
        viewModel.selectedLine = document.lines.first
        viewModel.actionState = .succeeded(
            BrewfileActionProgress(
                command: BrewfileActionCommand(kind: .install, fileURL: document.fileURL),
                startedAt: Date(timeIntervalSince1970: 1_000),
                finishedAt: Date(timeIntervalSince1970: 1_030)
            ),
            CommandResult(stdout: "Installed\n", stderr: "", exitCode: 0)
        )
        viewModel.actionLogs = [
            CommandLogEntry(
                id: 0,
                kind: .stdout,
                text: "Installing wget...",
                timestamp: Date(timeIntervalSince1970: 1_001)
            )
        ]

        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))
    }

    func testBrewfileViewRendersLoadedOverviewWhenNoLineIsSelected() {
        let document = BrewfileDocument.fixture()
        let viewModel = makeBrewfileModel()
        viewModel.documentState = .loaded(document)
        viewModel.selectedFileURL = document.fileURL
        viewModel.selectedLine = nil
        viewModel.actionState = .failed(
            BrewfileActionProgress(
                command: BrewfileActionCommand(kind: .install, fileURL: document.fileURL),
                startedAt: Date(timeIntervalSince1970: 1_000),
                finishedAt: Date(timeIntervalSince1970: 1_020)
            ),
            "No matching line"
        )
        viewModel.actionLogs = []

        XCTAssertNotNil(render(BrewfileView(viewModel: viewModel)))
    }

    private func makeModel() -> AppModel {
        AppModel(
            brewLocator: ViewTestBrewLocator(),
            helpResolver: ViewTestHelpResolver(),
            urlOpener: ViewTestURLOpener(),
            aboutPanelPresenter: ViewTestAboutPanelPresenter()
        )
    }

    private func makeCatalogModel() -> CatalogViewModel {
        CatalogViewModel(
            apiClient: ViewTestCatalogAPIClient(),
            commandExecutor: ViewTestBrewCommandExecutor(),
            actionHistoryStore: ViewTestCatalogActionHistoryStore(),
            actionHistoryExporter: ViewTestCatalogActionHistoryExporter(),
            preferencesStore: ViewTestCatalogPreferencesStore()
        )
    }

    private func makeInstalledPackagesModel() -> InstalledPackagesViewModel {
        InstalledPackagesViewModel(
            provider: ViewTestInstalledPackagesProvider(),
            commandExecutor: ViewTestInstalledPackagesCommandExecutor(),
            destinationPicker: ViewTestBrewfileDumpDestinationPicker()
        )
    }

    private func makeOutdatedPackagesModel() -> OutdatedPackagesViewModel {
        OutdatedPackagesViewModel(
            provider: ViewTestOutdatedPackagesProvider(),
            commandExecutor: ViewTestOutdatedCommandExecutor()
        )
    }

    private func makeServicesModel() -> ServicesViewModel {
        ServicesViewModel(
            provider: ViewTestBrewServicesProvider(),
            commandExecutor: ViewTestServicesCommandExecutor()
        )
    }

    private func makeMaintenanceModel() -> MaintenanceViewModel {
        MaintenanceViewModel(
            provider: ViewTestBrewMaintenanceProvider(),
            commandExecutor: ViewTestMaintenanceCommandExecutor()
        )
    }

    private func makeTapsModel() -> TapsViewModel {
        TapsViewModel(
            provider: ViewTestBrewTapsProvider(),
            commandExecutor: ViewTestTapsCommandExecutor()
        )
    }

    private func makeBrewfileModel() -> BrewfileViewModel {
        BrewfileViewModel(
            dependencies: .init(
                loader: ViewTestBrewfileLoader(),
                selectionStore: ViewTestBrewfileSelectionStore(),
                picker: ViewTestBrewfilePicker(),
                dumpDestinationPicker: ViewTestBrewfileDumpDestinationPicker(),
                commandExecutor: ViewTestBrewfileCommandExecutor()
            )
        )
    }

    private func render<Content: View>(_ view: Content) -> NSHostingView<Content> {
        let hostingView = NSHostingView(rootView: view)
        hostingView.layoutSubtreeIfNeeded()
        _ = hostingView.fittingSize
        return hostingView
    }
}

private struct PreviewAppSettingsStore: AppSettingsStoring {
    let snapshot: AppSettingsSnapshot

    func loadSettings() -> AppSettingsSnapshot {
        snapshot
    }

    func saveSettings(_ snapshot: AppSettingsSnapshot) {}
}

private struct ViewTestBrewLocator: BrewLocating {
    func locate() async throws -> HomebrewInstallation {
        .fixture()
    }
}

private struct ViewTestHelpResolver: HelpDocumentResolving {
    func helpURL(anchor: HelpAnchor) throws -> URL {
        URL(fileURLWithPath: "/Bundle/Help/index.html")
    }
}

private struct ViewTestURLOpener: URLOpening {
    func open(_ url: URL) -> Bool {
        true
    }
}

private struct ViewTestAboutPanelPresenter: AboutPanelPresenting {
    func presentAboutPanel() {}
}

private struct ViewTestCatalogAPIClient: HomebrewAPIClienting, Sendable {
    func fetchCatalog() async throws -> [CatalogPackageSummary] {
        []
    }

    func fetchDetail(for package: CatalogPackageSummary) async throws -> CatalogPackageDetail {
        CatalogPackageDetail(
            kind: package.kind,
            slug: package.slug,
            title: package.title,
            fullName: package.slug,
            aliases: [],
            oldNames: [],
            description: package.subtitle,
            homepage: package.homepage,
            version: package.version,
            tap: "homebrew/core",
            license: nil,
            downloadURL: nil,
            checksum: nil,
            autoUpdates: nil,
            versionDetails: [
                CatalogDetailMetric(title: "Current", value: package.version)
            ],
            dependencies: [],
            dependencySections: [],
            conflicts: [],
            lifecycleSections: [],
            platformSections: [],
            caveats: nil,
            artifacts: [],
            artifactSections: [],
            analytics: []
        )
    }

    func fetchAnalytics(period: CatalogAnalyticsPeriod) async throws -> CatalogAnalyticsSnapshot {
        .empty(for: period)
    }
}

private struct ViewTestBrewCommandExecutor: BrewCommandExecuting, Sendable {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "$ /opt/homebrew/bin/brew \(arguments.joined(separator: " "))")
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestCatalogActionHistoryStore: CatalogActionHistoryStoring {
    func loadHistory() -> [CatalogPackageActionHistoryEntry] {
        []
    }

    func saveHistory(_ entries: [CatalogPackageActionHistoryEntry]) {}
}

private struct ViewTestCatalogPreferencesStore: CatalogPreferencesStoring {
    func loadPreferences() -> CatalogPreferencesSnapshot {
        .empty
    }

    func savePreferences(_ snapshot: CatalogPreferencesSnapshot) {}

    func loadFavoritePackageIDs() -> [String] {
        []
    }

    func saveFavoritePackageIDs(_ ids: [String]) {}
}

@MainActor
private struct ViewTestCatalogActionHistoryExporter: CatalogActionHistoryExporting {
    func export(
        entries: [CatalogPackageActionHistoryEntry],
        suggestedFileName: String
    ) throws {}
}

private struct ViewTestInstalledPackagesProvider: InstalledPackagesProviding {
    func fetchInstalledPackages() async throws -> [InstalledPackage] {
        []
    }
}

private struct ViewTestOutdatedPackagesProvider: OutdatedPackagesProviding {
    func fetchOutdatedPackages() async throws -> [OutdatedPackage] {
        []
    }
}

private struct ViewTestOutdatedCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestBrewServicesProvider: BrewServicesProviding {
    func fetchServices() async throws -> [BrewService] {
        []
    }
}

private struct ViewTestServicesCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestBrewMaintenanceProvider: BrewMaintenanceProviding {
    func fetchDashboard() async throws -> BrewMaintenanceDashboard {
        .fixture()
    }
}

private struct ViewTestMaintenanceCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestBrewTapsProvider: BrewTapsProviding {
    func fetchTaps() async throws -> [BrewTap] {
        []
    }
}

private struct ViewTestTapsCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestBrewfileLoader: BrewfileDocumentLoading {
    func loadDocument(at fileURL: URL) throws -> BrewfileDocument {
        .fixture(fileURL: fileURL)
    }
}

private struct ViewTestBrewfileSelectionStore: BrewfileSelectionStoring {
    func loadSelection() -> URL? {
        nil
    }

    func saveSelection(_ url: URL?) {}
}

private struct ViewTestBrewfilePicker: BrewfilePicking {
    @MainActor
    func pickBrewfile(startingDirectory: URL?) -> URL? {
        nil
    }
}

private struct ViewTestBrewfileCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

private struct ViewTestInstalledPackagesCommandExecutor: BrewCommandExecuting {
    func execute(
        arguments: [String],
        onLog: @escaping @MainActor @Sendable (CatalogPackageActionLogKind, String) -> Void
    ) async throws -> CommandResult {
        await onLog(.system, "Using Homebrew at /opt/homebrew/bin/brew")
        return CommandResult(stdout: "", stderr: "", exitCode: 0)
    }
}

@MainActor
private struct ViewTestBrewfileDumpDestinationPicker: BrewfileDumpDestinationPicking {
    func chooseDestination(
        suggestedFileName: String,
        startingDirectory: URL?
    ) -> URL? {
        nil
    }
}
