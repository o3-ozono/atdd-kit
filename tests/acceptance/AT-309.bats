#!/usr/bin/env bats
# @covers: scripts/retrospective.sh
# @covers: templates/docs/issues/retrospective.md
# @covers: skills/merging-and-deploying/SKILL.md
# @covers: skills/express/SKILL.md
# @covers: docs/retrospective-log.jsonl
#
# Acceptance Tests for Issue #309 -- Flow retrospective automation
# (metrics + feedback extraction)
# Corresponds to docs/issues/309-flow-retrospective-automation/acceptance-tests.md
#
# Anchor: docs/issues/309-flow-retrospective-automation/acceptance-tests.md
# Invariant assertions -- no version/date/line-count exact-pins (#289).
#
# SCOPE NOTE: This suite pins static file structure + lightweight execution.
# Script output contract details are in tests/test_retrospective_script.bats.
# Skill structure (calling point) details are in tests/test_retrospective_skill.bats.

bats_require_minimum_version 1.5.0

RETRO_SCRIPT="scripts/retrospective.sh"
RETRO_TEMPLATE="templates/docs/issues/retrospective.md"
SKILL_MERGE="skills/merging-and-deploying/SKILL.md"
SKILL_EXPRESS="skills/express/SKILL.md"
PLUGIN_JSON=".claude-plugin/plugin.json"
CHANGELOG="CHANGELOG.md"

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

# ---------------------------------------------------------------------------
# AT-309-1: Retrospective auto-start on completion trigger (FS-1 / CS-1)
# ---------------------------------------------------------------------------

@test "AT-309-1a: scripts/retrospective.sh exists" {
  # Given: a script that auto-starts retrospective after merge gate
  # When: checking for the file
  # Then: scripts/retrospective.sh exists
  local root
  root="$(repo_root)"
  [[ -f "${root}/${RETRO_SCRIPT}" ]] || {
    echo "FAIL: ${RETRO_SCRIPT} does not exist"
    return 1
  }
}

@test "AT-309-1b: retrospective.sh is executable" {
  # Given: scripts/retrospective.sh
  # When: checking execute permission
  # Then: execute bit is set
  local root
  root="$(repo_root)"
  [[ -x "${root}/${RETRO_SCRIPT}" ]] || {
    echo "FAIL: ${RETRO_SCRIPT} is not executable"
    return 1
  }
}

@test "AT-309-1c: retrospective.sh --help returns usage (exit 0)" {
  # Given: scripts/retrospective.sh exists
  # When: run with --help argument
  # Then: usage/help output is returned, exits 0
  local root
  root="$(repo_root)"
  run bash "${root}/${RETRO_SCRIPT}" --help
  [[ "$status" -eq 0 ]] || {
    echo "FAIL: retrospective.sh --help exited non-0 (status=${status})"
    echo "$output"
    return 1
  }
  echo "$output" | grep -qiE 'usage|help|issue|retrospective' || {
    echo "FAIL: retrospective.sh --help output has no usage information"
    echo "$output"
    return 1
  }
}

@test "AT-309-1d: CS-1 lightweight -- retrospective.sh has 0 LLM invocations (claude binary call / Workflow tool)" {
  # Given: CS-1 constraint of 0 LLM round-trips
  # When: inspecting retrospective.sh non-comment lines for LLM binary invocations
  # Then: 'claude ' (binary invocation) or 'Workflow' pattern has 0 non-comment hits
  local root
  root="$(repo_root)"
  # Strip comment lines (# lines are documentation, not invocations)
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE '\bclaude[[:space:]]|Workflow'; then
    echo "FAIL: retrospective.sh has LLM invocations (claude/Workflow) in non-comment lines -- CS-1 violation"
    grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" | grep -nE '\bclaude[[:space:]]|Workflow' || true
    return 1
  fi
}

@test "AT-309-1e: CS-1 lightweight -- retrospective.sh has 0 blocking prompts (read -p / AskUserQuestion)" {
  # Given: CS-1 non-interactive constraint
  # When: inspecting retrospective.sh non-comment lines
  # Then: 'read -p' (interactive prompt) or 'AskUserQuestion' has 0 non-comment hits
  # Note: 'IFS= read -r' (loop construct) is not a blocking prompt
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'read -p|AskUserQuestion'; then
    echo "FAIL: retrospective.sh has blocking prompts (read -p / AskUserQuestion) -- CS-1 violation"
    grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" | grep -nE 'read -p|AskUserQuestion' || true
    return 1
  fi
}

@test "AT-309-1f: CS-1 lightweight -- local aggregation completes within 5 seconds under stub gh" {
  # Given: gh stubbed for performance test
  # When: running retrospective.sh with stub gh
  # Then: SECONDS count <= 5
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  # shellcheck disable=SC2064
  trap "rm -rf '${tmpdir}'" RETURN

  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
case "${1:-}" in
  issue) echo '{}' ;;
  pr)    echo '{"number":1,"title":"stub-pr","additions":10,"deletions":5}' ;;
  *)     echo '{}' ;;
esac
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local start=$SECONDS
  PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>/dev/null || true
  local elapsed=$(( SECONDS - start ))

  [[ "$elapsed" -le 5 ]] || {
    echo "FAIL: retrospective.sh local aggregation took ${elapsed}s (limit: 5s)"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-309-2: express path skips retrospective (FS-1)
# ---------------------------------------------------------------------------

@test "AT-309-2a: retrospective call point exists only in merging-and-deploying SKILL.md" {
  # Given: retrospective sole entry point is merging-and-deploying tail step
  # When: checking for retrospective reference in merging-and-deploying SKILL.md
  # Then: reference is present
  local root
  root="$(repo_root)"
  grep -qiE 'retrospective' "${root}/${SKILL_MERGE}" || {
    echo "FAIL: ${SKILL_MERGE} has no retrospective reference"
    return 1
  }
}

@test "AT-309-2b: express SKILL.md has 0 retrospective invocations (structural skip)" {
  # Given: express does not pass through merging-and-deploying -- structural skip
  # When: inspecting skills/express/SKILL.md
  # Then: 0 retrospective invocations
  local root
  root="$(repo_root)"
  if grep -q 'retrospective' "${root}/${SKILL_EXPRESS}" 2>/dev/null; then
    local hits
    hits=$(grep -c 'retrospective' "${root}/${SKILL_EXPRESS}" 2>/dev/null)
    echo "FAIL: ${SKILL_EXPRESS} has ${hits} retrospective references (express must not invoke retrospective)"
    return 1
  fi
}

@test "AT-309-2c: merging-and-deploying SKILL.md states express structural-skip rationale" {
  # Given: express bypasses merging-and-deploying -> retrospective skipped structurally
  # When: inspecting SKILL.md around the retrospective section
  # Then: express bypass rationale is documented
  local root
  root="$(repo_root)"
  grep -qiE 'express.*skip|express.*structural|express.*not.*retrospective|express は.*retrospective' "${root}/${SKILL_MERGE}" || {
    echo "FAIL: ${SKILL_MERGE} does not document the express structural-skip rationale"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-309-3: Dialogue volume metrics aggregation (FS-2)
# ---------------------------------------------------------------------------

@test "AT-309-3a: retrospective.sh dry-run output contains turn count field" {
  # Given: session transcript exists or is absent (best-effort)
  # When: running retrospective.sh in dry-run mode
  # Then: output contains turns/turn-count/best-effort/transcript
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'turns|turn.count|best.effort|transcri' || {
    echo "FAIL: retrospective.sh --dry-run output has no turn count field"
    echo "output: $out"
    return 1
  }
}

@test "AT-309-3b: retrospective.sh dry-run output contains phase breakdown or best-effort note" {
  # Given: autopilot-log.jsonl absent (manual flow)
  # When: running retrospective.sh in dry-run mode
  # Then: output contains phase/best-effort/breakdown
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'phase|best.effort|breakdown' || {
    echo "FAIL: retrospective.sh --dry-run output has no phase breakdown or best-effort note"
    echo "output: $out"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-309-4: Token cost aggregation (harness primary source) (FS-3 / CS-2)
# ---------------------------------------------------------------------------

@test "AT-309-4a: retrospective.sh dry-run output contains token/cost field or best-effort note" {
  # Given: headless log absent (best-effort case)
  # When: running retrospective.sh in dry-run mode
  # Then: output contains token/cost/input/output/best-effort
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'token|cost|input|output|best.effort' || {
    echo "FAIL: retrospective.sh --dry-run output has no token/cost field or best-effort note"
    echo "output: $out"
    return 1
  }
}

@test "AT-309-4b: retrospective.sh excludes autopilot-log.jsonl as token primary source" {
  # Given: autopilot-log.jsonl real schema has no token field
  # When: inspecting retrospective.sh non-comment lines
  # Then: no executable code reads tokens from autopilot-log.jsonl
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'autopilot-log\.jsonl.*token|token.*autopilot-log\.jsonl'; then
    echo "FAIL: retrospective.sh has executable code reading tokens from autopilot-log.jsonl"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-309-5: Previous-run comparison with code-volume normalization (FS-4)
# ---------------------------------------------------------------------------

@test "AT-309-5a: retrospective.sh dry-run output contains normalized ratio or best-effort note" {
  # Given: stub gh returning PR diff line counts
  # When: running retrospective.sh in dry-run mode
  # Then: output contains ratio/normalized/diff/best-effort
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{"additions":100,"deletions":20}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'ratio|normalized|diff.*lines|best.effort' || {
    echo "FAIL: retrospective.sh --dry-run output has no normalized ratio or best-effort note"
    echo "output: $out"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-309-6: Friction points (user-flagged areas) extraction (FS-5)
# ---------------------------------------------------------------------------

@test "AT-309-6a: retrospective.sh dry-run output contains friction/gate classification or best-effort note" {
  # Given: no persistent signal (best-effort case)
  # When: running retrospective.sh in dry-run mode
  # Then: output contains friction/gate/requirements/design/merge/best-effort
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'friction|gate|requirements|design|merge.*gate|best.effort' || {
    echo "FAIL: retrospective.sh --dry-run output has no friction/gate classification or best-effort note"
    echo "output: $out"
    return 1
  }
}

@test "AT-309-6b: retrospective.sh does not reference in-memory rejectionFindings" {
  # Given: rejectionFindings is not available at retrospective execution time
  # When: inspecting retrospective.sh source (non-comment lines only)
  # Then: 0 references to rejectionFindings/implSeedFindings outside comments
  local root
  root="$(repo_root)"
  if grep -vE '^[[:space:]]*#' "${root}/${RETRO_SCRIPT}" 2>/dev/null | grep -qE 'rejectionFindings|implSeedFindings'; then
    echo "FAIL: retrospective.sh has rejectionFindings/implSeedFindings in non-comment lines"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-309-7: skill-fix candidate summary listing (FS-6)
# ---------------------------------------------------------------------------

@test "AT-309-7a: retrospective.sh dry-run output contains feedback_candidates/improvement section" {
  # Given: retrospective report needs improvement candidates section
  # When: running retrospective.sh in dry-run mode
  # Then: output contains candidates/feedback/skill-fix/improvement
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local out
  out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qiE 'candidates|feedback|skill.fix|improvement' || {
    echo "FAIL: retrospective.sh --dry-run output has no feedback_candidates/improvement section"
    echo "output: $out"
    return 1
  }
}

@test "AT-309-7b: retrospective.sh does not run gh issue create (no auto-routing)" {
  # Given: No Auto-Routing principle
  # When: inspecting retrospective.sh source
  # Then: 'gh issue create' is absent
  local root
  root="$(repo_root)"
  if grep -qE 'gh issue create' "${root}/${RETRO_SCRIPT}" 2>/dev/null; then
    echo "FAIL: retrospective.sh contains 'gh issue create' (auto-routing is forbidden)"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-309-8: Report output, cross-cutting log, all-channel sync (FS-7)
# ---------------------------------------------------------------------------

@test "AT-309-8a: retrospective.md template exists with all 5 metric sections" {
  # Given: templates/docs/issues/retrospective.md template
  # When: inspecting the file
  # Then: all 5 sections exist (turns/cost/comparison/friction/candidates)
  local root
  root="$(repo_root)"
  [[ -f "${root}/${RETRO_TEMPLATE}" ]] || {
    echo "FAIL: ${RETRO_TEMPLATE} does not exist"
    return 1
  }
  grep -qiE 'turns|dialogue|turn.count' "${root}/${RETRO_TEMPLATE}" || {
    echo "FAIL: ${RETRO_TEMPLATE} missing dialogue/turns section"
    return 1
  }
  grep -qiE 'cost|token' "${root}/${RETRO_TEMPLATE}" || {
    echo "FAIL: ${RETRO_TEMPLATE} missing cost section"
    return 1
  }
  grep -qiE 'comparison|normalized|ratio' "${root}/${RETRO_TEMPLATE}" || {
    echo "FAIL: ${RETRO_TEMPLATE} missing comparison/ratio section"
    return 1
  }
  grep -qiE 'friction|gate' "${root}/${RETRO_TEMPLATE}" || {
    echo "FAIL: ${RETRO_TEMPLATE} missing friction section"
    return 1
  }
  grep -qiE 'candidates|feedback|improvement' "${root}/${RETRO_TEMPLATE}" || {
    echo "FAIL: ${RETRO_TEMPLATE} missing candidates/feedback section"
    return 1
  }
}

@test "AT-309-8b: retrospective.sh --json-output produces valid JSON" {
  # Given: --json-output flag for cross-cutting JSONL
  # When: running retrospective.sh --json-output
  # Then: stdout is valid JSON object (verified by jq)
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{"additions":50,"deletions":10}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local json_out
  json_out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --json-output 2>/dev/null || true)
  echo "${json_out}" | jq . >/dev/null 2>&1 || {
    echo "FAIL: retrospective.sh --json-output is not valid JSON"
    echo "output: ${json_out}"
    return 1
  }
}

@test "AT-309-8c: retrospective.sh --json-output JSONL record has required keys" {
  # Given: stable JSONL schema (issue/pr/tokens/diff_lines/normalized_ratio/friction/feedback_candidates)
  # When: running retrospective.sh --json-output
  # Then: issue, tokens, friction, feedback_candidates keys are present
  local root
  root="$(repo_root)"

  local tmpdir
  tmpdir=$(mktemp -d)
  trap "rm -rf '${tmpdir}'" RETURN
  cat > "${tmpdir}/gh" << 'STUB'
#!/usr/bin/env bash
echo '{"additions":50,"deletions":10}'
exit 0
STUB
  chmod +x "${tmpdir}/gh"

  local json_out
  json_out=$(PATH="${tmpdir}:${PATH}" bash "${root}/${RETRO_SCRIPT}" --issue 1 --json-output 2>/dev/null || true)

  echo "${json_out}" | jq 'has("issue")' | grep -q true || {
    echo "FAIL: JSONL record missing 'issue' key"
    echo "output: ${json_out}"
    return 1
  }
  echo "${json_out}" | jq 'has("tokens")' | grep -q true || {
    echo "FAIL: JSONL record missing 'tokens' key"
    echo "output: ${json_out}"
    return 1
  }
  echo "${json_out}" | jq 'has("friction")' | grep -q true || {
    echo "FAIL: JSONL record missing 'friction' key"
    echo "output: ${json_out}"
    return 1
  }
  echo "${json_out}" | jq 'has("feedback_candidates")' | grep -q true || {
    echo "FAIL: JSONL record missing 'feedback_candidates' key"
    echo "output: ${json_out}"
    return 1
  }
}

@test "AT-309-8d: merging-and-deploying SKILL.md documents all-channel sync (terminal + Issue/PR comment)" {
  # Given: all-channel sync rule (workflow-overrides.md)
  # When: inspecting SKILL.md
  # Then: terminal+comment / both-channel / all-channel reference is present
  local root
  root="$(repo_root)"
  grep -qiE '(terminal|ターミナル).*(comment|コメント)|(comment|コメント).*(terminal|ターミナル)|both.channel|all.channel|全チャネル|両チャネル' "${root}/${SKILL_MERGE}" || {
    echo "FAIL: ${SKILL_MERGE} does not document all-channel sync (terminal + Issue/PR comment)"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-309-9: Version consistency (regression invariant)
# ---------------------------------------------------------------------------

@test "AT-309-9: plugin.json version matches CHANGELOG top release heading (invariant)" {
  # Given: feature PR (minor bump required)
  # When: comparing plugin.json version to CHANGELOG top heading
  # Then: they match (invariant assertion -- no exact-version pin #289)
  local root
  root="$(repo_root)"

  local plugin_ver changelog_ver
  plugin_ver=$(grep '"version"' "${root}/${PLUGIN_JSON}" | sed 's/.*"\([0-9][^"]*\)".*/\1/')
  changelog_ver=$(grep -E '^## \[[0-9]' "${root}/${CHANGELOG}" | head -1 | sed 's/## \[//;s/\].*//')

  [[ -n "$plugin_ver" ]] || {
    echo "FAIL: cannot extract version from plugin.json"
    return 1
  }
  [[ -n "$changelog_ver" ]] || {
    echo "FAIL: CHANGELOG.md has no [X.Y.Z] release heading"
    return 1
  }
  [[ "$plugin_ver" == "$changelog_ver" ]] || {
    echo "FAIL: plugin.json version (${plugin_ver}) != CHANGELOG top release (${changelog_ver})"
    return 1
  }
}

# ===========================================================================
# Behavioral scenarios (fixture injection) -- these exercise actual behavior,
# not keyword presence. The script computes REPO_ROOT from its own location,
# so we copy it into a temp repo and inject fixtures (worker-out.json,
# autopilot-log.jsonl, transcript jsonl, stub gh) to assert real output.
# ===========================================================================

# Copy retrospective.sh into a throwaway repo root so REPO_ROOT (= script/..)
# points at our fixture tree. HOME is overridden per-test for transcript fixtures.
_behavioral_temp_repo() {
  local t
  t=$(mktemp -d)
  mkdir -p "${t}/scripts" "${t}/docs/issues/1-demo"
  cp "$(repo_root)/${RETRO_SCRIPT}" "${t}/scripts/retrospective.sh"
  chmod +x "${t}/scripts/retrospective.sh"
  echo "$t"
}

# A stub gh that echoes '{}' (overridden inline where specific output is needed).
_behavioral_stub_gh() {
  local d
  d=$(mktemp -d)
  printf '#!/usr/bin/env bash\necho '\''{}'\''\nexit 0\n' > "${d}/gh"
  chmod +x "${d}/gh"
  echo "$d"
}

@test "AT-309-4-behavioral: headless worker-out.json usage yields numeric token output (FS-3)" {
  local t gh; t=$(_behavioral_temp_repo); gh=$(_behavioral_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  printf '{"usage":{"input_tokens":111,"output_tokens":222},"total_cost_usd":0.5}\n' > "${t}/worker-out.json"
  local out
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qE 'input=111' || { echo "FAIL: no input=111 in: $out"; return 1; }
  echo "$out" | grep -qE 'output=222' || { echo "FAIL: no output=222 in: $out"; return 1; }
}

@test "AT-309-3-behavioral: transcript jsonl user/assistant records counted as turns (FS-2)" {
  local t gh munged; t=$(_behavioral_temp_repo); gh=$(_behavioral_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  # Real Claude Code convention (#348): leading dash kept, both `/` and `.` -> `-`.
  # (The prior transform stripped the leading dash and left dots intact, matching
  # the old buggy script — so this fixture was self-consistent and masked the bug.)
  munged=$(echo "${t}" | sed 's|[/.]|-|g')
  mkdir -p "${t}/.claude/projects/${munged}"
  printf '{"type":"user"}\n{"type":"assistant"}\n{"type":"assistant"}\n' > "${t}/.claude/projects/${munged}/sess.jsonl"
  local out
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  echo "$out" | grep -qE 'turns: user=1 assistant=2 total=3' || { echo "FAIL: turns miscounted: $(echo "$out" | grep -i turns)"; return 1; }
}

@test "AT-309-6-behavioral: autopilot-log FAIL entries classify friction by gate (FS-5)" {
  local t gh; t=$(_behavioral_temp_repo); gh=$(_behavioral_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  cat > "${t}/docs/issues/1-demo/autopilot-log.jsonl" << 'LOG'
{"iteration":1,"step":"writing-plan-and-tests","verdict":"FAIL","fingerprint":"x","timestamp":"t"}
{"iteration":2,"step":"merging-and-deploying","verdict":"FAIL","fingerprint":"y","timestamp":"t"}
LOG
  local out
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --dry-run 2>&1 || true)
  local fr; fr=$(echo "$out" | grep -E '^friction:')
  echo "$fr" | grep -qE 'design=writing-plan-and-tests' || { echo "FAIL: design not classified: $fr"; return 1; }
  echo "$fr" | grep -qE 'merge=merging-and-deploying' || { echo "FAIL: merge not classified: $fr"; return 1; }
}

@test "AT-309-6b-behavioral: PR comments contribute rejection signal to friction (FS-5 (b))" {
  local t gh; t=$(_behavioral_temp_repo); gh=$(mktemp -d)
  trap "rm -rf '${t}' '${gh}'" RETURN
  cat > "${gh}/gh" << 'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"pr view"* && "$*" == *"--comments"* ]]; then echo "needs-revision: please fix"; exit 0; fi
echo '{}'; exit 0
STUB
  chmod +x "${gh}/gh"
  local out
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --pr 7 --dry-run 2>&1 || true)
  echo "$out" | grep -E '^friction:' | grep -qiE 'rejection-related comments found' || { echo "FAIL: PR-comment friction not detected: $(echo "$out" | grep -i friction)"; return 1; }
}

@test "AT-309-5-behavioral: tokens + PR diff yield numeric normalized_ratio (FS-4)" {
  local t gh; t=$(_behavioral_temp_repo); gh=$(mktemp -d)
  trap "rm -rf '${t}' '${gh}'" RETURN
  printf '{"usage":{"input_tokens":100,"output_tokens":100},"total_cost_usd":0.1}\n' > "${t}/worker-out.json"
  cat > "${gh}/gh" << 'STUB'
#!/usr/bin/env bash
if [[ "$*" == *"pr view"* && "$*" == *"--json"* ]]; then echo '{"additions":10,"deletions":10}'; exit 0; fi
if [[ "$*" == *"pr list"* ]]; then echo "42 merged"; exit 0; fi
echo '{}'; exit 0
STUB
  chmod +x "${gh}/gh"
  local out ratio
  out=$(PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 --pr 42 --json-output 2>/dev/null || true)
  echo "$out" | jq . >/dev/null 2>&1 || { echo "FAIL: invalid JSON: $out"; return 1; }
  ratio=$(echo "$out" | jq -r '.normalized_ratio')
  [[ "$ratio" != "null" ]] || { echo "FAIL: normalized_ratio is null with tokens+diff present: $out"; return 1; }
  echo "$ratio" | grep -qE '^[0-9]+(\.[0-9]+)?$' || { echo "FAIL: ratio not numeric: $ratio"; return 1; }
}

@test "AT-309-8-behavioral: non-dry-run writes retrospective.md and append-only JSONL (FS-7)" {
  local t gh; t=$(_behavioral_temp_repo); gh=$(_behavioral_stub_gh)
  trap "rm -rf '${t}' '${gh}'" RETURN
  PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 >/dev/null 2>&1 || true
  [[ -f "${t}/docs/issues/1-demo/retrospective.md" ]] || { echo "FAIL: retrospective.md not written"; return 1; }
  [[ -f "${t}/docs/retrospective-log.jsonl" ]] || { echo "FAIL: cross-cutting JSONL not created"; return 1; }
  local n1 n2; n1=$(grep -c . "${t}/docs/retrospective-log.jsonl")
  PATH="${gh}:${PATH}" HOME="${t}" bash "${t}/scripts/retrospective.sh" --issue 1 >/dev/null 2>&1 || true
  n2=$(grep -c . "${t}/docs/retrospective-log.jsonl")
  [[ "$n2" -gt "$n1" ]] || { echo "FAIL: JSONL not append-only (${n1} -> ${n2})"; return 1; }
  while IFS= read -r ln; do
    echo "$ln" | jq . >/dev/null 2>&1 || { echo "FAIL: invalid JSONL line: $ln"; return 1; }
  done < "${t}/docs/retrospective-log.jsonl"
}
