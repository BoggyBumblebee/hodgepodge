import XCTest
@testable import Hodgepodge

final class CatalogAnalyticsTests: XCTestCase {
    func testPeriodsExposeStableIDsAndTitles() {
        XCTAssertEqual(CatalogAnalyticsPeriod.days30.id, "30d")
        XCTAssertEqual(CatalogAnalyticsPeriod.days30.title, "30 Days")
        XCTAssertEqual(CatalogAnalyticsPeriod.days90.id, "90d")
        XCTAssertEqual(CatalogAnalyticsPeriod.days90.title, "90 Days")
        XCTAssertEqual(CatalogAnalyticsPeriod.days365.id, "365d")
        XCTAssertEqual(CatalogAnalyticsPeriod.days365.title, "365 Days")
    }

    func testLeaderboardKindsExposeStableIDsTitlesAndSubtitles() {
        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.formulaInstalls.id, "formulaInstalls")
        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.formulaInstalls.title, "Top Formula Installs")
        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.formulaInstalls.subtitle,
            "Most-installed formulae in the selected period."
        )

        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.formulaInstallsOnRequest.id,
            "formulaInstallsOnRequest"
        )
        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.formulaInstallsOnRequest.title,
            "Top On-Request Formulae"
        )
        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.formulaInstallsOnRequest.subtitle,
            "Formulae users explicitly chose most often."
        )

        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.caskInstalls.id, "caskInstalls")
        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.caskInstalls.title, "Top Cask Installs")
        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.caskInstalls.subtitle,
            "Most-installed casks in the selected period."
        )

        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.buildErrors.id, "buildErrors")
        XCTAssertEqual(CatalogAnalyticsLeaderboardKind.buildErrors.title, "Most Frequent Build Errors")
        XCTAssertEqual(
            CatalogAnalyticsLeaderboardKind.buildErrors.subtitle,
            "Formulae with the highest recent build error counts."
        )
    }

    func testItemAndLeaderboardExposeDerivedIdentityAndSummary() {
        let item = CatalogAnalyticsItem(
            kind: .formula,
            slug: "wget",
            rank: 1,
            count: "42",
            percent: "12.0%"
        )
        let leaderboard = CatalogAnalyticsLeaderboard(
            kind: .formulaInstalls,
            period: .days30,
            startDate: "2026-03-01",
            endDate: "2026-03-31",
            totalItems: 10,
            totalCount: "420",
            items: [item]
        )

        XCTAssertEqual(item.id, "formula:wget")
        XCTAssertEqual(item.title, "wget")
        XCTAssertEqual(leaderboard.id, "formulaInstalls:30d")
        XCTAssertEqual(leaderboard.title, "Top Formula Installs")
        XCTAssertEqual(leaderboard.subtitle, "Most-installed formulae in the selected period.")
        XCTAssertEqual(leaderboard.dateRangeSummary, "2026-03-01 to 2026-03-31")
    }

    func testEmptySnapshotUsesRequestedPeriod() {
        XCTAssertEqual(CatalogAnalyticsSnapshot.empty.period, .days30)
        XCTAssertTrue(CatalogAnalyticsSnapshot.empty.leaderboards.isEmpty)

        let snapshot = CatalogAnalyticsSnapshot.empty(for: .days365)
        XCTAssertEqual(snapshot.period, .days365)
        XCTAssertTrue(snapshot.leaderboards.isEmpty)
    }
}
