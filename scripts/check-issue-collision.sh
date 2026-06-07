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
# This is a BEST-EFFORT, point-in-time advisory scan: it cannot prevent a true
# simultaneous-start race (TOCTOU). Treat a clean result as "no collision seen
# right now", not a hard guarantee.
#
# Usage:
#   check-issue-collision.sh --issue <N> [--self <path>] [--base <ref>]
#
# Options:
#   --issue <N>    Issue number to check (required, numeric).
#   --self <path>  The current worktree to exclude from the scan
#                  (default: git toplevel of $PWD).
#   --base <ref>   Base ref for the committed-work check. Default: auto-detect
#                  per worktree (origin/HEAD, else main/master/trunk).
#
# Exit codes:
#   0  no collision (safe to proceed)
#   1  collision detected (another worktree is already working Issue <N>)
#   3  usage / infra error
set -uo pipefail

usage() {
  cat <<'EOF'
check-issue-collision.sh — detect parallel work on the same Issue across git worktrees.

Usage:
  check-issue-collision.sh --issue <N> [--self <path>] [--base <ref>]

Options:
  --issue <N>    Issue number to check (required, numeric).
  --self <path>  Worktree to exclude from the scan (default: git toplevel of $PWD).
  --base <ref>   Base ref for the committed-work check (default: auto-detect).

Exit codes:
  0  no collision     1  collision detected     3  usage / infra error
EOF
}

OPT_ISSUE=""
OPT_SELF=""
OPT_BASE=""
OPT_BASE_SET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --issue)
      [ $# -ge 2 ] || { echo "ERROR: --issue requires a value" >&2; exit 3; }
      OPT_ISSUE="$2"; shift 2 ;;
    --self)
      [ $# -ge 2 ] || { echo "ERROR: --self requires a value" >&2; exit 3; }
      OPT_SELF="$2"; shift 2 ;;
    --base)
      [ $# -ge 2 ] || { echo "ERROR: --base requires a value" >&2; exit 3; }
      OPT_BASE="$2"; OPT_BASE_SET=1; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *) echo "ERROR: unknown argument: $1" >&2; exit 3 ;;
  esac
done

# --- Validate --issue (required, single-line numeric) ---
case "$OPT_ISSUE" in
  "") echo "ERROR: --issue <N> is required" >&2; exit 3 ;;
  *[!0-9]*) echo "ERROR: --issue must be numeric, got '$OPT_ISSUE'" >&2; exit 3 ;;
esac
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
  ( cd -- "$1" 2>/dev/null && pwd -P ) || printf '%s' "$1"
}
SELF_REAL="$(_realpath "$SELF")"

# Paths under docs/issues/ that belong to Issue N: bare "<N>/" or slugged "<N>-...".
# Anchored to a path boundary (start-of-line or after a space/slash) so that an
# unrelated substring like "mydocs/issues/<N>/" or "old-docs/issues/<N>/" does
# NOT false-positive. The trailing [/-] guard prevents 197 matching 1970.
ISSUE_RE="(^|[ /])docs/issues/${N}[/-]"

# Resolve the base ref for the committed-work check in a given worktree.
# Explicit --base wins; else origin/HEAD; else the first existing of main/master/trunk.
resolve_base() {
  local wt="$1" ref b
  if [ "$OPT_BASE_SET" -eq 1 ]; then printf '%s' "$OPT_BASE"; return; fi
  ref="$(git -C "$wt" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"
  if [ -n "$ref" ]; then printf '%s' "$ref"; return; fi
  for b in main master trunk; do
    if git -C "$wt" rev-parse --verify --quiet "$b" >/dev/null 2>&1; then
      printf '%s' "$b"; return
    fi
  done
  printf '%s' ""
}

# --- Enumerate worktrees (from self's git dir) ---
WT_LIST="$(git -C "$SELF" worktree list --porcelain 2>/dev/null || true)"
if [ -z "$WT_LIST" ]; then
  exit 0  # not a git repo / no worktrees → nothing to collide with
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

  # (a) uncommitted / staged / untracked changes under docs/issues/<N>/.
  # --untracked-files=all lists individual untracked files instead of collapsing
  # them to the top untracked dir (e.g. "?? docs/"), so nested new files match.
  status_out="$(git -C "$wt" status --porcelain --untracked-files=all 2>/dev/null)"
  status_rc=$?
  if [ "$status_rc" -ne 0 ]; then
    echo "WARNING: could not inspect worktree '$wt' (git status exit $status_rc); collision check is best-effort and may miss a real collision here." >&2
  fi
  if printf '%s\n' "$status_out" | grep -qE "$ISSUE_RE"; then
    hit="yes"
  fi

  # (b) committed work ahead of base touching docs/issues/<N>/
  if [ -z "$hit" ]; then
    base="$(resolve_base "$wt")"
    if [ -n "$base" ] && git -C "$wt" rev-parse --verify --quiet "$base" >/dev/null 2>&1; then
      diff_out="$(git -C "$wt" diff --name-only "${base}...HEAD" 2>/dev/null)"
      if printf '%s\n' "$diff_out" | grep -qE "$ISSUE_RE"; then
        hit="yes"
      fi
    else
      echo "WARNING: could not resolve a base ref for worktree '$wt'; committed-work collision check skipped (best-effort). Pass --base <ref> to force." >&2
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
