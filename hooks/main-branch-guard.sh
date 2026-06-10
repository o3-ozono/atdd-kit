#!/usr/bin/env bash
set -uo pipefail

# main-branch-guard.sh -- PreToolUse hook that blocks edits of project-repo
# files whose worktree is on main/master
#
# This wrapper only does three things (#251): read the hook input, verify
# that git and python3 are available, and fail-safe. All decision logic
# lives in main_branch_guard.py, which resolves the *target file* against
# the project repository (the hook cwd's repo, compared via
# `git rev-parse --git-common-dir`) and the target-side worktree branch:
#   outside the project repo -> allow; target worktree not on main/master
#   -> allow; on main/master -> allow-list check -> deny.
#
# CS-1 (fail-safe): Any unexpected condition (git not in PATH, python3 not
# in PATH, missing helper, python crash, malformed stdin) returns {} exit 0.
#
# Registered in hooks/hooks.json as a plugin-level PreToolUse hook so that
# all projects using atdd-kit automatically receive this protection.

# --- Read hook input (fail-safe: ignore read errors) ---
INPUT=$(cat 2>/dev/null || true)

# --- Fail-safe: required commands must exist ---
if ! command -v git >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo '{}'
  exit 0
fi

# --- Delegate all decision logic to the Python helper ---
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
