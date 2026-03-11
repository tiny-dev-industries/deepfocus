import SwiftUI
import AppKit

struct HUDContentView: View {
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var blockerService: AppBlockerService

    @State private var isHovered = false
    @State private var isEditingTaskName = false
    @State private var originalTaskName = ""
    @State private var completionScale: CGFloat = 1.0
    @State private var showingAppPicker = false

    // Block feedback
    @State private var shakeOffset: CGFloat = 0
    @State private var isFlashing: Bool = false
    @State private var toastOpacity: Double = 0
    @State private var toastAppName: String = ""

    // Cancel challenge (medium strictness)
    @State private var showingCancelChallenge = false
    @State private var challengeAnswer = ""
    @State private var challengeWrong = false
    @State private var challengeProgress = 0   // 0–2; 3 correct in a row → cancel
    @State private var currentChallenge = MathChallenge.generate()

    var body: some View {
        contentView
            .padding(.top, 28)   // clearance for traffic lights
            .padding([.horizontal, .bottom], 12)
            .frame(minWidth: 210)
            .background(hudBackground)
            .overlay(alignment: .topLeading) { trafficLights.padding(9) }
            .offset(x: shakeOffset)
            .overlay(alignment: .top) { toastBanner }
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.18)) {
                    isHovered = hovering
                }
            }
            .contextMenu { contextMenuContent }
            .sheet(isPresented: $showingAppPicker) {
                AppPickerView()
                    .environmentObject(blockerService)
            }
            .sheet(isPresented: $showingCancelChallenge) {
                cancelChallengeSheet
            }
            .onAppear { postResize() }
            .onChange(of: isHovered) { _ in postResize() }
            .onChange(of: timerModel.state, perform: handleStateChange)
            .onChange(of: isEditingTaskName) { _ in postResize() }
            .onChange(of: timerModel.hudScale) { _ in postResize() }
            .onChange(of: blockerService.blockedAttempts) { _ in triggerBlockFeedback() }
    }

    private var contentView: some View {
        Group {
            if timerModel.state == .idle {
                idleView
            } else {
                activeView
            }
        }
    }

    private var hudBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color.black)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        isFlashing ? Color.orange.opacity(0.85) : Color.white.opacity(0.1),
                        lineWidth: isFlashing ? 2 : 1
                    )
            )
    }

    private var toastBanner: some View {
        HStack(spacing: 5) {
            Text("⛔")
                .font(.system(size: 10))
            Text(toastAppName.isEmpty ? "Blocked" : "\(toastAppName) blocked")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(white: 0.15).opacity(0.95))
        .cornerRadius(20)
        .padding(.top, 8)
        .opacity(toastOpacity)
    }

    private func handleStateChange(_ newState: TimerState) {
        postResize()
        if newState == .completed {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.35)) {
                completionScale = 1.08
            }
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    completionScale = 1.0
                }
            }
        }
    }

    // MARK: - Idle view

    private var idleView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Task name field
                ZStack {
                    if timerModel.currentTaskName.isEmpty {
                        Text("Task name...")
                            .font(.system(size: 12 * timerModel.hudScale, weight: .medium))
                            .foregroundColor(.white.opacity(0.4))
                    }
                    TextField("", text: taskNameBinding)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12 * timerModel.hudScale, weight: .medium))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .center)

                // Timer display
                Text(formatStagingTime())
                    .font(.system(size: 48 * timerModel.hudScale, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)

                // Duration adjust buttons
                HStack(spacing: 8) {
                    adjustButton("-5", offset: -5 * 60)
                    adjustButton("-1", offset: -1 * 60)
                    adjustButton("+1", offset: 1 * 60)
                    adjustButton("+5", offset: 5 * 60)
                }
                .padding(.bottom, 12)

                // Start button
                Button {
                    startTimerWithStagingValues()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("START")
                            .font(.system(size: 13, weight: .bold))
                            .kerning(1)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.green.opacity(0.25))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.green.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.bottom, 12)

                // Presets
                VStack(spacing: 4) {
                    Text("PRESETS")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    presetList
                }
                .padding(.bottom, 12)

                // Divider
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .frame(height: 1)
                    .padding(.vertical, 8)

                // App Blocker config
                BlockerConfigView(showingAppPicker: $showingAppPicker)
                    .environmentObject(blockerService)

                // Strictness
                strictnessSection
                    .padding(.top, 12)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Preset List

    private var presetList: some View {
        VStack(spacing: 4) {
            ForEach(Preset.builtIns) { preset in
                Button {
                    timerModel.stagingDuration = preset.durationSeconds
                    timerModel.currentTaskName = preset.name
                } label: {
                    HStack {
                        Text(preset.name)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                        Spacer()
                        Text(preset.durationFormatted)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.07))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Strictness

    private var strictnessSection: some View {
        VStack(spacing: 8) {
            Text("TIMER STRICTNESS")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $timerModel.strictness) {
                ForEach(TimerStrictness.allCases, id: \.self) { s in
                    Text(s.label).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: .infinity)

            Text(timerModel.strictness.hint)
                .font(.system(size: 10))
                .foregroundColor(.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Cancel challenge sheet (medium mode)

    private var cancelChallengeSheet: some View {
        VStack(spacing: 20) {
            Text("Prove you mean it")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)

            // Progress dots
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(i < challengeProgress ? Color.green : Color.white.opacity(0.2))
                        .frame(width: 10, height: 10)
                        .animation(.easeInOut(duration: 0.2), value: challengeProgress)
                }
            }

            Text(currentChallenge.question)
                .font(.system(size: 40, weight: .bold, design: .monospaced))
                .foregroundColor(.white)

            TextField("Answer", text: $challengeAnswer)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
                .multilineTextAlignment(.center)
                .font(.system(size: 18, design: .monospaced))
                .onSubmit { submitChallengeAnswer() }

            if challengeWrong {
                Text("Wrong — back to zero")
                    .font(.system(size: 12))
                    .foregroundColor(.red)
            }

            HStack(spacing: 16) {
                Button("Keep Going") {
                    dismissChallenge()
                }
                .foregroundColor(.white.opacity(0.6))

                Button("Submit") {
                    submitChallengeAnswer()
                }
                .foregroundColor(.red)
                .fontWeight(.semibold)
                .keyboardShortcut(.return)
            }
        }
        .padding(32)
        .background(Color(white: 0.1))
        .frame(width: 280)
    }

    private func submitChallengeAnswer() {
        guard let answer = Int(challengeAnswer) else { return }
        if answer == currentChallenge.answer {
            challengeWrong = false
            challengeAnswer = ""
            challengeProgress += 1
            if challengeProgress >= 3 {
                dismissChallenge()
                timerModel.cancel()
            } else {
                currentChallenge = MathChallenge.generate()
            }
        } else {
            challengeWrong = true
            challengeAnswer = ""
            challengeProgress = 0
            currentChallenge = MathChallenge.generate()
        }
    }

    private func dismissChallenge() {
        showingCancelChallenge = false
        challengeAnswer = ""
        challengeWrong = false
        challengeProgress = 0
        currentChallenge = MathChallenge.generate()
    }

    // MARK: - Active view

    private var activeView: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 2) {
                taskNameRow

                Text(timerModel.formattedTime)
                    .font(.system(size: 48 * timerModel.hudScale, weight: .bold, design: .monospaced))
                    .foregroundColor(timerColor)
                    .monospacedDigit()
                    .frame(maxWidth: .infinity, alignment: .center)

                if timerModel.state == .paused {
                    Text("PAUSED")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                        .kerning(2)
                } else if timerModel.state == .completed {
                    Text("COMPLETE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green)
                        .kerning(2)
                }

                // Blocked attempts counter
                if blockerService.isActive && blockerService.blockedAttempts > 0 {
                    Text("Blocked: \(blockerService.blockedAttempts)")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(.top, 2)
                        .accessibilityIdentifier("blockedAttempts")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .scaleEffect(completionScale)

            if isHovered {
                HStack(spacing: 0) {
                    switch timerModel.state {
                    case .running:
                        Button { timerModel.pause() } label: {
                            Image(systemName: "pause.fill")
                        }
                        .buttonStyle(HUDIconButtonStyle())
                        .help("Pause timer")
                    case .paused:
                        Button { timerModel.resume() } label: {
                            Image(systemName: "play.fill")
                        }
                        .buttonStyle(HUDIconButtonStyle())
                        .help("Resume timer")
                    case .completed, .idle:
                        Color.clear.frame(width: 26, height: 26)
                    }

                    Spacer()

                    if timerModel.strictness != .hard {
                        Button {
                            if timerModel.strictness == .medium {
                                currentChallenge = MathChallenge.generate()
                                showingCancelChallenge = true
                            } else {
                                timerModel.cancel()
                            }
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(HUDIconButtonStyle(isDestructive: true))
                        .help(timerModel.strictness == .medium ? "Solve a problem to cancel" : "Cancel timer")
                        .opacity(timerModel.state == .completed ? 0 : 1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Task name row

    @ViewBuilder
    private var taskNameRow: some View {
        if isEditingTaskName {
            VStack(spacing: 4) {
                FocusableTextField(
                    text: taskNameBinding,
                    placeholder: "Focus task...",
                    isFocused: isEditingTaskName,
                    onSubmit: { isEditingTaskName = false },
                    onCancel: {
                        timerModel.currentTaskName = originalTaskName
                        isEditingTaskName = false
                    }
                )
                .frame(height: 20)
                .frame(maxWidth: .infinity)

                HStack(spacing: 6) {
                    Spacer()
                    Button { isEditingTaskName = false } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(HUDIconButtonStyle())
                    .help("Save changes")
                    Button {
                        timerModel.currentTaskName = originalTaskName
                        isEditingTaskName = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(HUDIconButtonStyle(isDestructive: true))
                    .help("Discard changes")
                    Spacer()
                }
            }
        } else {
            Text(timerModel.currentTaskName.isEmpty ? "Focus task..." : timerModel.currentTaskName)
                .font(.system(size: 12 * timerModel.hudScale, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
                .frame(maxWidth: .infinity, alignment: .center)
                .lineLimit(1)
                .truncationMode(.tail)
                .overlay(alignment: .trailing) {
                    if isHovered {
                        Button {
                            originalTaskName = timerModel.currentTaskName
                            isEditingTaskName = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(HUDIconButtonStyle())
                        .help("Edit task name")
                    }
                }
        }
    }

    // MARK: - Context menu

    @ViewBuilder
    private var contextMenuContent: some View {
        if timerModel.state == .idle {
            Button("Start Timer") {
                startTimerWithStagingValues()
            }
            Divider()
        }
        if timerModel.state == .running {
            Button("Pause") { timerModel.pause() }
        }
        if timerModel.state == .paused {
            Button("Resume") { timerModel.resume() }
        }
        if timerModel.state == .completed {
            Button("New Session") { timerModel.reset() }
        }
        if timerModel.state == .running || timerModel.state == .paused {
            Divider()
            if timerModel.strictness != .hard {
                Button("Cancel", role: .destructive) {
                    if timerModel.strictness == .medium {
                        currentChallenge = MathChallenge.generate()
                        showingCancelChallenge = true
                    } else {
                        timerModel.cancel()
                    }
                }
            }
        }
        Divider()
        Button(timerModel.isHUDVisible ? "Dismiss HUD" : "Show HUD") {
            timerModel.isHUDVisible.toggle()
        }
    }

    // MARK: - Resize signalling

    private func postResize() {
        let scale = timerModel.hudScale
        var height: CGFloat
        switch timerModel.state {
        case .idle:
            height = timerModel.idleWindowHeight * scale
        case .running:
            height = isHovered ? 152 * scale : 114 * scale
        case .paused, .completed:
            height = isHovered ? 174 * scale : 138 * scale
        }
        if isEditingTaskName { height += 30 }
        NotificationCenter.default.post(
            name: .hudResizeRequested,
            object: height as NSNumber
        )
    }

    // MARK: - Block feedback

    private func triggerBlockFeedback() {
        toastAppName = blockerService.lastBlockedAppName

        // Shake: rapid left-right oscillation
        let offsets: [CGFloat] = [-9,  9, -6,  6, -3,  3, 0]
        let delays:  [Int]     = [  0, 60, 120, 180, 240, 300, 380]
        for (offset, ms) in zip(offsets, delays) {
            Task {
                try? await Task.sleep(for: .milliseconds(ms))
                withAnimation(.interactiveSpring(response: 0.07, dampingFraction: 0.5)) {
                    shakeOffset = offset
                }
            }
        }

        // Border flash: snap to orange, fade back
        withAnimation(.easeOut(duration: 0.08)) { isFlashing = true }
        Task {
            try? await Task.sleep(for: .milliseconds(120))
            withAnimation(.easeOut(duration: 0.7)) { isFlashing = false }
        }

        // Toast: fade in, hold, fade out
        withAnimation(.easeOut(duration: 0.15)) { toastOpacity = 1 }
        Task {
            try? await Task.sleep(for: .milliseconds(1500))
            withAnimation(.easeOut(duration: 0.35)) { toastOpacity = 0 }
        }
    }

    // MARK: - Helpers

    private var taskNameBinding: Binding<String> {
        Binding(
            get: { timerModel.currentTaskName },
            set: { timerModel.currentTaskName = $0 }
        )
    }

    private var timerColor: Color {
        switch timerModel.state {
        case .completed: return .green
        case .paused:    return .orange
        default:         return .white
        }
    }

    private func adjustButton(_ label: String, offset: Int) -> some View {
        Button {
            timerModel.stagingDuration = max(60, timerModel.stagingDuration + offset)
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .frame(width: 32, height: 24)
                .background(Color.white.opacity(0.07))
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func formatStagingTime() -> String {
        let m = timerModel.stagingDuration / 60
        let s = timerModel.stagingDuration % 60
        return String(format: "%02d:%02d", m, s)
    }

    private func startTimerWithStagingValues() {
        let name = timerModel.currentTaskName.trimmingCharacters(in: .whitespaces)
        timerModel.start(
            taskName: name.isEmpty ? "Focus" : name,
            duration: timerModel.stagingDuration
        )
        blockerService.start()
    }
}

// MARK: - Math challenge

private struct MathChallenge {
    let question: String
    let answer: Int

    static func generate() -> MathChallenge {
        let useMultiply = Bool.random()
        if useMultiply {
            let a = Int.random(in: 7...15)
            let b = Int.random(in: 7...15)
            return MathChallenge(question: "\(a) × \(b)", answer: a * b)
        } else {
            let a = Int.random(in: 20...99)
            let b = Int.random(in: 20...99)
            return MathChallenge(question: "\(a) + \(b)", answer: a + b)
        }
    }
}

// MARK: - Traffic lights

extension HUDContentView {
    /// macOS-style close / minimize / zoom buttons, always visible in the top-left corner.
    ///
    /// Behaviour:
    /// - Idle: red (close) + yellow (minimize) both hide the HUD; green is disabled.
    /// - Active timer: red is disabled (can't dismiss mid-session); yellow hides the HUD.
    var trafficLights: some View {
        let isTimerActive = timerModel.state == .running || timerModel.state == .paused
        let redEnabled = !isTimerActive

        return HStack(spacing: 8) {
            // Red — hide HUD (disabled during active timer)
            TrafficLightButton(
                color: redEnabled
                    ? Color(red: 1.0,   green: 0.373, blue: 0.341)
                    : Color(white: 0.35),
                icon: "xmark",
                showIcon: isHovered && redEnabled,
                disabled: !redEnabled
            ) {
                NotificationCenter.default.post(name: .hudShouldHide, object: nil)
            }

            // Yellow — miniaturize with genie animation (always available)
            TrafficLightButton(
                color: Color(red: 0.996, green: 0.737, blue: 0.180),
                icon: "minus",
                showIcon: isHovered
            ) {
                NotificationCenter.default.post(name: .hudShouldMiniaturize, object: nil)
            }

            // Green — no-op; greyed out (no meaningful zoom for a floating HUD)
            TrafficLightButton(
                color: Color(white: 0.35),
                icon: "arrow.up.left.and.arrow.down.right",
                showIcon: false,
                disabled: true
            ) {}
        }
    }
}

private struct TrafficLightButton: View {
    let color: Color
    let icon: String
    let showIcon: Bool
    var disabled: Bool = false
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                if showIcon || isHovered, !disabled {
                    Image(systemName: icon)
                        .font(.system(size: 6.5, weight: .black))
                        .foregroundStyle(.black.opacity(0.55))
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { isHovered = $0 }
    }
}

// MARK: - HUD icon button style

struct HUDIconButtonStyle: ButtonStyle {
    var isDestructive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(
                isDestructive
                    ? .red.opacity(configuration.isPressed ? 0.45 : 0.75)
                    : .white.opacity(configuration.isPressed ? 0.35 : 0.65)
            )
            .frame(width: 26, height: 26)
            .background(
                Circle()
                    .fill(Color.white.opacity(configuration.isPressed ? 0.14 : 0.07))
            )
    }
}
