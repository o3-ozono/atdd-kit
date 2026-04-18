#!/usr/bin/env bash
set -uo pipefail

# autopilot-worktree-guard.sh -- PreToolUse hook enforcing autopilot session
# file-write boundary.
#
# Gated by env var ATDD_AUTOPILOT_WORKTREE (absolute worktree path).
#   unset  -> no-op (exit 0, stdout "{}") -- Issue #111 AC6
#   set    -> block Edit/Write/MultiEdit/NotebookEdit file_path and Bash
#             mutating targets that resolve outside the worktree and are
#             not in the allow-list. Issue #111 AC2-AC5.
#
# Output contract:
#   allow: exit 0, stdout "{}"
#   block: exit 2, stderr "worktree=<W>\nviolating=<path>\n<guidance>"
#   fail-safe: any unexpected error -> exit 0 "{}" (never break tool flow)
#
# Delegates JSON + shlex + path canonicalization to the co-located
# autopilot_worktree_guard.py. Pure-bash is insufficient for shell-aware
# tokenization (e.g. `echo "a > b"` must not be treated as a redirect).

# AC6: env unset -> complete no-op, before touching stdin or python.
if [ -z "${ATDD_AUTOPILOT_WORKTREE:-}" ]; then
  cat >/dev/null 2>&1 || true
  echo '{}'
  exit 0
fi

HERE="$(cd "$(dirname "$0")" && pwd)"
PY_SCRIPT="$HERE/autopilot_worktree_guard.py"

if [ ! -f "$PY_SCRIPT" ]; then
  # Fail-safe: missing helper -> do not break tool flow.
  cat >/dev/null 2>&1 || true
  echo '{}'
  exit 0
fi

# Run python directly on stdin so the hook's stdin is delivered intact.
python3 "$PY_SCRIPT"
RC=$?

case "$RC" in
  0)
    exit 0
    ;;
  2)
    exit 2
    ;;
  *)
    # Python crashed or exited unexpectedly. Fail-safe allow.
    echo '{}'
    exit 0
    ;;
esac
