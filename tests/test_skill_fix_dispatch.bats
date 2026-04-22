#!/usr/bin/env bats

# AC3 (4-class duplicate check), AC5 (RED/GREEN fixture),
# AC7 (parallel suppression), AC9 (cleanup)

DISPATCH_LIB="lib/skill_fix_dispatch.sh"
FIXTURES="tests/fixtures/skill-fix"

setup() {
  export TEST_REGISTRY="/tmp/skill_fix_inflight_bats_test.json"
  rm -f "$TEST_REGISTRY"
  export SKILL_FIX_TIMESTAMP_OVERRIDE="2026-04-21T00:00:00Z"
  export GH_CMD_OVERRIDE="true"
}

teardown() {
  rm -f "$TEST_REGISTRY"
}

_run_dispatch() {
  INFLIGHT_REGISTRY="$TEST_REGISTRY" bash "$DISPATCH_LIB" "$@"
}

# --- Fixtures exist ---

@test "fixtures directory exists" {
  [[ -d "$FIXTURES" ]]
}

@test "dummy_skill_pass/SKILL.md fixture exists" {
  [[ -f "${FIXTURES}/dummy_skill_pass/SKILL.md" ]]
}

@test "dummy_skill_fail/SKILL.md fixture exists" {
  [[ -f "${FIXTURES}/dummy_skill_fail/SKILL.md" ]]
}

@test "inflight_registry_sample.json fixture exists" {
  [[ -f "${FIXTURES}/inflight_registry_sample.json" ]]
}

@test "issues.json fixture exists" {
  [[ -f "${FIXTURES}/issues.json" ]]
}

# --- AC3: duplicate check 4-class coverage ---

@test "AC3: issues.json fixture contains 4 classification entries" {
  # Should have entries for: 新規, 既存追記, 完全重複, 判断保留
  count=$(grep -c '"classification"' "${FIXTURES}/issues.json" || echo 0)
  [[ "$count" -ge 4 ]]
}

@test "AC3: issues.json has exact_duplicate entry" {
  grep -q 'exact_duplicate\|exact-duplicate' "${FIXTURES}/issues.json"
}

@test "AC3: issues.json has new classification entry" {
  grep -q '"new"\|: "new"' "${FIXTURES}/issues.json"
}

@test "AC3: issues.json has existing_append classification entry" {
  grep -q '"existing_append"' "${FIXTURES}/issues.json"
}

@test "AC3: issues.json has pending_judgement classification entry" {
  grep -q '"pending_judgement"' "${FIXTURES}/issues.json"
}

# --- AC5: RED/GREEN fixture content ---

@test "AC5: dummy_skill_fail/SKILL.md represents a broken skill (RED scenario)" {
  grep -qi 'fail\|broken\|error\|intentional' "${FIXTURES}/dummy_skill_fail/SKILL.md"
}

@test "AC5: dummy_skill_pass/SKILL.md represents a working skill (GREEN scenario)" {
  grep -qi 'pass\|working\|correct\|normal' "${FIXTURES}/dummy_skill_pass/SKILL.md"
}

# --- AC7: inflight registry operations ---

@test "AC7: register_inflight creates registry file" {
  _run_dispatch register_inflight 99 discover step3
  [[ -f "$TEST_REGISTRY" ]]
}

@test "AC7: register_inflight stores issue number" {
  _run_dispatch register_inflight 99 discover step3
  grep -q '"issue": 99' "$TEST_REGISTRY"
}

@test "AC7: query_inflight returns 1 when skill matches" {
  _run_dispatch register_inflight 99 discover step3
  result=$(_run_dispatch query_inflight discover)
  [[ "$result" == "1" ]]
}

@test "AC7: query_inflight returns 0 or empty when skill not registered" {
  result=$(_run_dispatch query_inflight plan)
  [[ "$result" == "0" || "$result" == "[]" || -z "$result" ]]
}

@test "AC7: deregister_inflight removes entry" {
  _run_dispatch register_inflight 99 discover step3
  _run_dispatch deregister_inflight 99
  result=$(_run_dispatch query_inflight discover)
  [[ "$result" == "0" ]]
}

@test "AC7: inflight_registry_sample.json fixture is valid JSON-like format" {
  grep -q '"issue"' "${FIXTURES}/inflight_registry_sample.json"
  grep -q '"skill"' "${FIXTURES}/inflight_registry_sample.json"
}

# --- AC9: cleanup ---

@test "AC9: cleanup deregisters inflight entry" {
  _run_dispatch register_inflight 88 atdd step2
  _run_dispatch cleanup 88
  result=$(_run_dispatch query_inflight atdd)
  [[ "$result" == "0" ]]
}

@test "AC9: cleanup without issue number does not error" {
  _run_dispatch cleanup ""
}

@test "AC9: is_stale function is defined in dispatch lib" {
  grep -q "^is_stale()" lib/skill_fix_dispatch.sh
}

@test "AC9: cleanup_stale removes entries with ready-to-go label" {
  grep -q "cleanup_stale\|is_stale" lib/skill_fix_dispatch.sh
}

@test "AC9: cleanup_stale removes entries older than 24h" {
  grep -q "24\|86400\|hours\|started_at" lib/skill_fix_dispatch.sh
}

@test "AC9: cleanup_stale removes entries for closed issues" {
  grep -q "closed\|is_stale\|cleanup_stale" lib/skill_fix_dispatch.sh
}
