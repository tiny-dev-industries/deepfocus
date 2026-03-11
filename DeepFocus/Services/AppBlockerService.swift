import AppKit
import Combine

enum BlockerMode: String, CaseIterable {
    case blocklist
    case allowlist
}

struct BlockedApp: Identifiable, Codable, Equatable, Hashable {
    let bundleIdentifier: String
    let name: String

    var id: String { bundleIdentifier }
}

@MainActor
final class AppBlockerService: ObservableObject {
    // MARK: - Published State

    @Published var mode: BlockerMode = .blocklist {
        didSet { persistConfig() }
    }
    @Published var blocklist: [BlockedApp] = [] {
        didSet { persistConfig() }
    }
    @Published var allowlist: [BlockedApp] = [] {
        didSet { persistConfig() }
    }
    @Published private(set) var isActive: Bool = false
    @Published private(set) var blockedAttempts: Int = 0
    @Published private(set) var lastBlockedAppName: String = ""

    // MARK: - Private

    private var workspaceObserver: (any NSObjectProtocol)?
    private var lastAllowedApp: NSRunningApplication?

    private let modeKey = "com.deepfocus.blockerMode"
    private let blocklistKey = "com.deepfocus.blocklist"
    private let allowlistKey = "com.deepfocus.allowlist"

    init() {
        loadConfig()
    }

    // MARK: - Active list for current mode

    var activeList: [BlockedApp] {
        mode == .blocklist ? blocklist : allowlist
    }

    var activeListLabel: String {
        mode == .blocklist ? "Blocked Apps" : "Allowed Apps"
    }

    // MARK: - Start / Stop

    func start() {
        guard !isActive else { return }
        isActive = true
        blockedAttempts = 0

        // Only track the frontmost app as lastAllowed if it's not our own app
        let frontmost = NSWorkspace.shared.frontmostApplication
        if let bid = frontmost?.bundleIdentifier, bid != Bundle.main.bundleIdentifier {
            lastAllowedApp = frontmost
        } else {
            lastAllowedApp = nil
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                self?.handleAppActivation(notification)
            }
        }

        // If a blocked app is already frontmost when the timer starts, block it immediately
        if let frontmost,
           let bundleID = frontmost.bundleIdentifier,
           bundleID != Bundle.main.bundleIdentifier {
            checkAndBlock(frontmost, bundleID: bundleID)
        }
    }

    func stop() {
        guard isActive else { return }
        isActive = false

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            workspaceObserver = nil
        }
        lastAllowedApp = nil
    }

    // MARK: - App Activation Handler

    private func handleAppActivation(_ notification: Notification) {
        guard isActive else { return }
        guard let activatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey]
                as? NSRunningApplication,
              let bundleID = activatedApp.bundleIdentifier else { return }

        // Our own app is always allowed
        if bundleID == Bundle.main.bundleIdentifier { return }

        checkAndBlock(activatedApp, bundleID: bundleID)
    }

    private func checkAndBlock(_ app: NSRunningApplication, bundleID: String) {
        let shouldBlock: Bool

        switch mode {
        case .blocklist:
            shouldBlock = blocklist.contains { $0.bundleIdentifier == bundleID }
        case .allowlist:
            shouldBlock = !allowlist.contains { $0.bundleIdentifier == bundleID }
        }

        if shouldBlock {
            blockedAttempts += 1
            lastBlockedAppName = app.localizedName ?? bundleID
            app.hide()
            if let fallback = lastAllowedApp,
               !fallback.isTerminated,
               fallback.bundleIdentifier != Bundle.main.bundleIdentifier {
                if #available(macOS 14.0, *) {
                    fallback.activate()
                } else {
                    fallback.activate(options: .activateIgnoringOtherApps)
                }
            } else {
                // No valid last-allowed app (e.g., came from DeepFocus itself) —
                // bring the HUD panel to key focus
                NSApp.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: .hudShouldBecomeKey, object: nil)
            }
        } else {
            lastAllowedApp = app
        }
    }

    // MARK: - App Discovery

    static func runningGUIApps() -> [BlockedApp] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in
                guard let bundleID = app.bundleIdentifier else { return nil }
                return BlockedApp(
                    bundleIdentifier: bundleID,
                    name: app.localizedName ?? bundleID
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func installedApps() -> [BlockedApp] {
        let fm = FileManager.default
        let appDirs = ["/Applications", "/Applications/Utilities",
                       "\(NSHomeDirectory())/Applications"]
        var seen = Set<String>()
        var apps: [BlockedApp] = []

        for dir in appDirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                guard let bundle = Bundle(path: path),
                      let bundleID = bundle.bundleIdentifier,
                      !seen.contains(bundleID) else { continue }
                seen.insert(bundleID)
                let name = bundle.infoDictionary?["CFBundleName"] as? String
                    ?? item.replacingOccurrences(of: ".app", with: "")
                apps.append(BlockedApp(bundleIdentifier: bundleID, name: name))
            }
        }

        return apps.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    // MARK: - List Management

    func addToActiveList(_ app: BlockedApp) {
        switch mode {
        case .blocklist:
            if !blocklist.contains(app) { blocklist.append(app) }
        case .allowlist:
            if !allowlist.contains(app) { allowlist.append(app) }
        }
    }

    func removeFromActiveList(_ app: BlockedApp) {
        switch mode {
        case .blocklist:
            blocklist.removeAll { $0 == app }
        case .allowlist:
            allowlist.removeAll { $0 == app }
        }
    }

    func isInActiveList(_ app: BlockedApp) -> Bool {
        switch mode {
        case .blocklist:
            return blocklist.contains(app)
        case .allowlist:
            return allowlist.contains(app)
        }
    }

    // MARK: - Persistence

    private func persistConfig() {
        UserDefaults.standard.set(mode.rawValue, forKey: modeKey)
        if let data = try? JSONEncoder().encode(blocklist) {
            UserDefaults.standard.set(data, forKey: blocklistKey)
        }
        if let data = try? JSONEncoder().encode(allowlist) {
            UserDefaults.standard.set(data, forKey: allowlistKey)
        }
    }

    private func loadConfig() {
        if let raw = UserDefaults.standard.string(forKey: modeKey),
           let m = BlockerMode(rawValue: raw) {
            mode = m
        }
        if let data = UserDefaults.standard.data(forKey: blocklistKey),
           let list = try? JSONDecoder().decode([BlockedApp].self, from: data) {
            blocklist = list
        }
        if let data = UserDefaults.standard.data(forKey: allowlistKey),
           let list = try? JSONDecoder().decode([BlockedApp].self, from: data) {
            allowlist = list
        }
    }
}
