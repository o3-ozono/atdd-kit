#!/usr/bin/env bash
# hooks/in-progress-label.sh — PostToolUse hook: in-progress label management
#
# Listens for gh pr create --draft (PostToolUse / Bash) and:
#   - on Draft PR creation: adds "in-progress" label to the linked Issue (F1)
#   - on PR close or merge:  removes "in-progress" label from the linked Issue (F3)
#
# Issue number resolution order (shared by F1/F3, DRY):
#   1. "--body" value containing "Closes #<N>"
#   2. Current branch name prefix "<N>-..."
#
# For close/merge, the PR branch (headRefName) is obtained via gh pr view when a PR
# number is available, otherwise falls back to git branch --show-current.
#
# Fail-safe (C3 / AC5 principle — mirrors bash-output-normalizer.sh):
#   Any unexpected condition (empty stdin, non-Bash tool_name, jq absent, gh absent,
#   malformed JSON, unresolvable issue number) exits 0 with no side effects.
#
# Idempotent (C2): gh issue edit --add-label / --remove-label are no-ops when the
# label is already present / already absent.

set -uo pipefail

# ── Fail-safe helpers ─────────────────────────────────────────────────────────

safe_exit() { exit 0; }

# ── Issue number resolution ───────────────────────────────────────────────────

# resolve_issue_number <cmd_string>
# Tries:
#   (1) "Closes #<N>" in the --body value of the command string
#   (2) Current branch name prefix "<N>-..."
# Returns the first matching integer, or empty string.
resolve_issue_number() {
  local cmd="$1"

  # (1) Closes #<N> in cmd (covers both --body and inline text)
  local from_body
  from_body=$(printf '%s' "$cmd" | grep -oE 'Closes[[:space:]]+#[0-9]+' | head -1 | grep -oE '[0-9]+' || true)
  if [ -n "$from_body" ]; then
    printf '%s' "$from_body"
    return 0
  fi

  # (2) branch name prefix <N>-...
  local branch
  branch=$(git branch --show-current 2>/dev/null || true)
  if [ -n "$branch" ]; then
    local from_branch
    from_branch=$(printf '%s' "$branch" | grep -oE '^[0-9]+' || true)
    if [ -n "$from_branch" ]; then
      printf '%s' "$from_branch"
      return 0
    fi
  fi

  # Unresolvable
  return 0
}

# resolve_issue_from_close_cmd <close/merge command string>
# Used during close/merge: tries PR number → gh pr view → headRefName → prefix.
# Falls back to git branch --show-current if gh unavailable or pr_num empty.
resolve_issue_from_close_cmd() {
  local cmd="$1"

  # Extract PR number from positional arg.
  # Handles both "gh pr close 324" and "gh pr merge --squash 324" (flags before number).
  # Strategy: confirm the command starts with gh pr close|merge, then scan all
  # whitespace-separated tokens for the first that is purely numeric (non-flag).
  local pr_num
  if printf '%s' "$cmd" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(close|merge)([[:space:]]|$)'; then
    pr_num=$(printf '%s' "$cmd" \
      | sed 's/^gh[[:space:]]*pr[[:space:]]*\(close\|merge\)[[:space:]]*//' \
      | tr ' \t' '\n' \
      | grep -E '^[0-9]+$' \
      | head -1 || true)
  fi

  if [ -n "$pr_num" ] && command -v gh >/dev/null 2>&1; then
    local head_branch
    head_branch=$(gh pr view "$pr_num" --json headRefName --jq '.headRefName' 2>/dev/null || true)
    if [ -n "$head_branch" ]; then
      local from_branch
      from_branch=$(printf '%s' "$head_branch" | grep -oE '^[0-9]+' || true)
      if [ -n "$from_branch" ]; then
        printf '%s' "$from_branch"
        return 0
      fi
    fi
  fi

  # Fallback: current branch prefix
  local branch
  branch=$(git branch --show-current 2>/dev/null || true)
  if [ -n "$branch" ]; then
    local from_branch
    from_branch=$(printf '%s' "$branch" | grep -oE '^[0-9]+' || true)
    [ -n "$from_branch" ] && printf '%s' "$from_branch"
  fi
  return 0
}

# ── Command classification ────────────────────────────────────────────────────

is_draft_create() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -qE '^gh[[:space:]]+pr[[:space:]]+create' || return 1
  printf '%s' "$cmd" | grep -qE '(^|[[:space:]])--draft([[:space:]]|$)' || return 1
  return 0
}

is_pr_close_or_merge() {
  local cmd="$1"
  printf '%s' "$cmd" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(close|merge)([[:space:]]|$)'
}

# ── Label operations ──────────────────────────────────────────────────────────

add_in_progress() {
  local issue="$1"
  # Idempotent: gh issue edit --add-label is no-op when label already present
  gh issue edit "$issue" --add-label "in-progress" 2>/dev/null || true
}

remove_in_progress() {
  local issue="$1"
  # Idempotent: gh issue edit --remove-label is no-op when label absent
  gh issue edit "$issue" --remove-label "in-progress" 2>/dev/null || true
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  # Fail-safe: read stdin
  local input
  input=$(cat 2>/dev/null || true)
  [ -z "$input" ] && safe_exit

  # Fail-safe: require jq
  command -v jq >/dev/null 2>&1 || safe_exit

  # Fail-safe: require gh
  command -v gh >/dev/null 2>&1 || safe_exit

  # Parse tool_name — only handle Bash
  local tool_name
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)
  [ "$tool_name" = "Bash" ] || safe_exit

  # Extract command from tool_input
  local cmd
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
  [ -z "$cmd" ] && safe_exit

  if is_draft_create "$cmd"; then
    local issue
    issue=$(resolve_issue_number "$cmd")
    [ -z "$issue" ] && safe_exit
    add_in_progress "$issue"
  elif is_pr_close_or_merge "$cmd"; then
    local issue
    issue=$(resolve_issue_from_close_cmd "$cmd")
    [ -z "$issue" ] && safe_exit
    remove_in_progress "$issue"
  fi

  safe_exit
}

main
