#!/usr/bin/env bash
set -uo pipefail

# main-branch-guard.sh -- PreToolUse hook that blocks edits on main/master
#
# Denies Edit/Write/MultiEdit/NotebookEdit tool calls when the current git
# branch is exactly "main" or "master" (case-sensitive). All other conditions
# pass through with {} to ensure fail-safe behaviour.
#
# AC6 (fail-safe): Any unexpected condition (non-git directory, detached HEAD,
# git not in PATH, malformed stdin) returns {} + exit 0 without blocking.
#
# Registered in hooks/hooks.json as a plugin-level PreToolUse hook so that
# all projects using atdd-kit automatically receive this protection.

# --- Read hook input (fail-safe: ignore read errors) ---
INPUT=$(cat 2>/dev/null || true)

# --- Detect current branch (fail-safe) ---
BRANCH=$(git branch --show-current 2>/dev/null || true)

# Fail-safe: empty branch means detached HEAD, non-git dir, or git unavailable
if [ -z "$BRANCH" ]; then
  echo '{}'
  exit 0
fi

# --- Check if branch is main or master (case-sensitive exact match) ---
if [ "$BRANCH" != "main" ] && [ "$BRANCH" != "master" ]; then
  echo '{}'
  exit 0
fi

# --- Deny ---
escape_for_json() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  s="${s//$'\t'/\\t}"
  printf '%s' "$s"
}

REASON="main/master branch direct edits are not allowed. Please create a feature branch and use /atdd-kit:issue to open an Issue, then /atdd-kit:autopilot to implement via the Issue-driven workflow."
ESCAPED_REASON=$(escape_for_json "$REASON")

cat <<ENDJSON
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "${ESCAPED_REASON}"
  }
}
ENDJSON

exit 0
