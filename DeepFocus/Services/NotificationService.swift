import UserNotifications
import Foundation

enum NotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound]
        ) { granted, error in
            if let error {
                print("[DeepFocus] Notification permission error: \(error)")
            }
        }
    }

    static func sendCompletionNotification(taskName: String) {
        let content = UNMutableNotificationContent()
        content.title = "Time's up!"
        content.body = "\"\(taskName)\" session complete."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                print("[DeepFocus] Notification delivery error: \(error)")
            }
        }
    }
}
