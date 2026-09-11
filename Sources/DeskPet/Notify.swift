import AppKit
import UserNotifications

final class DoneNotify: NSObject, UNUserNotificationCenterDelegate {
    static let shared = DoneNotify()

    func start() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func finished(_ event: PluginState) {
        let folder = URL(fileURLWithPath: event.cwd).lastPathComponent
        let body: String
        if folder.isEmpty {
            body = L10n.doneNotify
        } else {
            body = "\(folder) · \(L10n.captionReview)"
        }
        let content = UNMutableNotificationContent()
        content.title = "DeskPet"
        content.body = body
        content.userInfo = [
            "source": event.source,
            "paneKey": event.paneKey,
            "tabId": event.tabId,
            "worktreeId": event.worktreeId,
            "cwd": event.cwd,
        ]
        let request = UNNotificationRequest(
            identifier: "deskpet-done-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info = response.notification.request.content.userInfo
        AgentFocus.activate(
            source: info["source"] as? String ?? "orca",
            paneKey: info["paneKey"] as? String ?? "",
            tabId: info["tabId"] as? String ?? "",
            worktreeId: info["worktreeId"] as? String ?? "",
            cwd: info["cwd"] as? String ?? ""
        )
        completionHandler()
    }
}

