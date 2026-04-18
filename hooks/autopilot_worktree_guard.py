#!/usr/bin/env python3
"""autopilot-worktree-guard: shared JSON/shlex/path logic for the hook.

Invoked by hooks/autopilot-worktree-guard.sh. Reads Claude Code hook JSON
on stdin. Requires ATDD_AUTOPILOT_WORKTREE env var to be set (the bash
wrapper short-circuits when unset, so this script assumes it is).

Exit codes:
  0 -> allow (stdout "{}")
  2 -> block (stderr contains worktree=<W>\\nviolating=<path>\\n<msg>)

Any unhandled exception -> exit 0 "{}" (fail-safe, never break tool flow).
"""

from __future__ import annotations

import json
import os
import shlex
import sys

ALLOW_PREFIXES = (
    "/tmp",
    "/var/folders",
    "/private/var/folders",
    "/private/tmp",
)
ALLOW_EXACT = ("/dev/null",)

MUTATING_COMMANDS = {
    "cp", "mv", "rm", "mkdir", "touch", "install", "tee", "ln",
}
REPO_META_COMMANDS = {"git", "gh"}


def _emit_allow() -> None:
    sys.stdout.write("{}")
    sys.exit(0)


def _emit_block(worktree: str, violating: str, detail: str = "") -> None:
    msg = (
        f"worktree={worktree}\n"
        f"violating={violating}\n"
        "autopilot-worktree-guard: write target is outside the autopilot "
        "worktree and not in the allow-list (/tmp, /var/folders, /dev/null, "
        "<W>/.git)."
    )
    if detail:
        msg += f"\ndetail: {detail}"
    sys.stderr.write(msg + "\n")
    sys.exit(2)


def _fail_safe() -> None:
    sys.stdout.write("{}")
    sys.exit(0)


def canonicalize(path: str, cwd: str) -> str:
    if not path:
        return path
    if path.startswith("~"):
        path = os.path.expanduser(path)
    if not os.path.isabs(path):
        path = os.path.join(cwd or os.getcwd(), path)
    return os.path.realpath(path)


def is_allowed(target: str, worktree: str) -> bool:
    if target in ALLOW_EXACT:
        return True
    if target == worktree:
        return True
    if target.startswith(worktree + os.sep):
        return True
    for pref_raw in ALLOW_PREFIXES:
        pref = os.path.realpath(pref_raw)
        if target == pref or target.startswith(pref + os.sep):
            return True
    return False


def extract_bash_targets(command: str):
    if not command:
        return None, None
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return None, None
    if not tokens:
        return None, None

    CHAIN_OPS = {";", "&&", "||", "|", "&"}
    sub_cmds = []
    current = []
    for tok in tokens:
        if tok in CHAIN_OPS:
            if current:
                sub_cmds.append(current)
                current = []
        else:
            current.append(tok)
    if current:
        sub_cmds.append(current)

    first_token = sub_cmds[0][0] if sub_cmds and sub_cmds[0] else None
    targets = []

    for sub in sub_cmds:
        if not sub:
            continue
        head = sub[0]
        if head in REPO_META_COMMANDS:
            continue

        # Redirect detection.
        i = 0
        while i < len(sub):
            tok = sub[i]
            if tok in (">", ">>"):
                if i + 1 < len(sub):
                    targets.append(sub[i + 1])
                i += 2
                continue
            # Numbered redirect like "2>", "2>>", "2>&1", "2>file"
            if len(tok) >= 2 and tok[0].isdigit():
                rest = tok[1:]
                if rest in (">", ">>"):
                    if i + 1 < len(sub):
                        targets.append(sub[i + 1])
                    i += 2
                    continue
                if rest.startswith(">&"):
                    # stream merge, no path target
                    i += 1
                    continue
                if rest.startswith(">"):
                    possible = rest.lstrip(">")
                    if possible:
                        targets.append(possible)
                    i += 1
                    continue
            if tok.startswith(">&"):
                i += 1
                continue
            i += 1

        if head in MUTATING_COMMANDS:
            args = sub[1:]
            non_flag = [a for a in args if not a.startswith("-")]
            if head in {"cp", "mv", "install", "ln"}:
                if non_flag:
                    targets.append(non_flag[-1])
            elif head in {"rm", "mkdir", "touch", "tee"}:
                targets.extend(non_flag)

    return first_token, targets


def main() -> None:
    raw = sys.stdin.read()
    worktree_raw = os.environ.get("ATDD_AUTOPILOT_WORKTREE", "")
    if not worktree_raw:
        _emit_allow()
    worktree = os.path.realpath(worktree_raw)

    try:
        data = json.loads(raw) if raw.strip() else {}
    except (json.JSONDecodeError, ValueError):
        _fail_safe()

    tool_name = data.get("tool_name", "")
    tool_input = data.get("tool_input", {}) or {}
    cwd = data.get("cwd", "") or worktree

    if tool_name in {"Edit", "Write", "MultiEdit", "NotebookEdit"}:
        fp = (
            tool_input.get("file_path")
            or tool_input.get("notebook_path")
            or ""
        )
        if not fp:
            _emit_allow()
        canon = canonicalize(fp, cwd)
        if is_allowed(canon, worktree):
            _emit_allow()
        _emit_block(worktree, canon, f"tool={tool_name}")

    if tool_name == "Bash":
        command = tool_input.get("command", "") or ""
        first, targets = extract_bash_targets(command)
        if first is None:
            _emit_allow()
        if first in REPO_META_COMMANDS:
            _emit_allow()
        if not targets:
            _emit_allow()
        for t in targets:
            canon = canonicalize(t, cwd)
            if not is_allowed(canon, worktree):
                _emit_block(
                    worktree, canon, f"tool=Bash command-head={first}"
                )
        _emit_allow()

    _emit_allow()


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise
    except Exception:  # noqa: BLE001 -- fail-safe is intentional
        _fail_safe()
