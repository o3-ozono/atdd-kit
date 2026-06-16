#!/usr/bin/env bash
# hooks/branch-lease-guard.sh — PreToolUse hook: branch-lease guard
#
# Blocks write-back operations (git push / gh pr edit / gh pr merge / gh pr ready)
# on branches that have an open Draft PR and whose lease is held by another session.
#
# Two-layer protection (Issue #316):
#   Layer 1: session-start SKILL.md — Draft PRs are read-only / non-actionable.
#   Layer 2: this hook — hard-blocks the write-back tool at the PreToolUse level.
#
# Lease store:
#   BRANCH_LEASE_DIR (default /tmp/claude-branch-leases/) — shared across sessions.
#   File per branch: <branch-name-urlencoded> → JSON {session_id, timestamp}
#
# TTL:
#   BRANCH_LEASE_TTL_LOCAL (default 7200s / 2h)
#   BRANCH_LEASE_TTL_CI    (default 2400s / 40min, when GITHUB_ACTIONS is set)
#
# Override:
#   ATDD_BRANCH_LEASE_FORCE=1 — unconditionally allow (emergency escape hatch)
#
# Fail-safe (CS-1 principle): any unexpected condition (jq/git absent, malformed
# stdin, gh unavailable, etc.) returns {} + exit 0 (allow).

set -uo pipefail

# ── Constants ────────────────────────────────────────────────────────────────

LEASE_DIR="${BRANCH_LEASE_DIR:-/tmp/claude-branch-leases}"
TTL_LOCAL="${BRANCH_LEASE_TTL_LOCAL:-7200}"
TTL_CI="${BRANCH_LEASE_TTL_CI:-2400}"

# ── Helpers ──────────────────────────────────────────────────────────────────

emit_allow() {
  printf '{}\n'
}

emit_deny() {
  local reason="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$reason" \
      '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":$r}}'
  else
    # jq unavailable — inline manual JSON (reason is plain ASCII in practice)
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"%s"}}\n' "$reason"
  fi
}

# Encode a branch name to a safe filename (replace / and other unsafe chars).
encode_branch() {
  printf '%s' "$1" | sed 's|/|%2F|g; s| |%20|g'
}

# Return effective TTL based on CI detection.
effective_ttl() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    echo "$TTL_CI"
  else
    echo "$TTL_LOCAL"
  fi
}

# ── Write-back detection ──────────────────────────────────────────────────────
#
# Targeted operations only — git push, gh pr edit/merge/ready.
# Non-targeted: git checkout, git switch, git rebase (without push), local ops.

is_write_back() {
  local cmd="$1"
  # Strip leading whitespace
  cmd="${cmd#"${cmd%%[! ]*}"}"

  # git push (any form, including --force*)
  if printf '%s' "$cmd" | grep -qE '^git[[:space:]]+push([[:space:]]|$)'; then
    return 0
  fi

  # gh pr edit / merge / ready
  if printf '%s' "$cmd" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(edit|merge|ready)([[:space:]]|$)'; then
    return 0
  fi

  return 1
}

# ── Branch resolution ─────────────────────────────────────────────────────────
#
# For git push: extract explicit remote-branch arg if present, else use HEAD.
# For gh pr *: extract PR number/branch from --head / positional arg / current branch.
# Returns empty string on failure → caller should fail-safe.

resolve_branch_from_cmd() {
  local cmd="$1"

  # --- git push ---------------------------------------------------------------
  if printf '%s' "$cmd" | grep -qE '^git[[:space:]]+push'; then
    # Try to find explicit <branch> or <remote> <branch> or <remote> HEAD:refs/heads/<branch>
    # Simple heuristic: last non-flag token after 'push'
    local args
    args=$(printf '%s' "$cmd" | sed 's/^git[[:space:]]*push[[:space:]]*//')
    # Remove flag-style tokens
    local candidate=""
    local tok
    for tok in $args; do
      case "$tok" in
        -*)
          : ;;  # skip flags
        *:*)
          # e.g. HEAD:refs/heads/mybranch or src:dest — take the rhs
          candidate="${tok##*:}"
          candidate="${candidate##refs/heads/}"
          ;;
        *)
          # Could be remote or branch; take the last one
          candidate="$tok"
          ;;
      esac
    done

    if [ -n "$candidate" ] && [ "$candidate" != "origin" ] && [ "$candidate" != "upstream" ]; then
      printf '%s' "$candidate"
      return 0
    fi

    # Fall back to current branch
    git branch --show-current 2>/dev/null || true
    return 0
  fi

  # --- gh pr edit / merge / ready ---------------------------------------------
  if printf '%s' "$cmd" | grep -qE '^gh[[:space:]]+pr[[:space:]]+(edit|merge|ready)'; then
    # Try --head <branch> flag
    local head_val
    head_val=$(printf '%s' "$cmd" | sed -n 's/.*--head[[:space:]]\+\([^[:space:]]*\).*/\1/p')
    if [ -n "$head_val" ]; then
      printf '%s' "$head_val"
      return 0
    fi

    # Try positional PR number → resolve branch via gh pr view
    local pr_num
    pr_num=$(printf '%s' "$cmd" | grep -oE '[0-9]+' | head -1)
    if [ -n "$pr_num" ] && command -v gh >/dev/null 2>&1; then
      local branch
      branch=$(gh pr view "$pr_num" --json headRefName --jq '.headRefName' 2>/dev/null || true)
      if [ -n "$branch" ]; then
        printf '%s' "$branch"
        return 0
      fi
    fi

    # Fall back to current branch
    git branch --show-current 2>/dev/null || true
    return 0
  fi

  return 1
}

# ── Open Draft PR check ───────────────────────────────────────────────────────

has_open_draft_pr() {
  local branch="$1"
  if ! command -v gh >/dev/null 2>&1; then
    return 1  # gh unavailable → fail-safe: assume no draft
  fi
  local result
  result=$(gh pr list --head "$branch" --state open --json isDraft \
    --jq '[.[] | select(.isDraft == true)] | length' 2>/dev/null || echo "0")
  [ "${result:-0}" -gt 0 ]
}

# ── Lease store ───────────────────────────────────────────────────────────────

lease_file() {
  local branch="$1"
  local encoded
  encoded=$(encode_branch "$branch")
  printf '%s/%s.json' "$LEASE_DIR" "$encoded"
}

read_lease() {
  local branch="$1"
  local lf
  lf=$(lease_file "$branch")
  if [ -f "$lf" ]; then
    cat "$lf" 2>/dev/null || true
  fi
}

write_lease() {
  local branch="$1"
  local session_id="$2"
  local now
  now=$(date +%s)
  mkdir -p "$LEASE_DIR"
  local lf
  lf=$(lease_file "$branch")
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg sid "$session_id" --argjson ts "$now" \
      '{"session_id":$sid,"timestamp":$ts}' > "$lf" 2>/dev/null || true
  else
    printf '{"session_id":"%s","timestamp":%s}\n' "$session_id" "$now" > "$lf" 2>/dev/null || true
  fi
}

delete_lease() {
  local branch="$1"
  local lf
  lf=$(lease_file "$branch")
  rm -f "$lf" 2>/dev/null || true
}

# Remove TTL-expired leases (orphan cleanup) at access time.
cleanup_stale_leases() {
  local ttl
  ttl=$(effective_ttl)
  local now
  now=$(date +%s)
  [ -d "$LEASE_DIR" ] || return 0
  local f
  for f in "$LEASE_DIR"/*.json; do
    [ -f "$f" ] || continue
    local ts=0
    if command -v jq >/dev/null 2>&1; then
      ts=$(jq -r '.timestamp // 0' "$f" 2>/dev/null || echo 0)
    else
      ts=$(grep -o '"timestamp":[0-9]*' "$f" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
    fi
    local age=$(( now - ts ))
    if [ "$age" -gt "$ttl" ]; then
      rm -f "$f" 2>/dev/null || true
    fi
  done
}

is_fresh_lease_from_other_session() {
  local branch="$1"
  local my_session="$2"

  cleanup_stale_leases

  local raw
  raw=$(read_lease "$branch")
  [ -z "$raw" ] && return 1  # no lease → not blocked

  local sid=""
  if command -v jq >/dev/null 2>&1; then
    sid=$(printf '%s' "$raw" | jq -r '.session_id // ""' 2>/dev/null || true)
  else
    sid=$(printf '%s' "$raw" | grep -o '"session_id":"[^"]*"' | cut -d'"' -f4 || true)
  fi

  [ -n "$sid" ] && [ "$sid" != "$my_session" ]
}

# ── Main ──────────────────────────────────────────────────────────────────────

main() {
  # Fail-safe: read stdin
  local input
  input=$(cat 2>/dev/null || true)
  [ -z "$input" ] && { emit_allow; exit 0; }

  # Fail-safe: require jq for JSON parsing (emit_deny can work without it, but
  # we need jq to reliably parse input; without it, fail-safe allow)
  if ! command -v jq >/dev/null 2>&1; then
    emit_allow
    exit 0
  fi

  # Fail-safe: require git
  if ! command -v git >/dev/null 2>&1; then
    emit_allow
    exit 0
  fi

  # Parse input
  local tool_name
  tool_name=$(printf '%s' "$input" | jq -r '.tool_name // ""' 2>/dev/null || true)
  local session_id
  session_id=$(printf '%s' "$input" | jq -r '.session_id // ""' 2>/dev/null || true)

  # Only intercept Bash tool calls
  [ "$tool_name" = "Bash" ] || { emit_allow; exit 0; }

  local cmd
  cmd=$(printf '%s' "$input" | jq -r '.tool_input.command // ""' 2>/dev/null || true)
  [ -z "$cmd" ] && { emit_allow; exit 0; }

  # Check if this is a write-back operation
  is_write_back "$cmd" || { emit_allow; exit 0; }

  # Override escape hatch
  if [ "${ATDD_BRANCH_LEASE_FORCE:-}" = "1" ]; then
    emit_allow
    exit 0
  fi

  # Resolve target branch
  local branch=""
  branch=$(resolve_branch_from_cmd "$cmd" 2>/dev/null || true)
  [ -z "$branch" ] && { emit_allow; exit 0; }

  # main/master always passes through
  case "$branch" in
    main|master) emit_allow; exit 0 ;;
  esac

  # If another session holds a fresh lease AND the branch has an open Draft PR → deny
  if is_fresh_lease_from_other_session "$branch" "$session_id"; then
    if has_open_draft_pr "$branch"; then
      local other_sid=""
      other_sid=$(read_lease "$branch" | jq -r '.session_id // "unknown"' 2>/dev/null || echo "unknown")
      emit_deny "branch-lease-guard: Branch '${branch}' has an open Draft PR and is currently claimed by session '${other_sid}'. Another session is working on this branch. Use ATDD_BRANCH_LEASE_FORCE=1 to override if you are sure this is safe."
      exit 0
    fi
  fi

  # Acquire lease for self if not already held
  if [ -n "$session_id" ]; then
    local my_lease
    my_lease=$(read_lease "$branch")
    local my_sid=""
    if [ -n "$my_lease" ] && command -v jq >/dev/null 2>&1; then
      my_sid=$(printf '%s' "$my_lease" | jq -r '.session_id // ""' 2>/dev/null || true)
    fi
    if [ "$my_sid" != "$session_id" ]; then
      write_lease "$branch" "$session_id"
    fi
  fi

  emit_allow
}

main
