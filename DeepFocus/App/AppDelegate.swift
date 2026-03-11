import AppKit
import UserNotifications

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by DeepFocusApp on launch so the delegate can inspect timer state.
    var timerModel: TimerModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationService.requestPermission()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let model = timerModel,
              model.strictness == .hard,
              model.state == .running || model.state == .paused else {
            return .terminateNow
        }

        let alert = NSAlert()
        alert.messageText = "Hard mode is active"
        alert.informativeText = "You set yourself a Hard mode timer. You can't quit normally.\n\nUse Force Quit (⌘⌥⎋) if you truly need out."
        alert.alertStyle = .critical
        alert.addButton(withTitle: "Stay Focused")
        alert.runModal()
        return .terminateCancel
    }
}
