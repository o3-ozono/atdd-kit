#!/usr/bin/env bats
# @covers: scripts/session-lease-scan.sh skills/session-start/SKILL.md
# AT-343: session-start の「別セッション作業中」検出を branch-lease store ベースにする
# Issue #343
#
# lifecycle: [regression]

# ── ヘルパー ──────────────────────────────────────────────────────────────────

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

# テンポラリ BRANCH_LEASE_DIR にリース JSON を作成する。
# 引数: dir branch_name session_id timestamp
make_lease() {
  local dir="$1" branch="$2" sid="$3" ts="$4"
  local encoded
  encoded=$(printf '%s' "$branch" | sed 's|/|%2F|g; s| |%20|g; s|#|%23|g; s|\.|%2E|g; s|~|%7E|g')
  printf '{"session_id":"%s","timestamp":%s}\n' "$sid" "$ts" > "${dir}/${encoded}.json"
}

setup() {
  REPO="$(repo_root)"
  HELPER="${REPO}/scripts/session-lease-scan.sh"
  TMP_LEASE_DIR="$(mktemp -d)"
  NOW="$(date +%s)"
}

teardown() {
  rm -rf "$TMP_LEASE_DIR"
}

# ── AT-001: fresh な別セッション lease を保持する branch を検出する ──────────

@test "AT-343-01: helper detects branch with fresh lease" {
  # Given: テンポラリ BRANCH_LEASE_DIR に branch feat/x の lease（session_id 非空・timestamp = 現在）を 1 件用意する
  make_lease "$TMP_LEASE_DIR" "feat/x" "session-abc" "$NOW"
  # When: scripts/session-lease-scan.sh を実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: stdout に feat/x が 1 行出力され exit 0（検出は branch-lease store の fresh lease が根拠で Draft 状態に依存しない）
  [ "$status" -eq 0 ]
  [[ "$output" == "feat/x" ]]
}

# ── AT-002: lease が無い branch は検出しない ─────────────────────────────────

@test "AT-343-02: empty lease dir returns empty stdout and exit 0" {
  # Given: 空のテンポラリ BRANCH_LEASE_DIR
  # When: ヘルパを実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: stdout 空・exit 0
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── AT-003: 非 Draft・green・mergeable でも lease 保持 branch は検出される ───

@test "AT-343-03: branch with fresh lease detected regardless of PR draft status or CI state" {
  # Given: branch feat/ready の fresh 別セッション lease を用意する
  # （非 Draft・CI green・mergeable=MERGEABLE という状況は session-start が判断するもので
  #   ヘルパはそれに依存しない — lease が存在することだけで検出される）
  make_lease "$TMP_LEASE_DIR" "feat/ready" "session-xyz" "$NOW"
  # When: ヘルパを実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: stdout に feat/ready が含まれる（「非 Draft = ready = 推薦」「green = マージ」既定を上書きし、推薦対象から除外される根拠になる）
  [ "$status" -eq 0 ]
  [[ "$output" == *"feat/ready"* ]]
}

# ── AT-004: SKILL.md が lease 保持 PR を read-only 表示・推薦除外と明記する ──

@test "AT-343-04: SKILL.md references session-lease-scan and marks leased PRs as read-only" {
  # Given: skills/session-start/SKILL.md
  local skill="${REPO}/skills/session-start/SKILL.md"
  # When: Previous Work / Recommended Tasks / Task Recommendation Rules Step 1 を検査する
  [[ -f "$skill" ]] || { echo "FAIL: skills/session-start/SKILL.md does not exist"; return 1; }
  # Then: session-lease-scan を参照し、ヘルパ出力 branch の open PR を 別セッション作業中 として扱うと明記
  grep -q 'session-lease-scan' "$skill" || {
    echo "FAIL: SKILL.md has no reference to session-lease-scan"
    return 1
  }
  grep -q '別セッション作業中' "$skill" || {
    echo "FAIL: SKILL.md has no 別セッション作業中 marker"
    return 1
  }
}

# ── AT-005: Step 2.1 が lease 未保持を前提条件にする ─────────────────────────

@test "AT-343-05: CONFLICTING rebase recommendation requires branch not held by another session's lease" {
  # Given: skills/session-start/SKILL.md の Step 2.1（CONFLICTING rebase 推奨）
  local skill="${REPO}/skills/session-start/SKILL.md"
  [[ -f "$skill" ]] || { echo "FAIL: skills/session-start/SKILL.md does not exist"; return 1; }
  # When: 当該ルール本文を検査する
  # Then: lease 未保持（別セッション fresh lease を保持していない）が前提条件として明記
  grep -qE 'session-lease-scan|lease.*保持|lease.*含まれない|lease.*未保持' "$skill" || {
    echo "FAIL: SKILL.md CONFLICTING rule has no lease-not-held precondition"
    return 1
  }
  # AT-316 回帰: @me / 非 Draft 制限文言が維持されていること
  grep -q '@me' "$skill" || {
    echo "FAIL: SKILL.md missing @me restriction (AT-316 regression)"
    return 1
  }
  grep -qE 'ready|非 Draft|non.Draft' "$skill" || {
    echo "FAIL: SKILL.md missing ready (non-Draft) restriction (AT-316 regression)"
    return 1
  }
}

# ── AT-006: stale lease（TTL 超過）は検出しない ────────────────────────────

@test "AT-343-06: stale lease (TTL exceeded) is not detected" {
  # Given: branch feat/old の lease を timestamp = 現在 - (7200+60)s で用意する
  local stale_ts=$(( NOW - 7260 ))
  make_lease "$TMP_LEASE_DIR" "feat/old" "session-stale" "$stale_ts"
  # When: ヘルパを実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: stdout に feat/old を含まない（freshness 判定が BRANCH_LEASE_TTL_LOCAL 既定 7200s に従う）
  [ "$status" -eq 0 ]
  [[ "$output" != *"feat/old"* ]] || {
    echo "FAIL: stale lease was detected, should be skipped: $output"
    return 1
  }
}

# ── AT-007: TTL / encode を二重定義せずフックと同一 env・同一文字セットを使う

@test "AT-343-07: helper uses same env names and 5-char encode set as branch-lease-guard.sh" {
  # Given: scripts/session-lease-scan.sh と hooks/branch-lease-guard.sh
  [[ -f "$HELPER" ]] || { echo "FAIL: scripts/session-lease-scan.sh does not exist"; return 1; }
  # When: 両者の env 名と encode 文字セットを検査する
  # Then: ヘルパが BRANCH_LEASE_DIR / BRANCH_LEASE_TTL_LOCAL を同名で読む
  grep -q 'BRANCH_LEASE_DIR' "$HELPER" || {
    echo "FAIL: helper missing BRANCH_LEASE_DIR env"
    return 1
  }
  grep -q 'BRANCH_LEASE_TTL_LOCAL' "$HELPER" || {
    echo "FAIL: helper missing BRANCH_LEASE_TTL_LOCAL env"
    return 1
  }
  # encode が %2F %2E %20 %23 %7E の 5 文字セットを実装している
  for code in '%2F' '%2E' '%20' '%23' '%7E'; do
    grep -q "$code" "$HELPER" || {
      echo "FAIL: encode missing $code (5-char set incomplete)"
      return 1
    }
  done
  # 独自 TTL 既定（7200 以外）が無いことを確認
  local non_std_ttl
  non_std_ttl=$(grep -oE 'TTL[_A-Z]*:?=[^;$]*[0-9]+' "$HELPER" | grep -v '7200' || true)
  [ -z "$non_std_ttl" ] || {
    echo "FAIL: non-standard TTL default found: $non_std_ttl"
    return 1
  }
}

# ── AT-008: 検出は store を読むだけで write/delete しない ────────────────────

@test "AT-343-08: helper reads lease store without modifying it" {
  # Given: テンポラリ BRANCH_LEASE_DIR に既存 lease ファイル 1 件
  make_lease "$TMP_LEASE_DIR" "feat/ro" "session-ro" "$NOW"
  local before_files before_content
  before_files=$(ls "$TMP_LEASE_DIR")
  before_content=$(cat "${TMP_LEASE_DIR}/"*.json)
  # When: ヘルパを実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: 実行前後でファイル一覧・各ファイル内容が不変（fresh lease に対し write_lease / delete_lease を呼ばない）
  [ "$status" -eq 0 ]
  local after_files after_content
  after_files=$(ls "$TMP_LEASE_DIR")
  after_content=$(cat "${TMP_LEASE_DIR}/"*.json)
  [ "$before_files" = "$after_files" ] || {
    echo "FAIL: file list changed: before=$before_files after=$after_files"
    return 1
  }
  [ "$before_content" = "$after_content" ] || {
    echo "FAIL: file content changed"
    return 1
  }
}

# ── AT-009: store 未生成でも壊れず従来どおり ────────────────────────────────

@test "AT-343-09: nonexistent BRANCH_LEASE_DIR returns exit 0 and empty stdout" {
  # Given: 存在しないパスを BRANCH_LEASE_DIR に指定する
  local nonexistent="/tmp/atdd343-nonexistent-$$"
  # When: ヘルパを実行する
  run bash "$HELPER" "$nonexistent"
  # Then: exit 0・stdout 空（新フォールバック機構を増やさない）
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

# ── AT-010: AT-343 スイートが exit-code ベースで全 green ────────────────────

@test "AT-343-10: AT-343.bats lists all 11 tests without error" {
  # Given: tests/acceptance/AT-343.bats
  [[ -f "${REPO}/tests/acceptance/AT-343.bats" ]] || {
    echo "FAIL: tests/acceptance/AT-343.bats does not exist"
    return 1
  }
  # When: bats -c でテスト数を取得する（構文エラーがないことを確認）
  local count
  count=$(bats -c "${REPO}/tests/acceptance/AT-343.bats" 2>/dev/null | tr -d ' ')
  # Then: 11 件のテストが存在する（exit-code ベース検証スイートの健全性確認）
  [ "$count" -eq 11 ] || {
    echo "FAIL: expected 11 tests in AT-343.bats, got $count"
    return 1
  }
}

# ── AT-011: plugin.json version が CHANGELOG 最上位 release 見出しと一致する ─

@test "AT-343-12: lease with missing/null timestamp is treated as stale and not detected (ts=0 fail-safe)" {
  # Given: branch feat/notimestamp の lease を timestamp フィールド無しで用意する（jq は .timestamp // 0 で 0 を返す）
  # This documents the intentional fail-safe: ts=0 → age ≈ now >> TTL → stale → skipped（偽陰性・安全方向）
  printf '{"session_id":"session-notime"}\n' > "${TMP_LEASE_DIR}/feat%2Fnotimestamp.json"
  # When: ヘルパを実行する
  run bash "$HELPER" "$TMP_LEASE_DIR"
  # Then: exit 0・stdout に feat/notimestamp を含まない（ts=0 fail-safe: jq/grep 失敗時は stale 扱いでスキップ）
  [ "$status" -eq 0 ]
  [[ "$output" != *"feat/notimestamp"* ]] || {
    echo "FAIL: lease with missing timestamp was incorrectly detected (ts=0 fail-safe not working)"
    return 1
  }
}

# ── AT-011: plugin.json version が CHANGELOG 最上位 release 見出しと一致する ─

@test "AT-343-11: plugin.json version matches topmost CHANGELOG release heading (no literal pin)" {
  # Given: .claude-plugin/plugin.json と CHANGELOG.md
  [[ -f "${REPO}/tests/acceptance/helpers/changelog.bash" ]] || {
    echo "FAIL: tests/acceptance/helpers/changelog.bash does not exist"
    return 1
  }
  # shellcheck disable=SC1090
  source "${REPO}/tests/acceptance/helpers/changelog.bash"
  local top version
  top=$(changelog_latest_release "${REPO}/CHANGELOG.md")
  version=$(grep '"version"' "${REPO}/.claude-plugin/plugin.json" | grep -o '"[0-9.]*"' | tr -d '"')
  [[ -n "$top" ]] || { echo "FAIL: CHANGELOG has no [X.Y.Z] release heading"; return 1; }
  [[ -n "$version" ]] || { echo "FAIL: plugin.json has no version field"; return 1; }
  # 不変条件: version == CHANGELOG 最上位リリース（固定値ピン禁止 / #289）
  [[ "$version" == "$top" ]] || {
    echo "FAIL: plugin.json version (${version}) != CHANGELOG latest release (${top}) -- #289 invariant"
    return 1
  }
}
