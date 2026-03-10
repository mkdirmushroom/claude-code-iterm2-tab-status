#!/usr/bin/env bash
# claude-code-iterm2-tab-status unified hook
# Handles both Notification and UserPromptSubmit events.
#   Notification(idle_prompt)       → writes signal with type "idle"
#   Notification(permission_prompt) → writes signal with type "attention"
#   UserPromptSubmit                → writes signal with type "running"
set -euo pipefail

STATUS_DIR="${CLAUDE_ITERM2_TAB_STATUS_DIR:-/tmp/claude-tab-status}"
mkdir -p "$STATUS_DIR"

# Read all of stdin
INPUT="$(cat)"

# Pure-bash JSON field extraction (no jq dependency).
# Handles flat JSON with string values. Not a full parser.
extract() {
  local key="$1"
  echo "$INPUT" | sed -n "s/.*\"${key}\": *\"\\([^\"]*\\)\".*/\\1/p" | head -1
}

# Extract fields
SESSION_ID="$(extract "session_id")"
if [[ -z "$SESSION_ID" ]]; then
  echo "hook.sh: no session_id found, skipping" >&2
  exit 0
fi

HOOK_EVENT="$(extract "hook_event_name")"

# Determine signal type based on event
if [[ "$HOOK_EVENT" == "UserPromptSubmit" ]]; then
  SIGNAL_TYPE="running"
  MESSAGE=""
else
  # Notification event — map notification_type to signal type
  NOTIF_TYPE="$(extract "notification_type")"
  case "$NOTIF_TYPE" in
    permission_prompt) SIGNAL_TYPE="attention" ;;
    *)                 SIGNAL_TYPE="idle" ;;
  esac
  MESSAGE="$(extract "message")"
fi

CWD="$(extract "cwd")"
PROJECT="$(basename "${CWD:-unknown}")"

# Find TTY and a stable PID by walking up the process tree.
# The stable PID is the process that owns the TTY (typically the login shell
# spawned by iTerm2), which stays alive for the tab's lifetime.
# Using $$ (the hook process PID) would cause the adapter's stale-signal
# cleanup to remove signals after 10s because the hook exits immediately.
# Called directly (not in a subshell) so TTY and PID are set in this shell.
TTY=""
PID="$$"
_find_tty_info() {
  local pid="$$"
  local depth=0
  while (( pid > 1 && depth < 15 )); do
    local tty_val
    tty_val="$(ps -o tty= -p "$pid" 2>/dev/null | tr -d ' ')" || true
    if [[ -n "$tty_val" && "$tty_val" != "??" && "$tty_val" != "-" ]]; then
      TTY="/dev/$tty_val"
      PID="$pid"
      # Keep walking — we want the highest ancestor with the TTY (login shell)
    fi
    pid="$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')" || break
    depth=$((depth + 1))
  done
}
_find_tty_info
TS="$(date +%s)"

# Escape double quotes in values to produce valid JSON
escape_json() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'; }

S_SID="$(escape_json "$SESSION_ID")"
S_TYPE="$(escape_json "$SIGNAL_TYPE")"
S_MSG="$(escape_json "$MESSAGE")"
S_PROJ="$(escape_json "$PROJECT")"
S_CWD="$(escape_json "$CWD")"
S_TTY="$(escape_json "$TTY")"

# Write signal file atomically (write to temp, then mv)
# Prevents the adapter from reading a partially-written file.
TMPFILE="$(mktemp "${STATUS_DIR}/.tmp.XXXXXX")"
cat > "$TMPFILE" <<SIGNAL
{
  "session_id": "${S_SID}",
  "type": "${S_TYPE}",
  "message": "${S_MSG}",
  "project": "${S_PROJ}",
  "cwd": "${S_CWD}",
  "tty": "${S_TTY}",
  "pid": "${PID}",
  "ts": "${TS}"
}
SIGNAL
mv "$TMPFILE" "${STATUS_DIR}/${SESSION_ID}.json"
