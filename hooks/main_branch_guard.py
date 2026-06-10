#!/usr/bin/env python3
"""main-branch-guard: project-repo × target-worktree-branch decision logic.

Invoked by hooks/main-branch-guard.sh for every Edit/Write/MultiEdit/
NotebookEdit PreToolUse event. Reads Claude Code hook JSON on stdin and
decides based on the *target file*, not the session cwd branch (#251):

  canonicalize file_path (or notebook_path), then
  (a) the hook cwd's git common dir cannot be resolved -> fail-safe allow
  (b) the target file's common dir cannot be resolved, or differs from the
      cwd's (file is outside the project repository) -> allow
  (c) common dirs match but the target-side worktree branch is not
      main/master (including detached HEAD = None) -> allow
  (d) target-side worktree is on main/master -> allow-list check;
      no match -> deny

Worktrees of one repository share the same git common dir, so comparing
`git rev-parse --git-common-dir` results identifies "same project repo"
across linked worktrees. Any unhandled exception -> "{}" exit 0 (fail-safe).

Exit codes:
  0 -> allow (stdout "{}") or deny (stdout deny JSON)

Note: This helper only uses exit 0 so the sh wrapper does not need to
distinguish exit codes.
"""

from __future__ import annotations

import json
import os
import subprocess
import sys

ALLOW_PREFIXES_STATIC = (
    "/tmp",
    "/var/folders",
    "/private/var/folders",
    "/private/tmp",
)
ALLOW_EXACT = ("/dev/null",)

TARGET_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

MAIN_BRANCHES = ("main", "master")

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


def _git(args: list[str], cwd: str) -> str | None:
    """Run `git -C <cwd> <args>` and return stripped stdout.

    Returns None on any failure: git not found, non-zero exit, timeout,
    or invalid cwd (fail-safe building block).
    """
    try:
        proc = subprocess.run(
            ["git", "-C", cwd, *args],
            capture_output=True,
            text=True,
            timeout=10,
        )
    except Exception:  # noqa: BLE001 -- git missing / timeout etc. -> None
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.strip()


def nearest_existing_dir(path: str) -> str:
    """Return the nearest existing ancestor directory of path's dirname.

    Supports Write of new files in not-yet-existing subdirectories: walk up
    from dirname(path) until an existing directory is found.
    """
    d = os.path.dirname(path)
    while d and not os.path.isdir(d):
        parent = os.path.dirname(d)
        if parent == d:
            break
        d = parent
    return d


def resolve_common_dir(dir_path: str) -> str | None:
    """Return the absolute, realpath'd git common dir for dir_path.

    `git rev-parse --git-common-dir` returns a *relative* path when run
    inside the main worktree (".git" at toplevel, "../.git" in a subdir) and
    an absolute path from a linked worktree (git 2.50.1 measured). The output
    must therefore be joined onto dir_path *before* realpath -- realpath
    alone would resolve relative output against this process's cwd.
    os.path.join ignores dir_path when the output is already absolute, so
    both forms are handled. Worktrees share the common dir, which makes the
    resolved value a same-repository key. Returns None when unresolvable.
    """
    if not dir_path or not os.path.isdir(dir_path):
        return None
    out = _git(["rev-parse", "--git-common-dir"], dir_path)
    if not out:
        return None
    return os.path.realpath(os.path.join(dir_path, out))


def branch_of(dir_path: str) -> str | None:
    """Return the current branch of dir_path's worktree.

    Empty output (detached HEAD) or any git failure -> None.
    """
    if not dir_path:
        return None
    out = _git(["branch", "--show-current"], dir_path)
    if not out:
        return None
    return out


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

    # (a) project repository = the repo of the hook cwd. Unresolvable
    #     (non-git cwd, git unavailable, missing cwd) -> fail-safe allow.
    cwd_common = resolve_common_dir(cwd)
    if cwd_common is None:
        _fail_safe()

    # (b) target outside the project repository (different or no common dir)
    #     -> allow. Guard scope is the project repo only (#251).
    target_dir = nearest_existing_dir(canon)
    target_common = resolve_common_dir(target_dir)
    if target_common is None or target_common != cwd_common:
        _emit_allow()

    # (c) target-side worktree branch decides, not the session cwd branch.
    #     Non-main/master (including detached HEAD = None) -> allow.
    branch = branch_of(target_dir)
    if branch not in MAIN_BRANCHES:
        _emit_allow()

    # (d) target is on main/master in the project repo -> allow-list check.
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
