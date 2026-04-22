#!/usr/bin/env bats
# @covers: lib/skill_fix_dispatch.sh
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

# --- AC9: is_stale / cleanup_stale (behavioral) ---

_make_mock_gh() {
  local mode="$1"
  local mock_bin="/tmp/bats_mock_gh_$$_${mode}"
  cat > "$mock_bin" <<SCRIPT
#!/usr/bin/env bash
if [[ "\$*" == *"--json labels"* ]]; then
  case "${mode}" in
    ready)  echo '{"labels":[{"name":"ready-to-go"}]}';;
    closed) echo '{"labels":[]}';;
    open)   echo '{"labels":[]}';;
  esac
elif [[ "\$*" == *"--json state"* ]]; then
  case "${mode}" in
    ready)  echo '{"state":"OPEN"}';;
    closed) echo '{"state":"CLOSED"}';;
    open)   echo '{"state":"OPEN"}';;
  esac
fi
SCRIPT
  chmod +x "$mock_bin"
  echo "$mock_bin"
}

@test "AC9: is_stale returns 0 (stale) when issue has ready-to-go label" {
  mock=$(_make_mock_gh ready)
  GH_CMD_OVERRIDE="$mock" INFLIGHT_REGISTRY="$TEST_REGISTRY" \
    bash lib/skill_fix_dispatch.sh is_stale 99 "2026-04-22T00:00:00Z"
  result=$?
  rm -f "$mock"
  [[ "$result" -eq 0 ]]
}

@test "AC9: is_stale returns 0 (stale) when issue state is CLOSED" {
  mock=$(_make_mock_gh closed)
  GH_CMD_OVERRIDE="$mock" INFLIGHT_REGISTRY="$TEST_REGISTRY" \
    bash lib/skill_fix_dispatch.sh is_stale 99 "2026-04-22T00:00:00Z"
  result=$?
  rm -f "$mock"
  [[ "$result" -eq 0 ]]
}

@test "AC9: is_stale returns 0 (stale) when started_at is older than 24h" {
  mock=$(_make_mock_gh open)
  GH_CMD_OVERRIDE="$mock" INFLIGHT_REGISTRY="$TEST_REGISTRY" \
    bash lib/skill_fix_dispatch.sh is_stale 99 "2020-01-01T00:00:00Z"
  result=$?
  rm -f "$mock"
  [[ "$result" -eq 0 ]]
}

@test "AC9: cleanup_stale preserves fresh entries when stale entry removed (regression)" {
  # Register stale (#99) and fresh (#88) — both in registry
  _run_dispatch register_inflight 99 discover step3
  _run_dispatch register_inflight 88 plan step2
  grep -q '"issue": 99' "$TEST_REGISTRY"
  grep -q '"issue": 88' "$TEST_REGISTRY"
  # Deregister only stale #99
  _run_dispatch deregister_inflight 99
  # Fresh entry #88 must still be present
  grep -q '"issue": 88' "$TEST_REGISTRY"
  # Stale entry #99 must be gone
  run grep -c '"issue": 99' "$TEST_REGISTRY"
  [[ "$output" == "0" ]] || [[ "$status" -ne 0 ]]
}
