#!/usr/bin/env bats
# @covers: docs/methodology/test-execution-policy.md
# @covers: skills/running-atdd-cycle/SKILL.md
# @covers: skills/reviewing-deliverables/SKILL.md
# @covers: skills/merging-and-deploying/SKILL.md
# Pins for phase-based test execution policy (AT-300/301/302/310/311/312)
# Issue #324

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
POLICY_DOC="${REPO_ROOT}/docs/methodology/test-execution-policy.md"

# ---------------------------------------------------------------------------
# AT-300: policy wording in flow skills
# ---------------------------------------------------------------------------

@test "AT-300: running-atdd-cycle SKILL.md contains impact-only policy wording" {
  grep -qE 'impact|--impact|affected only' "${REPO_ROOT}/skills/running-atdd-cycle/SKILL.md" || {
    echo "FAIL: skills/running-atdd-cycle/SKILL.md に影響範囲のみ実行ポリシーの文言がない"
    return 1
  }
}

@test "AT-300b: merging-and-deploying SKILL.md contains full-suite policy wording" {
  grep -qE '\-\-all|full suite|all tests' "${REPO_ROOT}/skills/merging-and-deploying/SKILL.md" || {
    echo "FAIL: skills/merging-and-deploying/SKILL.md に全件実行ポリシーの文言がない"
    return 1
  }
}

@test "AT-300c: test-execution-policy.md contains all three key policy terms" {
  # 「最終レビュー前=全件」「ATDD 各回=影響範囲のみ」「影響度基準」相当の英語文言が存在する
  grep -qiE 'all tests|full suite|--all' "${POLICY_DOC}" || {
    echo "FAIL: test-execution-policy.md に全件実行（all/full）ポリシーの記述がない"
    return 1
  }
  grep -qiE 'impact|affected|scope' "${POLICY_DOC}" || {
    echo "FAIL: test-execution-policy.md に影響範囲実行（impact/scope）ポリシーの記述がない"
    return 1
  }
  grep -qiE 'review|before.*review|pre.*review' "${POLICY_DOC}" || {
    echo "FAIL: test-execution-policy.md にレビュー前全件の文脈の記述がない"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-301: e2e impact-based integration
# ---------------------------------------------------------------------------

@test "AT-301: test-execution-policy.md integrates e2e into impact-based criteria" {
  grep -qiE 'e2e|live.*llm|live.*test' "${POLICY_DOC}" || {
    echo "FAIL: test-execution-policy.md に e2e テストの影響度基準統合の記述がない"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-302: reviewing-deliverables line budget
# ---------------------------------------------------------------------------

@test "AT-302: reviewing-deliverables SKILL.md is 240 lines or fewer" {
  local lines
  lines=$(wc -l < "${REPO_ROOT}/skills/reviewing-deliverables/SKILL.md")
  [[ "$lines" -le 240 ]] || {
    echo "FAIL: skills/reviewing-deliverables/SKILL.md が 240 行を超えている（${lines} 行）"
    return 1
  }
}

@test "AT-302b: reviewing-deliverables SKILL.md uses link reference for test-execution-policy" {
  grep -q 'test-execution-policy' "${REPO_ROOT}/skills/reviewing-deliverables/SKILL.md" || {
    echo "FAIL: skills/reviewing-deliverables/SKILL.md に test-execution-policy.md へのリンク参照がない"
    return 1
  }
}

# ---------------------------------------------------------------------------
# AT-311: English only language policy
# ---------------------------------------------------------------------------

@test "AT-311: test-execution-policy.md contains no Japanese characters" {
  [[ -f "${POLICY_DOC}" ]] || {
    echo "FAIL: docs/methodology/test-execution-policy.md が存在しない"
    return 1
  }
  if grep -P '[ぁ-んァ-ヶ一-龥]' "${POLICY_DOC}" >/dev/null 2>&1; then
    echo "FAIL: test-execution-policy.md に日本語文字が含まれている（English only 違反）"
    grep -P '[ぁ-んァ-ヶ一-龥]' "${POLICY_DOC}" | head -5
    return 1
  fi
}

# ---------------------------------------------------------------------------
# AT-312: README registration and Loaded-by meta
# ---------------------------------------------------------------------------

@test "AT-312a: docs/methodology/README.md has test-execution-policy.md in Documents table" {
  grep -q 'test-execution-policy' "${REPO_ROOT}/docs/methodology/README.md" || {
    echo "FAIL: docs/methodology/README.md に test-execution-policy.md が登録されていない"
    return 1
  }
}

@test "AT-312b: test-execution-policy.md starts with Loaded by meta-comment" {
  head -3 "${POLICY_DOC}" | grep -q '> \*\*Loaded by:\*\*' || {
    echo "FAIL: test-execution-policy.md の冒頭に '> **Loaded by:**' メタコメントがない"
    return 1
  }
}

@test "AT-312c: docs/methodology/README.md contains no Japanese characters" {
  if grep -P '[ぁ-んァ-ヶ一-龥]' "${REPO_ROOT}/docs/methodology/README.md" >/dev/null 2>&1; then
    echo "FAIL: docs/methodology/README.md に日本語文字が含まれている（English only 違反）"
    return 1
  fi
}
