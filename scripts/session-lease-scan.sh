#!/usr/bin/env bash
# scripts/session-lease-scan.sh — session-start 用 branch-lease store スキャンヘルパ
#
# 目的: session-start から呼び出し、別セッションが fresh lease を保持している
#       branch 名を 1 行ずつ stdout に出力する（案A: 自セッション突合なし）。
#
# 設計決定（design-doc.md 決定 1/2）:
#   - 案A: session-start 実行時点の fresh lease はすべて別セッション扱い（自 session_id 不要）
#   - Draft 非依存: has_open_draft_pr を呼ばず「fresh lease が存在する = 別セッション作業中」
#   - hooks/branch-lease-guard.sh と同一 env 名・同一 freshness 式・同一 encode 5 文字セット
#   - ストアは読み取り専用（write_lease / delete_lease を呼ばない）
#
# 使い方:
#   scripts/session-lease-scan.sh [<LEASE_DIR>]
#
#   引数なしの場合は BRANCH_LEASE_DIR 環境変数（既定 /tmp/claude-branch-leases）を使用。
#   引数あり（テスト用）は引数を LEASE_DIR として使用。
#
# 出力:
#   - 別セッションが fresh lease を保持する branch 名を 1 行ずつ stdout に出力する。
#   - store 空・未生成のときは stdout 空・exit 0（fail-safe）。
#   - エラー時も exit 0（CS-1 原則: セッション開始を壊さない）。
#
# 依存: bash 3.2+, date (GNU/BSD), sed (GNU/BSD 共通)
# 外部コマンド: jq（利用可能なら使用、なければ grep フォールバック）

set -uo pipefail

# ── 定数（hooks/branch-lease-guard.sh と同一 env 名・同一既定値）────────────

LEASE_DIR="${BRANCH_LEASE_DIR:-/tmp/claude-branch-leases}"
# 引数で上書き可能（テスト用）
if [ "${1:-}" != "" ]; then
  LEASE_DIR="$1"
fi

TTL="${BRANCH_LEASE_TTL_LOCAL:-7200}"

# ── ヘルパ関数 ───────────────────────────────────────────────────────────────

# branch ファイル名を branch 名にデコードする（encode の逆変換）。
# encode_branch（hooks）: / → %2F, space → %20, # → %23, . → %2E, ~ → %7E
decode_branch() {
  printf '%s' "$1" | sed 's|%2F|/|g; s|%20| |g; s|%23|#|g; s|%2E|.|g; s|%7E|~|g'
}

# lease ファイルから timestamp を取得する。
# jq があれば使用、なければ grep フォールバック。
get_timestamp() {
  local file="$1"
  local ts=0
  if command -v jq >/dev/null 2>&1; then
    ts=$(jq -r '.timestamp // 0' "$file" 2>/dev/null || echo 0)
  else
    ts=$(grep -o '"timestamp":[0-9]*' "$file" 2>/dev/null | grep -o '[0-9]*$' || echo 0)
  fi
  printf '%s' "$ts"
}

# lease ファイルから session_id を取得する。
get_session_id() {
  local file="$1"
  local sid=""
  if command -v jq >/dev/null 2>&1; then
    sid=$(jq -r '.session_id // ""' "$file" 2>/dev/null || true)
  else
    sid=$(grep -o '"session_id":"[^"]*"' "$file" 2>/dev/null | cut -d'"' -f4 || true)
  fi
  printf '%s' "$sid"
}

# ── メイン処理 ───────────────────────────────────────────────────────────────

main() {
  # ストアが存在しない場合は fail-safe（exit 0・stdout 空）
  [ -d "$LEASE_DIR" ] || exit 0

  local now
  now=$(date +%s)

  # LEASE_DIR 内の各 <encoded_branch>.json を走査する
  for lease_file in "${LEASE_DIR}"/*.json; do
    # ワイルドカードが展開されなかった場合（ファイルなし）をスキップ
    [ -f "$lease_file" ] || continue

    # ファイル名から branch 名を復元する（.json を除去してデコード）
    local encoded_name
    encoded_name="$(basename "$lease_file" .json)"
    local branch_name
    branch_name="$(decode_branch "$encoded_name")"

    # session_id が空の lease は無効（設計上 session_id が空の lease は無視）
    local sid
    sid="$(get_session_id "$lease_file")"
    [ -n "$sid" ] || continue

    # freshness 判定: now - timestamp <= ttl（hooks と同一ロジック）
    local ts
    ts="$(get_timestamp "$lease_file")"
    local age=$(( now - ts ))
    # TTL 超過 (stale) はスキップ
    [ "$age" -le "$TTL" ] || continue

    # fresh lease を持つ branch 名を出力する（1 行 = 1 branch）
    printf '%s\n' "$branch_name"
  done

  exit 0
}

main
