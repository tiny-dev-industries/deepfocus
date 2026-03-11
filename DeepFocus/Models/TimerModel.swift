import Foundation

enum TimerState: Equatable {
    case idle
    case running
    case paused
    case completed
}

enum TimerStrictness: String, CaseIterable, Codable {
    case soft
    case medium
    case hard

    var label: String {
        switch self {
        case .soft:   return "Soft"
        case .medium: return "Medium"
        case .hard:   return "Hard"
        }
    }

    var hint: String {
        switch self {
        case .soft:   return "Cancel anytime."
        case .medium: return "Solve a math problem to cancel."
        case .hard:   return "Can't cancel — quit the app to stop."
        }
    }
}

@MainActor
final class TimerModel: ObservableObject {
    @Published var state: TimerState = .idle
    @Published var currentTaskName: String = ""
    @Published var remainingSeconds: Int = 0
    @Published var totalSeconds: Int = 0
    @Published var isHUDVisible: Bool = true

    // Staging duration for idle state (in seconds)
    @Published var stagingDuration: Int = 1500  // Default 25 minutes

    // HUD appearance — persisted to UserDefaults
    @Published var hudScale: Double = 1.0 {
        didSet { UserDefaults.standard.set(hudScale, forKey: "com.deepfocus.hudScale") }
    }
    @Published var idleWindowHeight: Double = 520.0 {
        didSet { UserDefaults.standard.set(idleWindowHeight, forKey: "com.deepfocus.idleWindowHeight") }
    }
    @Published var strictness: TimerStrictness = .soft {
        didSet { UserDefaults.standard.set(strictness.rawValue, forKey: "com.deepfocus.strictness") }
    }

    private var timer: Timer? = nil

    init() {
        let storedScale = UserDefaults.standard.double(forKey: "com.deepfocus.hudScale")
        if storedScale > 0 { hudScale = storedScale }

        let storedIdleHeight = UserDefaults.standard.double(forKey: "com.deepfocus.idleWindowHeight")
        if storedIdleHeight > 0 { idleWindowHeight = storedIdleHeight }

        if let raw = UserDefaults.standard.string(forKey: "com.deepfocus.strictness"),
           let saved = TimerStrictness(rawValue: raw) {
            strictness = saved
        }
    }

    // MARK: - Computed

    var formattedTime: String {
        let m = remainingSeconds / 60
        let s = remainingSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var menuBarSymbol: String {
        state == .paused ? "pause.circle.fill" : "timer"
    }

    var menuBarText: String {
        switch state {
        case .idle:
            return ""
        case .running, .paused, .completed:
            let mins = Int(ceil(Double(remainingSeconds) / 60.0))
            return "\(mins)m"
        }
    }

    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }

    // MARK: - Actions

    func start(taskName: String, duration: Int) {
        stopTimer()
        let trimmed = taskName.trimmingCharacters(in: .whitespaces)
        currentTaskName = trimmed.isEmpty ? "Focus" : trimmed
        totalSeconds = duration
        remainingSeconds = duration
        state = .running
        scheduleTimer()
    }

    func pause() {
        guard state == .running else { return }
        state = .paused
        stopTimer()
    }

    func resume() {
        guard state == .paused else { return }
        state = .running
        scheduleTimer()
    }

    func cancel() {
        stopTimer()
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        currentTaskName = ""
    }

    func reset() {
        cancel()
    }

    // MARK: - Internal Timer

    private func scheduleTimer() {
        // .common mode ensures the timer fires even while menus are open
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.tick()
            }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard state == .running else { return }
        if remainingSeconds > 0 {
            remainingSeconds -= 1
        } else {
            completeTimer()
        }
    }

    private func completeTimer() {
        stopTimer()
        state = .completed

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            if state == .completed {
                reset()
            }
        }
    }
}
