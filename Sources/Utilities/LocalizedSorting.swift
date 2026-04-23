import Foundation

enum LocalizedSorting {
    static func ascending(
        _ lhs: String,
        _ rhs: String,
        fallback: @autoclosure () -> Bool
    ) -> Bool {
        let result = lhs.localizedCaseInsensitiveCompare(rhs)
        if result != .orderedSame {
            return result == .orderedAscending
        }

        return fallback()
    }
}
