#!/usr/bin/env bats
# @covers: docs/testing-skills.md
# test_l4_docs.bats -- AC6: methodology and onboarding docs

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
TESTING_SKILLS_DOC="${REPO_ROOT}/docs/testing-skills.md"
CLAUDE_CODE_README="${REPO_ROOT}/tests/claude-code/README.md"

# --- docs/testing-skills.md ---

@test "docs/testing-skills.md exists" {
  [ -f "$TESTING_SKILLS_DOC" ]
}

@test "docs/testing-skills.md has fast vs integration layer section" {
  grep -qiE "fast.*(layer|layer)|integration.*(layer|layer)|fast.*vs.*integration|two.layer" "$TESTING_SKILLS_DOC"
}

@test "docs/testing-skills.md has jsonl analysis section" {
  grep -qiE "jsonl|analyze-token-usage|pricing|price.map" "$TESTING_SKILLS_DOC"
}

@test "docs/testing-skills.md has cost baseline" {
  grep -qE '\$0\.10|\$5|0\.10|5\.00' "$TESTING_SKILLS_DOC"
}

@test "docs/testing-skills.md has adding a new test section" {
  grep -qiE "add.*test|new.*test|adding.*test" "$TESTING_SKILLS_DOC"
}

@test "docs/testing-skills.md has linter WARN to FAIL escalation criteria" {
  grep -qiE "WARN.*FAIL|warn.*fail|escalat|upgra" "$TESTING_SKILLS_DOC"
}

# --- tests/claude-code/README.md ---

@test "tests/claude-code/README.md exists" {
  [ -f "$CLAUDE_CODE_README" ]
}

@test "tests/claude-code/README.md mentions --permission-mode bypassPermissions" {
  grep -q "bypassPermissions" "$CLAUDE_CODE_README"
}

@test "tests/claude-code/README.md mentions --add-dir" {
  grep -q "\-\-add-dir" "$CLAUDE_CODE_README"
}

@test "tests/claude-code/README.md mentions GH_TOKEN handling" {
  grep -q "GH_TOKEN" "$CLAUDE_CODE_README"
}

@test "tests/claude-code/README.md mentions python3" {
  grep -q "python3" "$CLAUDE_CODE_README"
}

@test "tests/claude-code/README.md mentions SIGINT or SIGTERM cleanup" {
  grep -qiE "SIGINT|SIGTERM|cleanup|interrupt" "$CLAUDE_CODE_README"
}

# --- tests/README.md updated ---

@test "tests/README.md mentions tests/claude-code/" {
  grep -q "claude-code" "${REPO_ROOT}/tests/README.md"
}
