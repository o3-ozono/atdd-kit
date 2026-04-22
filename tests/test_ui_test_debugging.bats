#!/usr/bin/env bats
# @covers: skills/ui-test-debugging/SKILL.md
# Tests for ui-test-debugging skill

SKILL="skills/ui-test-debugging/SKILL.md"

# --- AC1: CI failure log retrieval and failed test identification ---

@test "AC1: SKILL.md exists" {
  [[ -f "$SKILL" ]]
}

@test "AC1: has name in frontmatter" {
  grep -q '^name: ui-test-debugging' "$SKILL"
}

@test "AC1: has description in frontmatter" {
  grep -q '^description:' "$SKILL"
}

@test "AC1: references gh run view --log-failed" {
  grep -q 'gh run view.*--log-failed' "$SKILL"
}

@test "AC1: references Allure summary.json" {
  grep -q 'summary\.json' "$SKILL"
}

@test "AC1: references Allure test-results JSON" {
  grep -q 'test-results' "$SKILL"
}

@test "AC1: specifies Allure absent fallback" {
  grep -qi 'allure.*\(不在\|absent\|not.*\(exist\|available\|found\)\)' "$SKILL" || \
  grep -qi 'allure レポートなし' "$SKILL" || \
  grep -qi 'without allure\|allure.*unavailable\|allure.*fallback\|no allure' "$SKILL"
}

# --- AC2: CI-specific error classification and retry proposal ---

@test "AC2: has CI-specific error pattern table" {
  grep -q 'Failed to boot simulator' "$SKILL"
  grep -q 'time.*allowance\|timeout\|Timeout' "$SKILL"
  grep -q 'memory.*pressure\|memory pressure' "$SKILL"
}

@test "AC2: references gh run rerun --failed" {
  grep -q 'gh run rerun.*--failed' "$SKILL"
}

@test "AC2: specifies safe-side fallback for unclassified errors" {
  grep -qi 'unclassified\|未分類\|safe.*side\|安全側\|default.*local' "$SKILL"
}

# --- AC3: Local reproduction with sim-pool ---

@test "AC3: references -only-testing for targeted test execution" {
  grep -q '\-only-testing' "$SKILL"
}

@test "AC3: specifies max 3 retry attempts" {
  grep -q '3' "$SKILL"
}

@test "AC3: references sim-pool" {
  grep -qi 'sim-pool' "$SKILL"
}

@test "AC3: specifies sim-pool not configured fallback" {
  grep -qi 'sim-pool.*\(not.*\(configured\|set\)\|未設定\)' "$SKILL" || \
  grep -qi 'skip.*local.*repro\|ローカル再現.*スキップ' "$SKILL"
}

# --- AC4: Flaky detection ---

@test "AC4: defines flaky detection criteria (3 passes)" {
  grep -qi 'flak\|フレーキー' "$SKILL"
}

@test "AC4: proposes CI retry for flaky tests" {
  # Flaky section should mention retry
  grep -qi 'flak.*retry\|フレーキー.*リトライ\|retry.*flak' "$SKILL"
}

# --- AC5: Evidence collection and multimodal analysis ---

@test "AC5: references xcresulttool" {
  grep -q 'xcresulttool' "$SKILL"
}

@test "AC5: references screenshot extraction" {
  grep -qi 'screenshot\|スクリーンショット' "$SKILL"
}

@test "AC5: references Read tool for multimodal analysis" {
  grep -qi 'Read.*tool\|Read ツール\|multimodal\|マルチモーダル' "$SKILL"
}

@test "AC5: specifies xcresulttool unavailable fallback" {
  grep -qi 'xcresulttool.*\(unavailable\|不可\|not available\|fallback\)' "$SKILL" || \
  grep -qi 'without xcresulttool\|allure.*only\|Allure.*fallback' "$SKILL"
}

# --- AC6: Structured diagnostic report PR comment ---

@test "AC6: references gh pr comment" {
  grep -q 'gh pr comment' "$SKILL"
}

@test "AC6: has code bug required fields" {
  grep -qi 'RCA\|root cause' "$SKILL"
  grep -qi 'fix.*proposal\|修正提案\|修正案' "$SKILL"
}

@test "AC6: has report classification types" {
  grep -qi 'code.*bug\|コードバグ' "$SKILL"
  grep -qi 'flak\|フレーキー' "$SKILL"
  grep -qi 'infra\|インフラ' "$SKILL"
}

@test "AC6: has diagnostic report template" {
  grep -q 'UI Test' "$SKILL"
  grep -qi 'diagnostic\|診断' "$SKILL"
}

# --- General structure ---

@test "has HARD-GATE preventing fixes before diagnosis" {
  grep -q 'HARD-GATE' "$SKILL"
}

@test "description contains trigger conditions only (no workflow summary)" {
  desc=$(grep '^description:' "$SKILL" | sed 's/^description:[[:space:]]*//' | tr -d '"')
  # Should not contain step-by-step workflow description
  [[ ! "$desc" =~ "step" ]]
  [[ ! "$desc" =~ "then" ]]
  # Should be concise (under 200 chars)
  [[ ${#desc} -lt 200 ]]
}
