#!/usr/bin/env bash
# skill_fix_dispatch.sh — dispatch / inflight registry / env scrubbing / cleanup
# for the skill-fix background subagent flow.
#
# Usage:
#   bash lib/skill_fix_dispatch.sh register_inflight <issue_n> <skill> <phase>
#   bash lib/skill_fix_dispatch.sh query_inflight [<skill> <phase>]
#   bash lib/skill_fix_dispatch.sh deregister_inflight <issue_n>
#   bash lib/skill_fix_dispatch.sh dispatch_subagent <parent_n> <new_n> <skill> <q3_info>
#   bash lib/skill_fix_dispatch.sh build_subagent_prompt <parent_n> <new_n> <skill> <q3_info>
#   bash lib/skill_fix_dispatch.sh build_env
#   bash lib/skill_fix_dispatch.sh check_completion <issue_n>
#   bash lib/skill_fix_dispatch.sh cleanup <issue_n> [<failure_reason>]
#
# Audit marker format (AC4 step 2):
#   <!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #<N> at <ISO-8601 timestamp> -->
#
# Env contract (AC8 — Spike-verified):
#   ATDD_AUTOPILOT_WORKTREE: NOT inherited (subagent uses its own isolated worktree)
#   CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1: inherited
#   GH_TOKEN: inherited

set -euo pipefail

INFLIGHT_REGISTRY="${INFLIGHT_REGISTRY:-${TMPDIR:-/tmp}/skill_fix_inflight.json}"
GH_CMD="${GH_CMD_OVERRIDE:-gh}"

# ---------------------------------------------------------------------------
# Audit marker (AC4 step 2)
# ---------------------------------------------------------------------------

_build_audit_marker() {
  local parent_n="$1"
  local timestamp
  timestamp="${SKILL_FIX_TIMESTAMP_OVERRIDE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"
  echo "<!-- skill-fix-audit: invoked via --skill-fix bypass from parent-issue #${parent_n} at ${timestamp} -->"
}

# ---------------------------------------------------------------------------
# Inflight registry (JSON file-based, AC7)
# ---------------------------------------------------------------------------

register_inflight() {
  local issue_n="$1"
  local skill="${2:-unknown}"
  local phase="${3:-unknown}"
  local timestamp
  timestamp="${SKILL_FIX_TIMESTAMP_OVERRIDE:-$(date -u +"%Y-%m-%dT%H:%M:%SZ")}"

  local entry="{\"issue\": ${issue_n}, \"skill\": \"${skill}\", \"phase\": \"${phase}\", \"started_at\": \"${timestamp}\"}"

  if [[ ! -f "$INFLIGHT_REGISTRY" ]]; then
    echo "[${entry}]" > "$INFLIGHT_REGISTRY"
  else
    local existing
    existing=$(cat "$INFLIGHT_REGISTRY")
    existing="${existing%]}"
    echo "${existing}, ${entry}]" > "$INFLIGHT_REGISTRY"
  fi
}

query_inflight() {
  local skill="${1:-}"
  local phase="${2:-}"

  if [[ ! -f "$INFLIGHT_REGISTRY" ]]; then
    echo "[]"
    return 0
  fi

  if [[ -z "$skill" ]]; then
    cat "$INFLIGHT_REGISTRY"
    return 0
  fi

  grep -o "\"skill\": \"${skill}\"" "$INFLIGHT_REGISTRY" >/dev/null 2>&1 && echo "1" || echo "0"
}

deregister_inflight() {
  local issue_n="$1"
  if [[ ! -f "$INFLIGHT_REGISTRY" ]]; then
    return 0
  fi
  sed -i.bak "/\"issue\": ${issue_n}/d" "$INFLIGHT_REGISTRY" 2>/dev/null || true
  rm -f "${INFLIGHT_REGISTRY}.bak"
}

# ---------------------------------------------------------------------------
# Env scrubbing (AC8)
# ---------------------------------------------------------------------------

build_env() {
  # ATDD_AUTOPILOT_WORKTREE: must NOT be passed (Spike-verified: unset in child)
  echo "ATDD_AUTOPILOT_WORKTREE_SCRUBBED=1"

  # CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS: inherited (Spike-verified: 1)
  echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-1}"

  # GH_TOKEN: inherited (Spike-verified: set)
  if [[ -n "${GH_TOKEN:-}" ]]; then
    echo "GH_TOKEN=${GH_TOKEN}"
  fi
}

# ---------------------------------------------------------------------------
# Subagent prompt builder (AC4 β strategy)
# ---------------------------------------------------------------------------

build_subagent_prompt() {
  local parent_n="$1"
  local new_n="$2"
  local skill="${3:-unknown}"
  local q3_info="${4:-}"

  local audit_marker
  audit_marker="$(_build_audit_marker "$parent_n")"

  cat <<EOF
You are a skill-fix subagent. Execute the following steps in order.
Do NOT use Agent tool (not available in subagent context). Use Skill tool chain only.

Parent issue: #${parent_n}
New issue: #${new_n}
Target skill: ${skill}

## Steps

1. Invoke /atdd-kit:issue via Skill tool → creates new issue and returns issue number.
   (If ${new_n} already set: skip creation.)

2. Append audit marker to issue #${new_n} body:
   Run: gh issue edit ${new_n} --body "\$(gh issue view ${new_n} --json body --jq .body)\n${audit_marker}"

3. Run target skill (${skill}) via Skill tool with blank context → collect RED baseline or GREEN fallback.
   - RED: document tool_uses, rationalizations, observed vs expected behavior
   - GREEN (not reproducible): document "独立再現不可" + Q3 info as alternative evidence
   Q3 info: ${q3_info}

4. Post evidence: gh issue comment ${new_n} --body "<evidence>"

5. Invoke /atdd-kit:discover ${new_n} --skill-fix via Skill tool.
   - AUTOPILOT-GUARD passes (--skill-fix flag accepted)
   - Step 7 user approval skipped
   - Step 8 inline plan mode forced
   - Quality gates (MUST-1/2/3, UX U1-U5, Interruption I1-I4) retained

6. If any quality gate FAIL:
   gh issue edit ${new_n} --add-label blocked-ac
   gh issue comment ${new_n} --body "blocked-ac: <reason>"
   EXIT (do not add ready-to-go)

7. If all gates PASS:
   gh issue edit ${new_n} --add-label ready-to-go

8. Observe label (ready-to-go / blocked-ac / closed) and exit normally.
EOF
}

# ---------------------------------------------------------------------------
# Subagent dispatch (AC4)
# Launched with isolation: worktree + run_in_background: true.
# worktree isolation prevents subagent from touching the main session branch.
# ---------------------------------------------------------------------------

dispatch_subagent() {
  local parent_n="$1"
  local new_n="$2"
  local skill="${3:-unknown}"
  local q3_info="${4:-}"

  register_inflight "$new_n" "$skill" "discover"
  build_subagent_prompt "$parent_n" "$new_n" "$skill" "$q3_info"
}

# ---------------------------------------------------------------------------
# Completion check (AC6)
# ---------------------------------------------------------------------------

check_completion() {
  local issue_n="$1"
  local url
  url="$($GH_CMD issue view "$issue_n" --json url --jq .url 2>/dev/null || echo "")"

  local labels
  labels="$($GH_CMD issue view "$issue_n" --json labels --jq '[.labels[].name]' 2>/dev/null || echo "[]")"

  if echo "$labels" | grep -q '"ready-to-go"'; then
    echo "skill-fix #${issue_n}: ready-to-go / link: ${url}"
  elif echo "$labels" | grep -q '"blocked-ac"'; then
    echo "skill-fix #${issue_n}: blocked-ac (phase=discover) / link: ${url}"
  fi
  # Not yet complete → print nothing
}

# ---------------------------------------------------------------------------
# Stale detection (AC9)
# An inflight entry is stale if:
#   (1) the issue has ready-to-go label, OR
#   (2) the issue is closed, OR
#   (3) started_at is older than 24h (86400 seconds)
# ---------------------------------------------------------------------------

is_stale() {
  local issue_n="$1"
  local started_at="${2:-}"

  # (1) ready-to-go label
  local labels
  labels="$($GH_CMD issue view "$issue_n" --json labels --jq '[.labels[].name]' 2>/dev/null || echo "[]")"
  if echo "$labels" | grep -q '"ready-to-go"\|"blocked-ac"'; then
    return 0
  fi

  # (2) closed
  local state
  state="$($GH_CMD issue view "$issue_n" --json state --jq .state 2>/dev/null || echo "")"
  if [[ "$state" == "CLOSED" ]]; then
    return 0
  fi

  # (3) 24h age check (started_at = ISO-8601)
  if [[ -n "$started_at" ]]; then
    local started_epoch now_epoch
    started_epoch=$(date -u -d "$started_at" +%s 2>/dev/null || date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$started_at" +%s 2>/dev/null || echo 0)
    now_epoch=$(date -u +%s)
    if (( now_epoch - started_epoch > 86400 )); then
      return 0
    fi
  fi

  return 1
}

# cleanup_stale — scan registry and deregister any stale entries
cleanup_stale() {
  if [[ ! -f "$INFLIGHT_REGISTRY" ]]; then
    return 0
  fi

  local content
  content=$(cat "$INFLIGHT_REGISTRY")

  # Extract issue numbers from registry (simple grep, JSON is single-level)
  local issues
  issues=$(grep -o '"issue": [0-9]*' "$INFLIGHT_REGISTRY" | grep -o '[0-9]*' || true)

  for issue_n in $issues; do
    local started_at
    # Extract started_at for this issue (grab next started_at after issue number)
    started_at=$(grep -A4 "\"issue\": ${issue_n}" "$INFLIGHT_REGISTRY" | grep '"started_at"' | grep -o '"[0-9T:Z-]*"' | tr -d '"' | head -1 || echo "")

    if is_stale "$issue_n" "$started_at"; then
      deregister_inflight "$issue_n"
    fi
  done
}

# ---------------------------------------------------------------------------
# Cleanup (AC9)
# ---------------------------------------------------------------------------

cleanup() {
  local issue_n="${1:-}"
  local failure_reason="${2:-}"

  if [[ -n "$issue_n" ]]; then
    deregister_inflight "$issue_n"

    if [[ -n "$failure_reason" ]]; then
      $GH_CMD issue comment "$issue_n" \
        --body "failed: ${failure_reason}" 2>/dev/null || true
    fi
  fi
}

# ---------------------------------------------------------------------------
# Dispatcher
# ---------------------------------------------------------------------------

fn="${1:-}"
shift || true

case "$fn" in
  register_inflight)     register_inflight "$@" ;;
  query_inflight)        query_inflight "$@" ;;
  deregister_inflight)   deregister_inflight "$@" ;;
  dispatch_subagent)     dispatch_subagent "$@" ;;
  build_subagent_prompt) build_subagent_prompt "$@" ;;
  build_env)             build_env "$@" ;;
  check_completion)      check_completion "$@" ;;
  cleanup)               cleanup "$@" ;;
  is_stale)              is_stale "$@" ;;
  cleanup_stale)         cleanup_stale "$@" ;;
  _build_audit_marker)   _build_audit_marker "$@" ;;
  "")
    echo "Usage: bash lib/skill_fix_dispatch.sh <function> [args...]" >&2
    exit 1
    ;;
  *)
    echo "Unknown function: $fn" >&2
    exit 1
    ;;
esac
