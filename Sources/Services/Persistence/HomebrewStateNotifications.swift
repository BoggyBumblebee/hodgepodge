import Foundation

extension Notification.Name {
    static let homebrewStateDidChange = Notification.Name("Hodgepodge.homebrewStateDidChange")
}

enum HomebrewStateNotificationUserInfoKey {
    static let sourceID = "sourceID"
}

struct HomebrewStateNotifier {
    private let notificationCenter: NotificationCenter

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    func notifyDidChange(sourceID: String? = nil) {
        if let sourceID {
            notificationCenter.post(
                name: .homebrewStateDidChange,
                object: nil,
                userInfo: [HomebrewStateNotificationUserInfoKey.sourceID: sourceID]
            )
        } else {
            notificationCenter.post(name: .homebrewStateDidChange, object: nil)
        }
    }
}

final class HomebrewStateObserver {
    private let notificationCenter: NotificationCenter
    private var token: NSObjectProtocol?

    init(
        notificationCenter: NotificationCenter = .default,
        onChange: @escaping @MainActor (String?) -> Void
    ) {
        self.notificationCenter = notificationCenter
        token = notificationCenter.addObserver(
            forName: .homebrewStateDidChange,
            object: nil,
            queue: .main
        ) { notification in
            let sourceID = notification.userInfo?[HomebrewStateNotificationUserInfoKey.sourceID] as? String
            MainActor.assumeIsolated {
                onChange(sourceID)
            }
        }
    }

    deinit {
        if let token {
            notificationCenter.removeObserver(token)
        }
    }
}
