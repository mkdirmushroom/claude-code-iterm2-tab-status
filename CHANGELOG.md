# Changelog

## 0.1.0 — 2026-03-06

Initial open-source release as a Claude Code plugin.

- Three tab states: Running (⚡), Idle (💤), Attention (🔴)
- Unified hook script handles `UserPromptSubmit`, `Notification`, and `Stop` events
- TTY-based session matching with PID ancestry fallback
- Original tab color/title/badge save and restore
- Auto-contrast flash color selection
- PID liveness check cleans stale signals from dead sessions
- Per-state configurable prefixes and environment variable configuration (`CLAUDE_ITERM2_TAB_STATUS_*`)
- Auto-bootstrap: creates iTerm2 Python runtime on first session start
- `/setup` and `/uninstall` slash commands
- macOS notification and sound support (optional)
- Shell and Python unit tests
