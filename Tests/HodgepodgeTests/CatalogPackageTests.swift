import Foundation
import XCTest
@testable import Hodgepodge

final class CatalogPackageTests: XCTestCase {
    func testPackageSummaryAndDetailCommandsReflectKind() {
        let formula = CatalogPackageSummary.fixture(kind: .formula, slug: "wget")
        let cask = CatalogPackageSummary.fixture(kind: .cask, slug: "docker-desktop")

        XCTAssertEqual(formula.installCommand, "brew install wget")
        XCTAssertEqual(cask.installCommand, "brew install --cask docker-desktop")

        let detail = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop")
        XCTAssertEqual(detail.installCommand, "brew install --cask docker-desktop")
        XCTAssertEqual(detail.fetchCommand, "brew fetch --cask docker-desktop")
    }

    func testActionCommandsReflectActionKindAndPackageKind() {
        let formulaDetail = CatalogPackageDetail.fixture()
        let caskDetail = CatalogPackageDetail.fixture(kind: .cask, slug: "docker-desktop", title: "Docker Desktop")

        XCTAssertEqual(CatalogPackageActionKind.install.title, "Install")
        XCTAssertEqual(CatalogPackageActionKind.fetch.title, "Fetch")
        XCTAssertTrue(CatalogPackageActionKind.install.requiresConfirmation)
        XCTAssertFalse(CatalogPackageActionKind.fetch.requiresConfirmation)

        XCTAssertEqual(
            formulaDetail.actionCommand(for: .fetch),
            CatalogPackageActionCommand(
                kind: .fetch,
                packageID: "formula:wget",
                packageTitle: "wget",
                command: "brew fetch wget",
                arguments: ["fetch", "wget"]
            )
        )
        XCTAssertEqual(
            caskDetail.actionCommand(for: .install),
            CatalogPackageActionCommand(
                kind: .install,
                packageID: "cask:docker-desktop",
                packageTitle: "Docker Desktop",
                command: "brew install --cask docker-desktop",
                arguments: ["install", "--cask", "docker-desktop"]
            )
        )
        XCTAssertEqual(caskDetail.packageID, "cask:docker-desktop")
    }

    func testActionProgressTracksCommandAndElapsedTime() {
        let command = CatalogPackageDetail.fixture().actionCommand(for: .fetch)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let finishedAt = Date(timeIntervalSince1970: 1_095)
        let progress = CatalogPackageActionProgress(command: command, startedAt: startedAt)
        let completed = progress.finished(at: finishedAt)

        XCTAssertEqual(progress.command, command)
        XCTAssertNil(progress.finishedAt)
        XCTAssertEqual(progress.elapsedTime(at: finishedAt), 95, accuracy: 0.001)
        XCTAssertEqual(completed.finishedAt, finishedAt)
        XCTAssertEqual(completed.elapsedTime(at: Date(timeIntervalSince1970: 1_200)), 95, accuracy: 0.001)
        XCTAssertEqual(CatalogPackageActionState.running(progress).command, command)
        XCTAssertEqual(CatalogPackageActionState.succeeded(completed, CommandResult(stdout: "", stderr: "", exitCode: 0)).progress, completed)
    }

    func testActionHistoryOutcomeAndDurationAreStable() {
        let command = CatalogPackageDetail.fixture().actionCommand(for: .install)
        let entry = CatalogPackageActionHistoryEntry(
            id: 7,
            command: command,
            startedAt: Date(timeIntervalSince1970: 1_000),
            finishedAt: Date(timeIntervalSince1970: 1_135),
            outcome: .failed("Already installed"),
            outputLineCount: 4
        )

        XCTAssertEqual(CatalogPackageActionHistoryOutcome.succeeded(0).title, "Completed")
        XCTAssertEqual(CatalogPackageActionHistoryOutcome.succeeded(0).detail, "Completed successfully")
        XCTAssertEqual(CatalogPackageActionHistoryOutcome.cancelled.title, "Cancelled")
        XCTAssertEqual(CatalogPackageActionHistoryOutcome.cancelled.detail, "Stopped before completion")
        XCTAssertEqual(entry.duration, 135, accuracy: 0.001)
        XCTAssertEqual(entry.outcome.title, "Failed")
        XCTAssertEqual(entry.outcome.detail, "Already installed")
        XCTAssertEqual(
            CatalogPackageActionHistoryOutcome.failed("The command failed with exit code 1.").detail,
            "Homebrew couldn't complete this action."
        )
    }

    func testMetadataDetailsIncludeOptionalValuesWhenPresent() {
        let detail = CatalogPackageDetail.fixture(
            fullName: "homebrew/cask/docker-desktop",
            license: nil,
            checksum: "feedface",
            autoUpdates: true
        )

        XCTAssertEqual(
            detail.metadataDetails,
            [
                CatalogDetailMetric(title: "Full Name", value: "homebrew/cask/docker-desktop"),
                CatalogDetailMetric(title: "Slug", value: "wget"),
                CatalogDetailMetric(title: "Tap", value: "homebrew/core"),
                CatalogDetailMetric(title: "License", value: "Not specified"),
                CatalogDetailMetric(title: "Checksum", value: "feedface"),
                CatalogDetailMetric(title: "Auto Updates", value: "Yes")
            ]
        )
    }

    func testFilterAndSortTitlesAreStable() {
        XCTAssertEqual(CatalogFilterOption.hasCaveats.title, "Has Caveats")
        XCTAssertEqual(CatalogFilterOption.deprecated.title, "Deprecated")
        XCTAssertEqual(CatalogFilterOption.disabled.title, "Disabled")
        XCTAssertEqual(CatalogFilterOption.autoUpdates.title, "Auto Updates")
        XCTAssertEqual(CatalogSortOption.name.title, "Name")
        XCTAssertEqual(CatalogSortOption.packageType.title, "Package Type")
        XCTAssertEqual(CatalogSortOption.version.title, "Version")
        XCTAssertEqual(CatalogSortOption.tap.title, "Tap")
        XCTAssertEqual(CatalogPackageKind.formula.title, "Formulae")
        XCTAssertEqual(CatalogPackageKind.formula.installCommandFlag, "")
        XCTAssertEqual(CatalogPackageKind.cask.title, "Casks")
        XCTAssertEqual(CatalogPackageKind.cask.installCommandFlag, "--cask ")
    }

    func testScopeFilteringIncludesExpectedKinds() {
        XCTAssertEqual(CatalogScope.all.title, "All")
        XCTAssertEqual(CatalogScope.formula.title, "Formulae")
        XCTAssertEqual(CatalogScope.cask.title, "Casks")
        XCTAssertTrue(CatalogScope.all.includes(.formula))
        XCTAssertTrue(CatalogScope.all.includes(.cask))
        XCTAssertTrue(CatalogScope.formula.includes(.formula))
        XCTAssertFalse(CatalogScope.formula.includes(.cask))
        XCTAssertTrue(CatalogScope.cask.includes(.cask))
        XCTAssertFalse(CatalogScope.cask.includes(.formula))
    }

    func testMetadataDetailsSkipAbsentOptionalValuesAndRenderNoForAutoUpdates() {
        let detail = CatalogPackageDetail.fixture(
            checksum: nil,
            autoUpdates: false
        )

        XCTAssertEqual(
            detail.metadataDetails,
            [
                CatalogDetailMetric(title: "Full Name", value: "wget"),
                CatalogDetailMetric(title: "Slug", value: "wget"),
                CatalogDetailMetric(title: "Tap", value: "homebrew/core"),
                CatalogDetailMetric(title: "License", value: "GPL-3.0-or-later"),
                CatalogDetailMetric(title: "Auto Updates", value: "No")
            ]
        )
    }

    func testJSONValueFlattensDescriptionsAndItems() throws {
        let value = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(
                """
                {
                  "zap": [
                    {
                      "trash": "~/Library/Caches/App"
                    },
                    true,
                    12
                  ]
                }
                """.utf8
            )
        )

        XCTAssertEqual(value.flattenedDescription, "zap: trash: ~/Library/Caches/App, true, 12")
        XCTAssertEqual(value.flattenedItems, ["zap: trash: ~/Library/Caches/App, true, 12"])
    }

    func testJSONValueHandlesPrimitiveAndNullCases() {
        XCTAssertEqual(JSONValue.string("brew").flattenedDescription, "brew")
        XCTAssertEqual(JSONValue.number(12).flattenedDescription, "12")
        XCTAssertEqual(JSONValue.number(12.5).flattenedDescription, "12.5")
        XCTAssertEqual(JSONValue.bool(false).flattenedDescription, "false")
        XCTAssertEqual(JSONValue.array([.string("a"), .number(2)]).flattenedItems, ["a", "2"])
        XCTAssertEqual(
            JSONValue.object(["name": .string("wget"), "items": .array([.bool(true)])]).flattenedItems,
            ["items: true, name: wget"]
        )
        XCTAssertEqual(JSONValue.null.flattenedDescription, "")
        XCTAssertEqual(JSONValue.null.flattenedItems, [])
    }

    func testJSONValueDecodingSupportsEverySupportedShape() throws {
        let decoder = JSONDecoder()

        XCTAssertEqual(try decoder.decode(JSONValue.self, from: Data("\"brew\"".utf8)), .string("brew"))
        XCTAssertEqual(try decoder.decode(JSONValue.self, from: Data("12.5".utf8)), .number(12.5))
        XCTAssertEqual(try decoder.decode(JSONValue.self, from: Data("true".utf8)), .bool(true))
        XCTAssertEqual(
            try decoder.decode(JSONValue.self, from: Data("[\"brew\", 7]".utf8)),
            .array([.string("brew"), .number(7)])
        )
        XCTAssertEqual(
            try decoder.decode(JSONValue.self, from: Data("{\"name\":\"wget\"}".utf8)),
            .object(["name": .string("wget")])
        )
        XCTAssertEqual(try decoder.decode(JSONValue.self, from: Data("null".utf8)), .null)
    }

    func testJSONValueObjectFlatteningKeepsKeyWhenNestedValueIsEmpty() {
        let value = JSONValue.object([
            "cleanup": .null,
            "name": .string("wget")
        ])

        XCTAssertEqual(value.flattenedDescription, "cleanup, name: wget")
        XCTAssertEqual(value.flattenedItems, ["cleanup, name: wget"])
    }
}
