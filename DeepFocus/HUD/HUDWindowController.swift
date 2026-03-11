import AppKit
import SwiftUI
import Combine

extension Notification.Name {
    static let hudResizeRequested  = Notification.Name("com.deepfocus.hudResizeRequested")
    static let hudShouldBecomeKey  = Notification.Name("com.deepfocus.hudShouldBecomeKey")
}

private final class KeyableHUDPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HUDWindowController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private weak var timerModel: TimerModel?

    private let hudFrameKey = "com.deepfocus.hudFrame"
    private var stateObserver: AnyCancellable?

    init(timerModel: TimerModel, blockerService: AppBlockerService) {
        self.timerModel = timerModel
        super.init()
        buildPanel(timerModel: timerModel, blockerService: blockerService)
        observeResizeRequests()
        observeTimerState(timerModel: timerModel)
    }

    // MARK: - Panel Setup

    private func buildPanel(timerModel: TimerModel, blockerService: AppBlockerService) {
        let rootView = HUDContentView()
            .environmentObject(timerModel)
            .environmentObject(blockerService)

        let hostingView = NSHostingView(rootView: rootView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let panel = KeyableHUDPanel(
            contentRect: initialFrame(),
            styleMask: [.resizable],
            backing: .buffered,
            defer: false
        )

        panel.level = .floating
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.appearance = NSAppearance(named: .darkAqua)
        panel.contentView = hostingView
        panel.delegate = self
        panel.setAccessibilityIdentifier("hud")

        self.panel = panel
    }

    private func initialFrame() -> NSRect {
        if let saved = UserDefaults.standard.string(forKey: hudFrameKey) {
            let frame = NSRectFromString(saved)
            if !frame.isEmpty { return frame }
        }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let width: CGFloat = 260
        let height: CGFloat = 132
        return NSRect(
            x: screen.maxX - width - 20,
            y: screen.maxY - height - 20,
            width: width,
            height: height
        )
    }

    // MARK: - Resize handling

    private func observeResizeRequests() {
        NotificationCenter.default.addObserver(
            forName: .hudResizeRequested,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let height = (notification.object as? NSNumber).map({ CGFloat($0.doubleValue) })
            else { return }
            Task { @MainActor [weak self] in
                self?.resize(to: height)
            }
        }

        NotificationCenter.default.addObserver(
            forName: .hudShouldBecomeKey,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.panel?.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func observeTimerState(timerModel: TimerModel) {
        stateObserver = timerModel.$state.sink { [weak self] state in
            Task { @MainActor [weak self] in
                self?.updateResizability(for: state)
            }
        }
    }

    private func updateResizability(for state: TimerState) {
        guard let panel else { return }

        // Never mutate styleMask on a visible window — it invalidates AppKit's
        // constraint system mid-display-cycle and causes an EXC_BREAKPOINT crash
        // on macOS 26+. Instead, lock/unlock the size via minSize/maxSize only.
        if state == .idle {
            panel.minSize = NSSize(width: 260, height: 300)
            panel.maxSize = NSSize(width: 260, height: 1200)
        } else {
            // Lock size: set min == max == current frame size
            let locked = NSSize(width: panel.frame.width, height: panel.frame.height)
            panel.minSize = locked
            panel.maxSize = locked
        }
    }

    private func resize(to height: CGFloat) {
        guard let panel else { return }
        guard abs(panel.frame.height - height) > 1 else { return }

        var frame = panel.frame
        let delta = height - frame.height
        frame.origin.y -= delta
        frame.size.height = height

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.18
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    // MARK: - Show / Hide

    func show() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
    }

    func hide() {
        saveFrame()
        panel?.orderOut(nil)
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    // MARK: - NSWindowDelegate

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.timerModel?.isHUDVisible = false
            self.saveFrame()
        }
    }

    nonisolated func windowDidResize(_ notification: Notification) {
        Task { @MainActor in
            guard let timerModel = self.timerModel,
                  timerModel.state == .idle,
                  let panel = self.panel else { return }

            let newHeight = panel.frame.height / timerModel.hudScale
            timerModel.idleWindowHeight = newHeight
        }
    }

    // MARK: - Frame Persistence

    private func saveFrame() {
        guard let frame = panel?.frame else { return }
        UserDefaults.standard.set(NSStringFromRect(frame), forKey: hudFrameKey)
    }
}
