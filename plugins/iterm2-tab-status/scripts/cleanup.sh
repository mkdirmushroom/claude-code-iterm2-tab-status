#!/usr/bin/env bash
# claude-code-iterm2-tab-status cleanup hook
# Runs on SessionEnd to remove the signal file immediately,
# instead of waiting for the adapter's stale-PID grace period.
set -euo pipefail

STATUS_DIR="${CLAUDE_ITERM2_TAB_STATUS_DIR:-/tmp/claude-tab-status}"

INPUT="$(cat)"

# Extract session_id
SESSION_ID="$(echo "$INPUT" | sed -n 's/.*"session_id": *"\([^"]*\)".*/\1/p' | head -1)"

if [[ -n "$SESSION_ID" ]]; then
  rm -f "${STATUS_DIR}/${SESSION_ID}.json"
fi
