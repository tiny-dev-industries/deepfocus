# Changelog

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
