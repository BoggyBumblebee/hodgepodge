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
