import SwiftUI
import AppKit

@MainActor
var globalHUDController: HUDWindowController?

@main
struct DeepFocusApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var timerModel = TimerModel()
    @StateObject private var blockerService = AppBlockerService()

    @State private var hudController: HUDWindowController? = nil

    var body: some Scene {
        MenuBarExtra {
            if timerModel.state == .running {
                Button("Pause") { timerModel.pause() }
            } else if timerModel.state == .paused {
                Button("Resume") { timerModel.resume() }
            }

            if timerModel.state == .idle {
                Menu("Start Timer") {
                    ForEach(Preset.builtIns) { preset in
                        Button("\(preset.name) (\(preset.durationFormatted))") {
                            timerModel.start(taskName: preset.name, duration: preset.durationSeconds)
                            blockerService.start()
                        }
                    }
                }
            }

            Divider()

            Button(timerModel.isHUDVisible ? "Hide HUD" : "Show HUD") {
                timerModel.isHUDVisible.toggle()
            }
            .onChange(of: timerModel.isHUDVisible) { isVisible in
                ensureHUDController()
                if isVisible {
                    hudController?.show()
                } else {
                    hudController?.hide()
                }
            }

            Divider()

            Button("Check for Updates…") {
                appDelegate.checkForUpdates()
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: timerModel.menuBarSymbol)
                if !timerModel.menuBarText.isEmpty {
                    Text(timerModel.menuBarText)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                }
            }
            .onAppear {
                appDelegate.timerModel = timerModel
                ensureHUDController()
                hudController?.show()
                applyTestConfigIfNeeded()
            }
            .onChange(of: timerModel.state) { newState in
                handleStateChange(newState)
            }
        }
        .menuBarExtraStyle(.menu)
    }

    // MARK: - State Change Handling

    @MainActor
    private func handleStateChange(_ newState: TimerState) {
        switch newState {
        case .completed:
            NotificationService.sendCompletionNotification(
                taskName: timerModel.currentTaskName
            )
            NSApp.activate(ignoringOtherApps: true)
            blockerService.stop()

        case .idle:
            blockerService.stop()

        default:
            break
        }
    }

    // MARK: - Helpers

    @MainActor
    private func applyTestConfigIfNeeded() {
        guard ProcessInfo.processInfo.environment["DEEPFOCUS_UI_TEST"] == "1" else { return }

        let env = ProcessInfo.processInfo.environment

        // Set blocker mode
        if let modeStr = env["DEEPFOCUS_TEST_MODE"],
           let mode = BlockerMode(rawValue: modeStr) {
            blockerService.mode = mode
        }

        // Pre-configure blocklist from env var (comma-separated bundle IDs)
        if let blocklistEnv = env["DEEPFOCUS_TEST_BLOCKLIST"] {
            let bundleIDs = blocklistEnv.split(separator: ",").map(String.init)
            if blockerService.mode == .blocklist { // only override if in blocklist mode
                blockerService.blocklist = bundleIDs.map { makeBlockedApp($0) }
            }
        }

        // Pre-configure allowlist from env var (comma-separated bundle IDs)
        if let allowlistEnv = env["DEEPFOCUS_TEST_ALLOWLIST"] {
            let bundleIDs = allowlistEnv.split(separator: ",").map(String.init)
            blockerService.allowlist = bundleIDs.map { makeBlockedApp($0) }
        }

        // Auto-start a timer and blocker for testing
        if let durationStr = env["DEEPFOCUS_TEST_DURATION"],
           let duration = Int(durationStr) {
            timerModel.start(taskName: "UI Test", duration: duration)
            blockerService.start()
        }
    }

    private func makeBlockedApp(_ bundleID: String) -> BlockedApp {
        let name = NSWorkspace.shared.runningApplications
            .first { $0.bundleIdentifier == bundleID }?
            .localizedName ?? bundleID
        return BlockedApp(bundleIdentifier: bundleID, name: name)
    }

    @MainActor
    private func ensureHUDController() {
        if hudController == nil {
            hudController = HUDWindowController(
                timerModel: timerModel,
                blockerService: blockerService
            )
            globalHUDController = hudController
        }
    }
}
