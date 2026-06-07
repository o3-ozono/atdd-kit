#!/usr/bin/env bash
# check-issue-collision.sh — detect parallel work on the same Issue across git worktrees.
#
# When multiple worktrees / sessions run in parallel, two of them writing the
# same Issue's deliverables (docs/issues/<N>/...) corrupts the 1-Issue=1-worktree
# discipline. This script scans every OTHER git worktree for in-progress work on
# Issue <N> — uncommitted/untracked changes OR commits ahead of the base branch
# touching docs/issues/<N>/ (or docs/issues/<N>-<slug>/) — and reports a
# collision so skill-gate can stop before a second session starts the same Issue.
#
# Usage:
#   check-issue-collision.sh --issue <N> [--self <path>] [--base <ref>]
#
# Options:
#   --issue <N>    Issue number to check (required, numeric).
#   --self <path>  The current worktree to exclude from the scan
#                  (default: git toplevel of $PWD).
#   --base <ref>   Base ref for the committed-work check (default: main).
#
# Exit codes:
#   0  no collision (safe to proceed)
#   1  collision detected (another worktree is already working Issue <N>)
#   3  usage / infra error
set -uo pipefail

OPT_ISSUE=""
OPT_SELF=""
OPT_BASE="main"

while [ $# -gt 0 ]; do
  case "$1" in
    --issue) OPT_ISSUE="${2:-}"; shift 2 ;;
    --self)  OPT_SELF="${2:-}";  shift 2 ;;
    --base)  OPT_BASE="${2:-}";  shift 2 ;;
    -h|--help)
      grep '^#' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 3 ;;
  esac
done

# --- Validate --issue (required, numeric) ---
if [ -z "$OPT_ISSUE" ]; then
  echo "ERROR: --issue <N> is required" >&2
  exit 3
fi
if ! printf '%s' "$OPT_ISSUE" | grep -qE '^[0-9]+$'; then
  echo "ERROR: --issue must be numeric, got '$OPT_ISSUE'" >&2
  exit 3
fi

N="$OPT_ISSUE"

# --- Resolve self worktree (excluded from the scan) ---
if [ -n "$OPT_SELF" ]; then
  SELF="$OPT_SELF"
else
  SELF="$(git rev-parse --show-toplevel 2>/dev/null || true)"
fi
if [ -z "$SELF" ] || [ ! -d "$SELF" ]; then
  echo "ERROR: cannot resolve self worktree (pass --self <path>)" >&2
  exit 3
fi

_realpath() {
  # Portable realpath (BSD/GNU). Falls back to the input if resolution fails.
  ( cd "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"
}
SELF_REAL="$(_realpath "$SELF")"

# Paths under docs/issues/ that belong to Issue N: bare "<N>/" or slugged "<N>-...".
# A trailing [/-] guard prevents prefix false-positives (197 vs 1970).
ISSUE_RE="docs/issues/${N}[/-]"

# --- Enumerate worktrees (from self's git dir) ---
WT_LIST="$(git -C "$SELF" worktree list --porcelain 2>/dev/null || true)"
if [ -z "$WT_LIST" ]; then
  # Not a git repo / no worktrees → nothing to collide with.
  exit 0
fi

found=0
while IFS= read -r line; do
  case "$line" in
    "worktree "*) ;;
    *) continue ;;
  esac
  wt="${line#worktree }"
  [ -d "$wt" ] || continue
  wt_real="$(_realpath "$wt")"
  [ "$wt_real" = "$SELF_REAL" ] && continue

  hit=""

  # (a) uncommitted / staged / untracked changes under docs/issues/<N>/
  # --untracked-files=all lists individual untracked files instead of collapsing
  # them to the top untracked dir (e.g. "?? docs/"), so nested new files match.
  status_out="$(git -C "$wt" status --porcelain --untracked-files=all 2>/dev/null || true)"
  if printf '%s\n' "$status_out" | grep -qE "$ISSUE_RE"; then
    hit="yes"
  fi

  # (b) committed work ahead of base touching docs/issues/<N>/
  if [ -z "$hit" ] && git -C "$wt" rev-parse --verify --quiet "$OPT_BASE" >/dev/null 2>&1; then
    diff_out="$(git -C "$wt" diff --name-only "${OPT_BASE}...HEAD" 2>/dev/null || true)"
    if printf '%s\n' "$diff_out" | grep -qE "$ISSUE_RE"; then
      hit="yes"
    fi
  fi

  if [ -n "$hit" ]; then
    echo "Issue #${N} is already in-progress in worktree ${wt}" >&2
    found=1
  fi
done <<< "$WT_LIST"

if [ "$found" -eq 1 ]; then
  echo "Resolve the parallel collision before starting Issue #${N}: finish or hand off the other worktree, or pick a different Issue." >&2
  exit 1
fi

exit 0
