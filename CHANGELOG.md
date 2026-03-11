# Changelog

## [1.0.4] - 2026-03-11

### Added

- **Traffic light buttons on HUD**: macOS-style close/minimize/zoom buttons are
  now always visible in the top-left corner of the HUD.
  - Red (×): hides the HUD (disabled during an active timer).
  - Yellow (−): miniaturizes the HUD to the Dock with the standard genie animation.
  - Green: disabled (no meaningful zoom action for a floating HUD).
- **Dock icon toggle**: Clicking the Dock icon now toggles the HUD — shows it
  if hidden, hides it if visible. Restores from the Dock when miniaturized.
- **"Check for Updates…" in app menu**: Added beside "About DeepFocus" with a
  separator, in addition to the menu bar menu.
- **Reactive update button**: Title changes to "Install Update…" when Sparkle
  finds a new version; resets after dismissal or error.
- **Version label in menu bar menu**: "DeepFocus v1.0.4" always visible in the
  menu bar dropdown.

### Removed

- **Services submenu**: Removed unused macOS Services submenu.

## [1.0.3] - 2026-03-11

### Added

- **Version label in menu**: Menu bar menu now shows "DeepFocus v1.0.3" as a
  static label above "Check for Updates…" so you always know which version is running.
- **"Check for Updates…" in app menu**: The item now appears in the DeepFocus
  app menu (next to About DeepFocus) with a separator, in addition to the
  menu bar menu.
- **Reactive update title**: The update button title changes automatically —
  "Check for Updates…" normally, "Install Update…" when a new version is
  available, and back to "Check for Updates…" after dismissal or error.
- **Button disabled while busy**: The update button is disabled while Sparkle
  is actively checking or downloading, preventing duplicate requests.

### Removed

- **Services submenu**: Removed the unused macOS Services submenu from the app
  menu to reduce clutter.

## [1.0.2] - 2026-03-11

### Added

- **Auto-updater**: Integrated Sparkle 2.9.0 for automatic in-app update checks.
  DeepFocus will silently check for updates on launch and notify you when a new
  version is available. A "Check for Updates…" item is also available in the
  menu bar menu for manual checks. Updates are EdDSA-signed for security.

## [1.0.1] - 2026-03-11

### Fixed

- **Crash on macOS 26**: Mutating `NSPanel.styleMask` on a visible window while
  SwiftUI's constraint engine was mid-pass caused an uncaught exception in
  `_postWindowNeedsUpdateConstraints`, which AppKit escalated to `EXC_BREAKPOINT`
  via `_crashOnException:`. Fixed by creating the panel with a fixed
  `styleMask: [.resizable]` and controlling idle/active resize behavior solely
  via `minSize`/`maxSize` (locked to the current frame size when a session is
  active).

## [1.0.0] - 2026-03-11

### Added

**Core timer**
- Floating HUD panel (always-on-top, draggable) with large countdown display
- Start, pause, resume, and cancel controls
- Task name field with inline editing during active sessions
- Adjustable duration via ±1 min / ±5 min buttons
- Three built-in presets: Pomodoro (25 min), Long Focus (50 min), Deep Work (90 min)
- Menu bar icon showing timer symbol + remaining minutes while active
- System notification on timer completion
- HUD position persisted across launches

**App Blocker**
- Blocklist mode: block specific apps during a session
- Allowlist mode: only permit specific apps, block everything else
- Detects and blocks any app that gains focus during an active session
- Hides the blocked app and redirects focus to the last allowed app
- Falls back to raising the HUD when no allowed app is available
- Immediately blocks any disallowed app that is already focused when the timer starts
- Block counter and last-blocked app name shown on HUD during active sessions

**Block feedback**
- HUD shakes left-right (7-keyframe animation) on each block event
- Border flashes orange and fades back over ~800ms
- Toast label ("⛔ AppName blocked") fades in, holds 1.5s, fades out

**Timer strictness modes**
- Soft: cancel the timer freely at any time (default)
- Medium: must solve 3 math problems in a row (addition or multiplication) to cancel; wrong answer resets progress to zero; Enter key submits answer
- Hard: cancel button hidden entirely; normal quit blocked via `applicationShouldTerminate`; must use Force Quit (⌘⌥⎋) to exit

**Distribution**
- `create_dmg.sh`: Release build + `.dmg` creation, auto-copied to `~/Public/Drop Box` for network access

**Tests**
- XCUITest suite covering: blocklist focus redirect from another app, focus redirect from DeepFocus itself, allowlist blocks unlisted apps, allowlist permits listed apps, focus redirect verification (blocked app goes to `.runningBackground`), three blocked apps all redirect independently
