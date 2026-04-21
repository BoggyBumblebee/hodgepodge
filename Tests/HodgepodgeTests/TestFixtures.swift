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
