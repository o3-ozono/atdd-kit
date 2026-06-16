#!/usr/bin/env bash
# lib/lease-store.sh — 汎用 lease ライブラリ（issue-lease / merge-lease）
#
# Issue #318 (d): #316 の branch-lease store 形式（JSON {session_id, timestamp}
# ＋ TTL アクセス時 orphan 掃除）を踏襲した capacity-1/キーのクロスセッション
# lease。pool 名前空間で用途を分離する。
#
#   pool=issue  key=<issue 番号>   … 同一 issue の二重 claim を防ぐ（dispatcher）
#   pool=merge  key=main-merge     … 統合の直列化・容量1（merge coordinator）
#
# branch-lease-guard.sh（#316）は PreToolUse フックとして独立に動く。本ライブラリ
# は dispatcher / coordinator（スキルが呼ぶ bash）から CLI/source で使う。store は
# 別ディレクトリ（LEASE_STORE_DIR）に置き #316 の store とは干渉しない。
#
# Store:
#   LEASE_STORE_DIR (default /tmp/claude-leases) / <pool> / <encoded-key>.json
# TTL:
#   LEASE_TTL_LOCAL (default 7200s / 2h)
#   LEASE_TTL_CI    (default 2400s / 40min, when GITHUB_ACTIONS is set)
#
# CLI:
#   lease-store.sh acquire <pool> <key> <session_id>   exit 0=held-by-self / 1=held-by-other
#   lease-store.sh holder  <pool> <key>                prints holder session_id (or empty)
#   lease-store.sh release <pool> <key> [session_id]   release if self (or unconditional if no sid)
#   lease-store.sh cleanup <pool>                       TTL orphan cleanup
#   lease-store.sh path    <pool> <key>                 prints the lease file path

set -u

STORE_DIR="${LEASE_STORE_DIR:-/tmp/claude-leases}"
TTL_LOCAL="${LEASE_TTL_LOCAL:-7200}"
TTL_CI="${LEASE_TTL_CI:-2400}"

# CI 検出時は短い TTL。GITHUB_ACTIONS が空/未設定なら LOCAL。
effective_ttl() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then
    printf '%s' "$TTL_CI"
  else
    printf '%s' "$TTL_LOCAL"
  fi
}

# キーをファイル名安全にエンコード（英数・. _ - 以外を _ へ）。
encode_key() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

pool_dir() {
  printf '%s/%s' "$STORE_DIR" "$1"
}

key_file() {
  local pool="$1" key="$2"
  printf '%s/%s.json' "$(pool_dir "$pool")" "$(encode_key "$key")"
}

# pool 内の TTL 超過 lease をアクセス時に掃除。
cleanup_stale() {
  local pool="$1"
  local dir
  dir="$(pool_dir "$pool")"
  [ -d "$dir" ] || return 0
  local ttl now f ts age
  ttl="$(effective_ttl)"
  now="$(date +%s)"
  for f in "$dir"/*.json; do
    [ -f "$f" ] || continue
    ts=0
    if command -v jq >/dev/null 2>&1; then
      ts="$(jq -r '.timestamp // 0' "$f" 2>/dev/null || echo 0)"
    else
      ts="$(grep -o '"timestamp":[0-9]*' "$f" 2>/dev/null | grep -o '[0-9]*$' || echo 0)"
    fi
    age=$(( now - ts ))
    if [ "$age" -gt "$ttl" ]; then
      rm -f "$f" 2>/dev/null || true
    fi
  done
}

# holder の session_id を出力（無ければ空）。呼び出し前に cleanup_stale 済み前提。
read_holder() {
  local pool="$1" key="$2" lf
  lf="$(key_file "$pool" "$key")"
  [ -f "$lf" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // ""' "$lf" 2>/dev/null || true
  else
    grep -o '"session_id":"[^"]*"' "$lf" 2>/dev/null | cut -d'"' -f4 || true
  fi
}

write_lease() {
  local pool="$1" key="$2" sid="$3" now lf
  now="$(date +%s)"
  mkdir -p "$(pool_dir "$pool")"
  lf="$(key_file "$pool" "$key")"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg sid "$sid" --argjson ts "$now" \
      '{"session_id":$sid,"timestamp":$ts}' > "$lf" 2>/dev/null || true
  else
    printf '{"session_id":"%s","timestamp":%s}\n' "$sid" "$now" > "$lf" 2>/dev/null || true
  fi
}

cmd_acquire() {
  local pool="$1" key="$2" sid="$3"
  cleanup_stale "$pool"
  local holder
  holder="$(read_holder "$pool" "$key")"
  if [ -n "$holder" ] && [ "$holder" != "$sid" ]; then
    return 1
  fi
  write_lease "$pool" "$key" "$sid"
  return 0
}

cmd_holder() {
  local pool="$1" key="$2"
  cleanup_stale "$pool"
  read_holder "$pool" "$key"
}

cmd_release() {
  local pool="$1" key="$2" sid="${3:-}" lf holder
  lf="$(key_file "$pool" "$key")"
  [ -f "$lf" ] || return 0
  if [ -n "$sid" ]; then
    holder="$(read_holder "$pool" "$key")"
    # 他セッションの lease は解放しない（自己保有のみ）
    [ "$holder" = "$sid" ] || return 0
  fi
  rm -f "$lf" 2>/dev/null || true
  return 0
}

main() {
  local action="${1:-}"
  case "$action" in
    acquire) shift; cmd_acquire "$@" ;;
    holder)  shift; cmd_holder "$@" ;;
    release) shift; cmd_release "$@" ;;
    cleanup) shift; cleanup_stale "$@" ;;
    path)    shift; key_file "$@" ;;
    *) echo "usage: lease-store.sh {acquire|holder|release|cleanup|path} <pool> <key> [session_id]" >&2; return 2 ;;
  esac
}

# 直接実行時のみ CLI を起動（source 時は関数提供のみ）。
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
