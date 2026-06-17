#!/usr/bin/env bash
# lib/full-autopilot-dispatch.sh — dispatcher の slot/lease ゲート選択ロジック
#
# Issue #318 (b)。full-autopilot スキルの dispatcher が、キュー候補（`ready-to-go`
# issue 群）から「issue-lease を取得できた issue を最大 K 件」選ぶ純粋ロジック。
# 既に他セッションが claim 済みの issue はスキップする（並列排他・数珠つなぎの心臓部）。
#
# headless worker の実起動（`claude -p ... --hand-off` を run_in_background）や
# gh からのキュー取得・完了監視は full-autopilot/SKILL.md が担う統合層。本ライブラリ
# は lib/lease-store.sh を合成した「誰を今 dispatch するか」の決定のみを担当する。
#
# Env:
#   FAD_SESSION       dispatcher のセッション ID（既定 "dispatcher"）
#   LEASE_STORE_DIR   lease-store の store（lib/lease-store.sh に委譲）
#
# CLI:
#   full-autopilot-dispatch.sh select  <K> <issue...>
#     → 取得できた issue を1行ずつ最大 K 件出力し、自セッション名義で lease 済みにする
#   full-autopilot-dispatch.sh release <issue> [session]
#     → worker 完了/失敗/回収時に issue-lease を解放する（数珠つなぎでスロットを空ける）

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# lease-store の関数（cmd_acquire 等）を取り込む。source 時 CLI は起動しない。
# shellcheck source=lease-store.sh
. "$HERE/lease-store.sh"

SESSION="${FAD_SESSION:-dispatcher}"

# キュー候補から issue-lease を取得できたものを最大 K 件選ぶ。
cmd_select() {
  local k="$1"; shift
  local count=0 issue
  for issue in "$@"; do
    [ "$count" -ge "$k" ] && break
    if cmd_acquire issue "$issue" "$SESSION"; then
      echo "$issue"
      count=$(( count + 1 ))
    fi
  done
}

# worker 完了/失敗/回収時に issue-lease を解放する。
cmd_release_issue() {
  local issue="$1" sid="${2:-$SESSION}"
  cmd_release issue "$issue" "$sid"
}

main() {
  case "${1:-}" in
    select)  shift; cmd_select "$@" ;;
    release) shift; cmd_release_issue "$@" ;;
    *) echo "usage: full-autopilot-dispatch.sh {select <K> <issue...>|release <issue> [session]}" >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
