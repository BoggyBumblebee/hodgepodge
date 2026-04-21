import Foundation

struct HomebrewInstallation: Equatable, Sendable {
    let brewPath: String
    let version: String
    let prefix: String
    let cellar: String
    let repository: String
    let taps: [String]
    let detectedAt: Date
}
