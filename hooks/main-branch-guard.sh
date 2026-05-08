#!/usr/bin/env bash
set -uo pipefail

# main-branch-guard.sh -- PreToolUse hook that blocks edits on main/master
#
# Checks the current git branch (case-sensitive exact match for "main" or
# "master"). On other branches or when branch detection fails, passes through
# with {} (fail-safe). On main/master, delegates to main_branch_guard.py which
# parses the hook JSON, canonicalizes file_path via realpath, and checks the
# allow-list. Allow -> {} exit 0, Deny -> deny JSON exit 0.
#
# AC6 (fail-safe): Any unexpected condition (non-git directory, detached HEAD,
# git not in PATH, python3 not in PATH, malformed stdin) returns {} + exit 0.
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

# --- Delegate to Python helper for allow-list check ---
HERE="$(cd "$(dirname "$0")" && pwd)"
PY_SCRIPT="$HERE/main_branch_guard.py"

if [ ! -f "$PY_SCRIPT" ]; then
  # Fail-safe: missing helper -> do not break tool flow.
  echo '{}'
  exit 0
fi

echo "$INPUT" | python3 "$PY_SCRIPT"
RC=$?

case "$RC" in
  0)
    exit 0
    ;;
  *)
    # Python crashed or exited unexpectedly. Fail-safe allow.
    echo '{}'
    exit 0
    ;;
esac
