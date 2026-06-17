#!/usr/bin/env bash
# lib/lease-store.sh — 汎用 lease ライブラリ（issue-lease / merge-lease）
#
# Issue #318 (d)。capacity-1/キーのクロスセッション lease。pool 名前空間で用途を分離:
#   pool=issue  key=<issue 番号>   … 同一 issue の二重 claim を防ぐ（dispatcher）
#   pool=merge  key=main-merge     … 統合の直列化・容量1（merge coordinator）
#
# 排他は lease の存在意義なので、取得は **アトミック（mkdir ロック）＋ fail-closed** で行う:
#   - `mkdir <lock>` はファイルシステムでアトミック。同時実行でも勝者は1つだけ（TOCTOU race を排除）。
#   - holder 書き込みに失敗したら lock を解放し acquire を**失敗**にする（未永続化を「取得成功」と
#     誤報しない。ENOSPC/EACCES/読取専用 FS で容量1保証が破れるのを防ぐ）。
#   #316 branch-lease-guard.sh は PreToolUse フックの fail-safe（allow 寄り）思想だが、本ライブラリの
#   acquire は「排他を保証できないなら取得失敗（fail-closed）」が正しい — 二重取得を許す方が危険。
#
# Store:
#   LEASE_STORE_DIR (default /tmp/claude-leases) / <pool> / <encoded-key>.lock/ (dir)
#                                                          / <encoded-key>.lock/holder.json
# TTL:
#   LEASE_TTL_LOCAL (default 7200s / 2h) / LEASE_TTL_CI (default 2400s / 40min, GITHUB_ACTIONS 設定時)
#
# CLI:
#   lease-store.sh acquire <pool> <key> <session_id>   exit 0=held-by-self / 1=held-by-other or persist-fail
#   lease-store.sh holder  <pool> <key>                prints holder session_id (or empty)
#   lease-store.sh release <pool> <key> [session_id]   release if self (or unconditional if no sid)
#   lease-store.sh cleanup <pool>                       TTL orphan cleanup
#   lease-store.sh path    <pool> <key>                 prints the holder.json path

set -u

STORE_DIR="${LEASE_STORE_DIR:-/tmp/claude-leases}"
TTL_LOCAL="${LEASE_TTL_LOCAL:-7200}"
TTL_CI="${LEASE_TTL_CI:-2400}"
ACQUIRE_RETRIES="${LEASE_ACQUIRE_RETRIES:-50}"

effective_ttl() {
  if [ -n "${GITHUB_ACTIONS:-}" ]; then printf '%s' "$TTL_CI"; else printf '%s' "$TTL_LOCAL"; fi
}

encode_key() {
  printf '%s' "$1" | sed 's/[^A-Za-z0-9._-]/_/g'
}

pool_dir() {
  printf '%s/%s' "$STORE_DIR" "$1"
}

lock_dir() {
  printf '%s/%s.lock' "$(pool_dir "$1")" "$(encode_key "$2")"
}

holder_file() {
  printf '%s/holder.json' "$(lock_dir "$1" "$2")"
}

# ディレクトリの mtime（macOS / Linux 両対応）。取得不能なら 0。
dir_mtime() {
  stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo 0
}

# lock の有効 timestamp。holder.json があればその ts、無ければ lock dir の mtime。
# mtime フォールバックが無いと、winner が mkdir 後 holder.json を書く前の一瞬を loser が
# ts=0（=age 無限大=stale）と誤判定して winner の lock を奪う race が起きる。mkdir 直後の
# dir mtime≈now なら age≈0 となり「作成直後＝保持中」と正しく扱える。
lock_ts() {
  local hf="$1/holder.json" ts=""
  if [ -f "$hf" ]; then
    if command -v jq >/dev/null 2>&1; then
      ts="$(jq -r '.timestamp // empty' "$hf" 2>/dev/null || true)"
    else
      ts="$(grep -o '"timestamp":[0-9]*' "$hf" 2>/dev/null | grep -o '[0-9]*$' || true)"
    fi
  fi
  if [ -z "$ts" ]; then ts="$(dir_mtime "$1")"; fi
  [ -n "$ts" ] && echo "$ts" || echo 0
}

# pool 内の TTL 超過 lock をアクセス時に掃除。
cleanup_stale() {
  local pool="$1" dir ttl now d age
  dir="$(pool_dir "$pool")"
  [ -d "$dir" ] || return 0
  ttl="$(effective_ttl)"; now="$(date +%s)"
  for d in "$dir"/*.lock; do
    [ -d "$d" ] || continue
    age=$(( now - $(lock_ts "$d") ))
    if [ "$age" -gt "$ttl" ]; then
      rm -rf "$d" 2>/dev/null || true
    fi
  done
}

read_holder() {
  local hf
  hf="$(holder_file "$1" "$2")"
  [ -f "$hf" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.session_id // ""' "$hf" 2>/dev/null || true
  else
    grep -o '"session_id":"[^"]*"' "$hf" 2>/dev/null | cut -d'"' -f4 || true
  fi
}

# holder.json を書く。書けたら 0、失敗したら非ゼロ（fail-closed の判定材料）。
write_holder() {
  local pool="$1" key="$2" sid="$3" now hf
  now="$(date +%s)"
  hf="$(holder_file "$pool" "$key")"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg sid "$sid" --argjson ts "$now" '{"session_id":$sid,"timestamp":$ts}' > "$hf" 2>/dev/null
  else
    printf '{"session_id":"%s","timestamp":%s}\n' "$sid" "$now" > "$hf" 2>/dev/null
  fi || return 1
  # fail-closed verify: 実際に自分の sid で永続化されたか読み戻す
  [ "$(read_holder "$pool" "$key")" = "$sid" ]
}

cmd_acquire() {
  local pool="$1" key="$2" sid="$3" ld holder i
  cleanup_stale "$pool"
  ld="$(lock_dir "$pool" "$key")"
  mkdir -p "$(pool_dir "$pool")" 2>/dev/null || true
  # 緊急上書き（#316 branch-lease-guard の ATDD_BRANCH_LEASE_FORCE 相当）。
  # 安全と判断したときの意図的な奪取。既存 lock を捨てて自セッション名義で取り直す。
  # 稼働中 lease を黙って奪うのは危険なので **必ず監査証跡を残す**（stderr ＋ LEASE_AUDIT_LOG）。
  if [ "${ATDD_LEASE_FORCE:-}" = "1" ]; then
    local prev; prev="$(read_holder "$pool" "$key")"
    local amsg="lease-force pool=$pool key=$key by=$sid prev=${prev:-none} ts=$(date +%s)"
    printf '%s\n' "$amsg" >&2
    [ -n "${LEASE_AUDIT_LOG:-}" ] && { printf '%s\n' "$amsg" >> "$LEASE_AUDIT_LOG" 2>/dev/null || true; }
    rm -rf "$ld" 2>/dev/null || true
    if mkdir "$ld" 2>/dev/null && write_holder "$pool" "$key" "$sid"; then
      return 0
    fi
    rm -rf "$ld" 2>/dev/null || true
    return 1
  fi
  i=0
  while [ "$i" -lt "$ACQUIRE_RETRIES" ]; do
    if mkdir "$ld" 2>/dev/null; then
      # アトミックに lock を獲得。holder を fail-closed で書く。
      if write_holder "$pool" "$key" "$sid"; then
        return 0
      fi
      rm -rf "$ld" 2>/dev/null || true   # 永続化失敗 → lock を返し取得失敗
      return 1
    fi
    # lock 既存。holder を確認。
    holder="$(read_holder "$pool" "$key")"
    if [ "$holder" = "$sid" ]; then
      write_holder "$pool" "$key" "$sid" || true   # 自己保有 → ts 更新（冪等）
      return 0
    fi
    # TTL 超過なら回収を試みて再挑戦
    if [ -d "$ld" ]; then
      local age
      age=$(( $(date +%s) - $(lock_ts "$ld") ))
      if [ "$age" -gt "$(effective_ttl)" ]; then
        rm -rf "$ld" 2>/dev/null || true
        i=$(( i + 1 ))
        continue
      fi
    fi
    return 1   # 別セッションが fresh に保有
  done
  return 1
}

cmd_holder() {
  cleanup_stale "$1"
  read_holder "$1" "$2"
}

cmd_release() {
  local pool="$1" key="$2" sid="${3:-}" ld holder
  ld="$(lock_dir "$pool" "$key")"
  [ -d "$ld" ] || return 0
  if [ -n "$sid" ]; then
    holder="$(read_holder "$pool" "$key")"
    [ "$holder" = "$sid" ] || return 0   # 他セッションの lease は解放しない
  fi
  rm -rf "$ld" 2>/dev/null || true
  return 0
}

main() {
  local action="${1:-}"
  case "$action" in
    acquire) shift; cmd_acquire "$@" ;;
    holder)  shift; cmd_holder "$@" ;;
    release) shift; cmd_release "$@" ;;
    cleanup) shift; cleanup_stale "$@" ;;
    path)    shift; holder_file "$@" ;;
    *) echo "usage: lease-store.sh {acquire|holder|release|cleanup|path} <pool> <key> [session_id]" >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
