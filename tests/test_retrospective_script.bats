#!/usr/bin/env bats
# @covers: scripts/retrospective.sh
# Unit tests for scripts/retrospective.sh (#309).
#
# Per docs/testing-skills.md, this is a Unit Test -- the script is invoked
# with stub gh to test output contracts without real network calls.
#
# Scope: output contract (each metric section), JSONL validity, auto-routing
# absence, and CS-1 lightweight invariants (LLM 0, blocking prompt 0, 5s limit).

bats_require_minimum_version 1.5.0

RETRO_SCRIPT="scripts/retrospective.sh"

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd
}

# Shared stub gh setup
setup_stub_gh() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"
  echo "$tmpdir"
}

# --- Existence + permissions ------------------------------------------------

@test "#309 existence: scripts/retrospective.sh exists" {
  local root
  root="$(repo_root)"
  [[ -f "${root}/${RETRO_SCRIPT}" ]]
}

@test "#309 permissions: scripts/retrospective.sh is executable" {
  local root
  root="$(repo_root)"
  [[ -x "${root}/${RETRO_SCRIPT}" ]]
}

# --- --help / usage ---------------------------------------------------------

@test "#309 usage: --help returns exit 0 with usage output" {
  local root
  root="$(repo_root)"
  run bash "${root}/${RETRO_SCRIPT}" --help
  [[ "$status" -eq 0 ]]
  echo "$output" | grep -qiE 'usage|help|issue|retrospective'
}

@test "#309 usage: missing --issue returns exit 1" {
  local root
  root="$(repo_root)"
  run bash "${root}/${RETRO_SCRIPT}"
  [[ "$status" -eq 1 ]]
}

# --- CS-1 lightweight invariants -------------------------------------------

@test "#309 CS-1: no LLM binary invocations in non-comment lines" {
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE '\bclaude[[:space:]]|Workflow'; then
    echo "FAIL: retrospective.sh calls LLM binary in non-comment lines -- CS-1 violation"
    return 1
  fi
}

@test "#309 CS-1: no blocking interactive prompts in non-comment lines" {
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'read -p|AskUserQuestion'; then
    echo "FAIL: retrospective.sh has blocking prompts -- CS-1 violation"
    return 1
  fi
}

@test "#309 CS-1: local aggregation completes within 5 seconds under stub gh" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  # shellcheck disable=SC2064
  trap "rm -rf '${tmpdir}'" RETURN

  local start=$SECONDS
  PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>/dev/null || true
  local elapsed=$(( SECONDS - start ))
  [[ "$elapsed" -le 5 ]] || {
    echo "FAIL: took ${elapsed}s (limit: 5s)"
    return 1
  }
}

# --- Output contract: all metric sections present in --dry-run ---

@test "#309 output: turns field in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'turns|turn.count|best.effort|transcri'
}

@test "#309 output: phase breakdown or best-effort in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'phase|best.effort|breakdown'
}

@test "#309 output: token/cost field or best-effort in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'token|cost|best.effort'
}

@test "#309 output: normalized ratio or best-effort in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'ratio|normalized|best.effort'
}

@test "#309 output: friction/gate or best-effort in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'friction|gate|best.effort'
}

@test "#309 output: feedback candidates section in dry-run output" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'candidates|feedback|skill.fix|improvement'
}

# --- JSONL valid record ----------------------------------------------------

@test "#309 JSONL: --json-output produces valid JSON" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --json-output 2>/dev/null || true)
  echo "$out" | jq . >/dev/null 2>&1 || {
    echo "FAIL: --json-output is not valid JSON: $out"
    return 1
  }
}

@test "#309 JSONL: record has issue, tokens, friction, feedback_candidates keys" {
  local root
  root="$(repo_root)"
  local tmpdir
  tmpdir=$(setup_stub_gh)
  trap "rm -rf '${tmpdir}'" RETURN

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --json-output 2>/dev/null || true)
  echo "$out" | jq 'has("issue")' | grep -q true
  echo "$out" | jq 'has("tokens")' | grep -q true
  echo "$out" | jq 'has("friction")' | grep -q true
  echo "$out" | jq 'has("feedback_candidates")' | grep -q true
}

# --- No Auto-Routing -------------------------------------------------------

@test "#309 no-auto-routing: gh issue create is absent from retrospective.sh" {
  local root
  root="$(repo_root)"
  if grep -qE 'gh issue create' "${root}/${RETRO_SCRIPT}" 2>/dev/null; then
    echo "FAIL: retrospective.sh contains 'gh issue create' (auto-routing is forbidden)"
    return 1
  fi
}

# --- Primary source: autopilot-log.jsonl excluded from token collection ---

@test "#309 token source: autopilot-log.jsonl excluded as token primary source (code level)" {
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'autopilot-log\.jsonl.*token|token.*autopilot-log\.jsonl'; then
    echo "FAIL: retrospective.sh executable code reads tokens from autopilot-log.jsonl"
    return 1
  fi
}

# --- No rejectionFindings reference ----------------------------------------

@test "#309 no transient refs: rejectionFindings/implSeedFindings absent from non-comment lines" {
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'rejectionFindings|implSeedFindings'; then
    echo "FAIL: retrospective.sh references transient rejectionFindings/implSeedFindings"
    return 1
  fi
}
