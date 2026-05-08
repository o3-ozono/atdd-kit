#!/usr/bin/env python3
"""main-branch-guard: path allow-list logic for the PreToolUse hook.

Invoked by hooks/main-branch-guard.sh when the current branch is main/master.
Reads Claude Code hook JSON on stdin. Checks file_path (or notebook_path for
NotebookEdit) against an allow-list. Allow → stdout "{}" exit 0. Deny → deny
JSON exit 0. Any unhandled exception → "{}" exit 0 (fail-safe).

Exit codes:
  0 -> allow (stdout "{}") or deny (stdout deny JSON)

Note: Unlike autopilot-worktree-guard.py this helper only uses exit 0 so the
sh wrapper does not need to distinguish exit codes.
"""

from __future__ import annotations

import json
import os
import sys

ALLOW_PREFIXES_STATIC = (
    "/tmp",
    "/var/folders",
    "/private/var/folders",
    "/private/tmp",
)
ALLOW_EXACT = ("/dev/null",)

TARGET_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

DENY_REASON = (
    "Direct edits on main/master are not allowed. "
    "Create a feature branch, open an Issue to track the work, "
    "and implement via the Issue-driven workflow."
)

DENY_JSON = json.dumps(
    {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": DENY_REASON,
        }
    }
)


def _emit_allow() -> None:
    sys.stdout.write("{}")
    sys.exit(0)


def _emit_deny() -> None:
    sys.stdout.write(DENY_JSON)
    sys.exit(0)


def _fail_safe() -> None:
    sys.stdout.write("{}")
    sys.exit(0)


def _home_prefixes() -> tuple[str, ...]:
    """Return allow-list prefixes derived from HOME at call time (lazy evaluation)."""
    home = os.path.expanduser("~")
    return (
        os.path.join(home, ".claude"),
        os.path.join(home, ".config"),
    )


def canonicalize(path: str, cwd: str) -> str:
    if not path:
        return path
    if path.startswith("~"):
        path = os.path.expanduser(path)
    if not os.path.isabs(path):
        path = os.path.join(cwd or os.getcwd(), path)
    return os.path.realpath(path)


def is_allowed(target: str) -> bool:
    if not target:
        return False
    if target in ALLOW_EXACT:
        return True
    # Static prefixes (resolve via realpath to handle macOS /tmp -> /private/tmp)
    for pref_raw in ALLOW_PREFIXES_STATIC:
        pref = os.path.realpath(pref_raw)
        if target == pref or target.startswith(pref + os.sep):
            return True
    # Home-relative prefixes evaluated at call time
    for pref in _home_prefixes():
        pref_real = os.path.realpath(pref)
        if target == pref_real or target.startswith(pref_real + os.sep):
            return True
    return False


def main() -> None:
    raw = sys.stdin.read()

    try:
        data = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        _fail_safe()
        return

    tool_name = data.get("tool_name", "")
    if tool_name not in TARGET_TOOLS:
        _emit_allow()

    tool_input = data.get("tool_input", {}) or {}
    cwd = data.get("cwd", "") or ""

    fp = tool_input.get("file_path") or tool_input.get("notebook_path") or ""
    if not fp:
        _emit_allow()

    canon = canonicalize(fp, cwd)
    if is_allowed(canon):
        _emit_allow()
    _emit_deny()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 -- fail-safe is intentional
        _fail_safe()
