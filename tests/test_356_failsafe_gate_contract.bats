#!/usr/bin/env bats
# @covers: scripts/run-tests.sh skills/merging-and-deploying/SKILL.md docs/methodology/test-execution-policy.md
# #356 pre-merge failsafe gate contract redefinition -- doc/skill structural pins
# FS2 / CS2 / CS3 / CS4 acceptance criteria (red->green: red before impl because asserted content is absent)

bats_require_minimum_version 1.5.0

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
MERGING="${REPO_ROOT}/skills/merging-and-deploying/SKILL.md"
RUN_TESTS="${REPO_ROOT}/scripts/run-tests.sh"
POLICY="${REPO_ROOT}/docs/methodology/test-execution-policy.md"
AT210F_SRC="${REPO_ROOT}/docs/issues/324-test-speedup/acceptance-tests.md"
PR_YML="${REPO_ROOT}/.github/workflows/pr.yml"

# FS2: impact-selected e2e wired into merge gate
@test "AT-356-3: merge gate wires run-skill-e2e.sh --changed-files" {
  grep -q 'run-skill-e2e.sh --changed-files' "$MERGING" || {
    echo "FAIL: merging-and-deploying に影響選択 e2e（run-skill-e2e.sh --changed-files）の配線記述が無い"
    return 1
  }
}

# CS2: e2e impact-selected, not forced full; auth-absent policy documented
@test "AT-356-4: merge gate e2e is impact-selected not forced --all and auth-absent policy documented" {
  grep -q 'run-skill-e2e.sh --changed-files' "$MERGING" || {
    echo "FAIL: 影響選択（--changed-files）記述が無い"
    return 1
  }
  ! grep -q 'run-skill-e2e.sh --all' "$MERGING" || {
    echo "FAIL: merge gate で e2e 全件(run-skill-e2e.sh --all)が強制されている"
    return 1
  }
  grep -qE 'skip|スキップ' "$MERGING" && grep -q 'e2e' "$MERGING" || {
    echo "FAIL: e2e 認証不在時の skip 方針が記述されていない"
    return 1
  }
}

# CS3: docs aligned with implementation
@test "AT-356-5a: issue 324 AT-210f revised to acceptance recursive contract" {
  # 改訂は #356 マーカーで識別する（旧テキストへの誤マッチを避ける）
  grep -q '#356' "$AT210F_SRC" || {
    echo "FAIL: #324 acceptance-tests.md の AT-210f に #356 改訂注記が無い（acceptance/ 再帰収集への改訂未反映）"
    return 1
  }
}

@test "AT-356-5b: collect_all_bats comment aligned with acceptance inclusion" {
  ! grep -A6 'collect_all_bats()' "$RUN_TESTS" | grep -q 'maxdepth 1' || {
    echo "FAIL: collect_all_bats が依然 maxdepth 1（acceptance/ 除外）"
    return 1
  }
  grep -qE 'acceptance/.*(含む|再帰)|(含む|再帰).*acceptance/' "$RUN_TESTS" || {
    echo "FAIL: collect_all_bats コメントが acceptance/ 包含を説明していない"
    return 1
  }
}

@test "AT-356-5c: test-execution-policy.md aligned with new contract" {
  grep -q 'acceptance' "$POLICY" || {
    echo "FAIL: test-execution-policy.md が acceptance/ 包含の新契約に言及していない"
    return 1
  }
  grep -qE '影響選択|impact-selected|run-skill-e2e' "$POLICY" || {
    echo "FAIL: test-execution-policy.md が影響選択 e2e に言及していない"
    return 1
  }
}

# CS4: reuse existing logic, CI unchanged
@test "AT-356-6a: merge gate reuses run-skill-e2e.sh without reimplementing mapping" {
  grep -q 'run-skill-e2e.sh' "$MERGING" || {
    echo "FAIL: merge gate が run-skill-e2e.sh を再利用していない"
    return 1
  }
  ! grep -qE 'tests/e2e/.*\.bats.*->|skills/<X>' "$MERGING" || {
    echo "FAIL: merge gate に独自 e2e マッピングが再実装されている疑い"
    return 1
  }
}

@test "AT-356-6b: CI pr.yml recursive bats run unchanged" {
  grep -qE 'bats[[:space:]]+tests/' "$PR_YML" || {
    echo "FAIL: pr.yml の再帰 bats 実行（bats tests/ ...）が見当たらない"
    return 1
  }
}
