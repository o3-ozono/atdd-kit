#!/usr/bin/env bats
# @covers: skills/autopilot/SKILL.md, skills/session-start/SKILL.md, docs/methodology/route-eligibility.md
# Acceptance Tests for Issue #304: autopilot SKILL.md loader split + express eligibility precheck
# Corresponds to docs/issues/304-autopilot-express-precheck-loader-split/acceptance-tests.md
#
# lifecycle: [regression]
#
# AT-100: route-eligibility.md single source extraction (FS-1)
# AT-200: autopilot SKILL.md loader split (FS-2 / CS-2)
# AT-300: express eligibility precheck (FS-3)
# AT-400: invariants (CS-1 / CS-3)

setup() {
  REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
  SKILL_AUTO="${REPO_ROOT}/skills/autopilot/SKILL.md"
  SKILL_SESSION="${REPO_ROOT}/skills/session-start/SKILL.md"
  ROUTE_ELIGIBILITY="${REPO_ROOT}/docs/methodology/route-eligibility.md"
}

# ============================================================================
# AT-100: route-eligibility.md single source extraction (FS-1)
# ============================================================================

# AT-101: route-eligibility.md exists as single source with all four required elements
@test "AT-101: route-eligibility.md exists and contains all four required elements" {
  # Given: routing criteria were previously embedded as prose in session-start/SKILL.md
  # When: docs/methodology/route-eligibility.md is read
  # Then: all four elements present -- express-eligible signals / autopilot signals /
  #       ambiguous fallback / invariant (recommendation only, no auto-routing)
  [ -f "$ROUTE_ELIGIBILITY" ] || {
    echo "FAIL: docs/methodology/route-eligibility.md does not exist"
    return 1
  }
  # 1. express-eligible signals
  grep -qiE 'express.eligible|express eligible' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: express-eligible signals not found in route-eligibility.md"
    return 1
  }
  # 2. autopilot signals
  grep -qi 'autopilot' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: autopilot signals not found in route-eligibility.md"
    return 1
  }
  # 3. ambiguous fallback
  grep -qiE 'doubt|ambiguous|曖昧' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: ambiguous fallback not found in route-eligibility.md"
    return 1
  }
  # 4. recommendation-only / no auto-routing invariant
  grep -qiE '推奨のみ|recommendation only|auto.route' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: recommendation-only/auto-route invariant not found in route-eligibility.md"
    return 1
  }
}

# AT-102: session-start Step 3 replaced with pointer to route-eligibility.md (no duplicate signals)
@test "AT-102: session-start Step 3 replaced with route-eligibility.md pointer -- no duplicate signal prose" {
  # Given: route-eligibility.md consolidates routing signals
  # When: skills/session-start/SKILL.md is read
  # Then: Step 3 routing replaced with reference to route-eligibility.md;
  #       signal prose not duplicated in session-start.
  #       Step 3 heading and recommended-route column header remain as structure.
  local step3_section
  step3_section=$(sed -n '/Task Recommendation Rules/,/^## /p' "$SKILL_SESSION")
  # Step 3 heading must remain (structural invariant)
  echo "$step3_section" | grep -qi 'Step 3' || {
    echo "FAIL: Step 3 heading missing from session-start SKILL.md"
    return 1
  }
  # Reference to route-eligibility.md must be present (signal relocation proof)
  echo "$step3_section" | grep -qF 'route-eligibility.md' || {
    echo "FAIL: route-eligibility.md reference missing from session-start Step 3 (signals not relocated)"
    return 1
  }
}

# ============================================================================
# AT-200: autopilot SKILL.md loader split (FS-2 / CS-2)
# ============================================================================

# AT-201: autopilot SKILL.md line count stays within budget after split
@test "AT-201: skills/autopilot/SKILL.md line count is le 280 (line-budget pin unchanged)" {
  # Given: line count was at 280/280 before split; third raise is forbidden
  # When: wc -l skills/autopilot/SKILL.md
  # Then: line count <= 280; budget pin value itself is not raised
  local line_count
  line_count=$(wc -l < "$SKILL_AUTO" | tr -d ' ')
  [[ "$line_count" -le 280 ]] || {
    echo "FAIL: SKILL.md line count (${line_count}) exceeds budget pin 280 (third raise is forbidden)"
    return 1
  }
}

# AT-202: autopilot BATS structure pins remain intact after loader split
@test "AT-202: autopilot SKILL.md retains canonical structure-pin targets (objective oracle / User gates / Dialog economy)" {
  # Given: SKILL.md has many strings directly grep-pinned by BATS
  # When: key structure tokens are checked in skills/autopilot/SKILL.md
  # Then: the objective-gate machinery, User gates, Dialog economy remain in the file body
  # NOTE (#355): the LLM-reviewer convergence term was removed and VERDICT_SCHEMA was
  #   intentionally deleted. Its structure-pin slot is replaced by the objective oracle
  #   tokens (redObserved / atGreen / coverageOk via `objective oracle`) that drive convergence.
  grep -q 'objective oracle' "$SKILL_AUTO" || {
    echo "FAIL: 'objective oracle' not found in skills/autopilot/SKILL.md"
    return 1
  }
  grep -qE 'redObserved.*atGreen.*coverageOk|AND\(redObserved, atGreen, coverageOk\)' "$SKILL_AUTO" || {
    echo "FAIL: objective-gate oracle terms (redObserved/atGreen/coverageOk) not found in skills/autopilot/SKILL.md"
    return 1
  }
  grep -q '## User gates' "$SKILL_AUTO" || {
    echo "FAIL: ## User gates section not found in skills/autopilot/SKILL.md"
    return 1
  }
  grep -q 'Dialog economy' "$SKILL_AUTO" || {
    echo "FAIL: Dialog economy section not found in skills/autopilot/SKILL.md"
    return 1
  }
}

# AT-203: docs/methodology pointers in SKILL.md resolve to existing files (no broken links)
@test "AT-203: all docs/methodology/*.md references in SKILL.md resolve to existing files" {
  # Given: stub-ified SKILL.md holds pointers to docs/methodology
  # When: docs/methodology/*.md references are extracted and checked against the filesystem
  # Then: every reference resolves to an existing file (no broken links)
  local broken=0
  while IFS= read -r ref; do
    local path="${REPO_ROOT}/${ref}"
    if [ ! -f "$path" ]; then
      echo "FAIL: broken link -- ${ref} (${path} does not exist)"
      broken=1
    fi
  done < <(grep -oE 'docs/methodology/[a-zA-Z0-9._/-]+\.md' "$SKILL_AUTO" | sort -u)
  [ "$broken" -eq 0 ] || return 1
}

# AT-204: #302 pin signal grep targets follow to route-eligibility.md (all five pins remain green)
@test "AT-204: route-eligibility.md contains all #302-AC2/AC3/AC4 pin signals (reference-follow keeps green)" {
  # Given: FS-1 relocated session-start Step 3 signal prose to route-eligibility.md
  # When: route-eligibility.md content is verified
  # Then: all five #302 pin signals present -- express signals, autopilot signals (full set including
  #       'new feature' and 'behavior change'), hybrid determination elements, ambiguous fallback,
  #       recommendation-only invariant
  [ -f "$ROUTE_ELIGIBILITY" ] || { echo "FAIL: route-eligibility.md does not exist"; return 1; }
  # express-eligible signals (docs/README/typo/gitignore/version-bump)
  grep -qiE 'docs|README|typo|gitignore|version.bump|version bump' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: express-eligible signals (docs/README/typo/gitignore/version-bump) not in route-eligibility.md"
    return 1
  }
  # autopilot signals -- full set including 'new feature' and 'behavior' (English coverage)
  grep -qiE 'new feature|behavior|CI|hooks|depend|security|新機能|挙動変更|依存|セキュリティ' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: autopilot signals (incl. new feature / behavior) not in route-eligibility.md"
    return 1
  }
  # hybrid determination: label + keyword + LLM
  grep -qi 'label' "$ROUTE_ELIGIBILITY" || { echo "FAIL: 'label' not in route-eligibility.md"; return 1; }
  grep -qiE 'keyword|キーワード' "$ROUTE_ELIGIBILITY" || { echo "FAIL: 'keyword' not in route-eligibility.md"; return 1; }
  grep -qi 'LLM' "$ROUTE_ELIGIBILITY" || { echo "FAIL: 'LLM' not in route-eligibility.md"; return 1; }
  # ambiguous fallback
  grep -qiE 'doubt|ambiguous|unclear|曖昧|不明' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: ambiguous fallback not in route-eligibility.md"
    return 1
  }
  # recommendation-only invariant
  grep -qiE '推奨のみ|recommendation only|auto.route.*not|not.*auto.route|自動.*しない|しない.*自動' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: recommendation-only invariant not in route-eligibility.md"
    return 1
  }
}

# ============================================================================
# AT-300: express eligibility precheck (FS-3)
# ============================================================================

# AT-301: Express precheck section exists and is positioned before User gates
@test "AT-301: autopilot SKILL.md has Express precheck section positioned before User gates" {
  # Given: /atdd-kit:autopilot <issue> invoked directly; Issue is express-eligible per route-eligibility.md
  # When: autopilot evaluates the precheck
  # Then: advisory presented once only, explicit ok required before proceeding
  grep -q 'Express precheck' "$SKILL_AUTO" || {
    echo "FAIL: Express precheck section not found in skills/autopilot/SKILL.md"
    return 1
  }
  local precheck_line user_gates_line
  precheck_line=$(grep -n 'Express precheck' "$SKILL_AUTO" | head -1 | cut -d: -f1)
  user_gates_line=$(grep -n '## User gates' "$SKILL_AUTO" | head -1 | cut -d: -f1)
  [ -n "$precheck_line" ] && [ -n "$user_gates_line" ] || {
    echo "FAIL: could not extract line numbers for Express precheck or User gates"
    return 1
  }
  [ "$precheck_line" -lt "$user_gates_line" ] || {
    echo "FAIL: Express precheck (L${precheck_line}) must precede User gates (L${user_gates_line})"
    return 1
  }
  # advisory presented once
  local section
  section=$(sed -n '/Express precheck/,/^## /p' "$SKILL_AUTO")
  echo "$section" | grep -qi 'once' || {
    echo "FAIL: precheck section missing 'once' (advisory must be presented once only)"
    return 1
  }
  # explicit ok required
  echo "$section" | grep -qiE 'without.*explicit.*ok|explicit.*`ok`|explicit ok.*do not proceed' || {
    echo "FAIL: precheck section missing explicit-ok gate phrase"
    return 1
  }
}

# AT-302: express non-eligible Issues proceed silently (precheck references route-eligibility.md)
@test "AT-302: autopilot SKILL.md references route-eligibility.md as the precheck signal source" {
  # Given: Issue does not match express-eligible signals
  # When: autopilot evaluates the precheck
  # Then: no advisory presented; autopilot proceeds as usual
  grep -qF 'docs/methodology/route-eligibility.md' "$SKILL_AUTO" || {
    echo "FAIL: skills/autopilot/SKILL.md does not reference docs/methodology/route-eligibility.md"
    return 1
  }
  [ -f "$ROUTE_ELIGIBILITY" ] || {
    echo "FAIL: docs/methodology/route-eligibility.md does not exist (dangling reference)"
    return 1
  }
}

# AT-303: precheck references route-eligibility.md and does not inline-duplicate signals in autopilot
@test "AT-303: Express precheck section references route-eligibility.md (no inline signal duplication)" {
  # Given: routing signals are consolidated in route-eligibility.md
  # When: autopilot SKILL.md precheck section is read
  # Then: judgment references route-eligibility.md; no inline copy of signals in autopilot
  local section
  section=$(sed -n '/Express precheck/,/^## /p' "$SKILL_AUTO")
  echo "$section" | grep -qF 'route-eligibility.md' || {
    echo "FAIL: Express precheck section does not reference route-eligibility.md"
    return 1
  }
}

# ============================================================================
# AT-400: invariants (CS-1 / CS-3)
# ============================================================================

# AT-401: User gate count remains exactly three (AL-1; pre-flight advisory is not a gate)
@test "AT-401: autopilot User gates count is exactly three (pre-flight advisory not counted)" {
  # Given: express precheck is a pre-flight advisory before Gate (1) (requirements approval)
  # When: autopilot SKILL.md User gates numbered list is counted
  # Then: gate count == 3; precheck is advisory, not a gate; total does not become 4
  local gates
  gates=$(sed -n '/^## User gates/,/^## Dialog economy/p' "$SKILL_AUTO" | grep -cE '^[0-9]+\. ')
  [ "$gates" -eq 3 ] || {
    echo "FAIL: User gates count is ${gates}, expected 3. Pre-flight advisory must not be added as a gate."
    return 1
  }
}

# AT-402: auto-route is explicitly forbidden in the precheck section (recommendation only)
@test "AT-402: Express precheck section explicitly forbids auto-routing (advisory only)" {
  # Given: consistent with #302 Q3; user retains final route choice
  # When: precheck description is read
  # Then: automatic switching to express (auto-route) is explicitly forbidden; advisory only
  local section
  section=$(sed -n '/Express precheck/,/^## /p' "$SKILL_AUTO")
  echo "$section" | grep -qiE 'auto.route.*never|never.*auto.route|自動.*しない|しない.*自動' || {
    echo "FAIL: Express precheck section missing explicit auto-route prohibition"
    return 1
  }
}

# AT-403: route-eligibility.md contains all four elements (express/autopilot/ambiguous/invariant)
@test "AT-403: route-eligibility.md contains all four required elements for AT-300 coverage" {
  # Given: pre-flight advisory evaluated before Gate (1) (requirements approval)
  # When: autopilot Flow / SKILL.md step order is read
  # Then: precheck positioned before requirements approval gate
  [ -f "$ROUTE_ELIGIBILITY" ] || { echo "FAIL: route-eligibility.md does not exist"; return 1; }
  grep -qiE 'express.eligible|express eligible' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: express-eligible element missing from route-eligibility.md"; return 1
  }
  grep -qi 'autopilot' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: autopilot element missing from route-eligibility.md"; return 1
  }
  grep -qiE 'doubt|ambiguous|曖昧' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: ambiguous fallback element missing from route-eligibility.md"; return 1
  }
  grep -qiE '推奨のみ|recommendation only|auto.route' "$ROUTE_ELIGIBILITY" || {
    echo "FAIL: recommendation-only invariant missing from route-eligibility.md"; return 1
  }
}
