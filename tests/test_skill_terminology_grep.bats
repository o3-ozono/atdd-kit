#!/usr/bin/env bats
# @covers: terminology policy (#222)
# AT-001: legacy skill testing terminology must not appear in active source.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# Excluded paths (semantics):
#   - CHANGELOG.md             : historical record (must keep "SAT" references)
#   - docs/testing-skills.md   : canonical doc that explicitly declares the
#                                legacy terms as deprecated
#   - docs/issues/222-*        : this Issue itself discusses the deprecated terms
#   - docs/issues/179-*        : parent epic that historically references SAT
#   - docs/issues/198-*        : D1+D2 統合 Issue that documents removal of the
#                                legacy SAT harness (must discuss old terms)
#   - tests/test_skill_terminology_grep.bats : this file (pattern strings)
PATTERN='SAT\b|Skill Acceptance|Fast layer|Integration layer|L1 BATS|L2 Fast|L3 Integration|BATS gate|Fast SAT|Integration SAT'

@test "AT-001: no legacy skill testing terminology in active source" {
  cd "$REPO_ROOT"
  hits=$(grep -rnE "$PATTERN" \
    --include='*.md' --include='*.sh' --include='*.bats' --include='*.yml' \
    --exclude-dir='.git' \
    --exclude='CHANGELOG.md' \
    --exclude='testing-skills.md' \
    --exclude-dir='222-skill-test-redesign' \
    --exclude-dir='179-atdd-kit-v1-redesign' \
    --exclude-dir='198-tests-claude-code-deprecation' \
    --exclude='test_skill_terminology_grep.bats' \
    . 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "Legacy terminology still present:"
    echo "$hits"
    return 1
  fi
}
