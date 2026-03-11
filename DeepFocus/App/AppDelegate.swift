import AppKit
import UserNotifications
import Sparkle

final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Set by DeepFocusApp on launch so the delegate can inspect timer state.
    var timerModel: TimerModel?

    /// Sparkle updater controller — must be kept alive for the app's lifetime.
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NotificationService.requestPermission()
    }

    /// Exposed so the menu bar "Check for Updates…" item can trigger a manual check.
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
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
