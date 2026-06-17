#!/usr/bin/env bash
# lib/merge-coordinator.sh — merge coordinator の失敗ハンドリング状態機械
#
# Issue #318 (c)。merge-ready PR を容量1（merge-lease）で直列 drain する
# coordinator のうち、「rebase 衝突 / 再ゲート fail → 自動差し戻し → 閾値 N で
# human エスカレーション」の分岐ロジック（User Story F6 / F7）を担う。
#
# 外部ステップ（rebase / 再ゲート / merge / regression）は env で差し替え可能な
# コマンドに分離し、純粋な状態遷移を unit テスト可能にしている。
#
# State:
#   MC_STATE_DIR (default /tmp/claude-merge-coordinator) / <pr>.count … 連続失敗回数
#
# CLI:
#   merge-coordinator.sh decide  <pr> <N>          失敗を1回記録し retry|escalate を出力
#   merge-coordinator.sh clear   <pr>              成功時にカウンタをリセット
#   merge-coordinator.sh process <pr> <branch> <N> 1件を rebase→再ゲート→merge→regression
#
# process が使う差し替え可能コマンド（既定は本番の git/gh、テストはモック注入）:
#   MC_REBASE_CMD MC_REGATE_CMD MC_MERGE_CMD MC_REGRESSION_CMD
#   いずれも "<cmd> <branch>" 形式で呼ばれ、exit 0 を成功とみなす。

set -u

STATE_DIR="${MC_STATE_DIR:-/tmp/claude-merge-coordinator}"

count_file() {
  printf '%s/%s.count' "$STATE_DIR" "$1"
}

read_count() {
  local f
  f="$(count_file "$1")"
  if [ -f "$f" ]; then
    cat "$f" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

# 失敗を1回記録し、累積が N 以上なら escalate、未満なら retry を出力。
cmd_decide() {
  local pr="$1" n="$2" count
  mkdir -p "$STATE_DIR"
  count="$(read_count "$pr")"
  count=$(( count + 1 ))
  printf '%s' "$count" > "$(count_file "$pr")" 2>/dev/null || true
  if [ "$count" -ge "$n" ]; then
    echo "escalate"
  else
    echo "retry"
  fi
}

cmd_clear() {
  rm -f "$(count_file "$1")" 2>/dev/null || true
}

# 差し替え可能な外部ステップを実行（既定は no-op 成功 — 本番スキルが env で上書き）。
run_step() {
  local cmd="$1" branch="$2"
  [ -z "$cmd" ] && return 0
  # shellcheck disable=SC2086
  $cmd "$branch"
}

# merge-ready 1件を統合する。各ステップ失敗時は decide で retry|escalate を出力し非ゼロ。
# 全成功で clear し "merged" を出力して 0。
cmd_process() {
  local pr="$1" branch="$2" n="$3" decision

  if ! run_step "${MC_REBASE_CMD:-}" "$branch"; then
    decision="$(cmd_decide "$pr" "$n")"
    echo "rebase-failed:$decision"
    return 1
  fi
  if ! run_step "${MC_REGATE_CMD:-}" "$branch"; then
    decision="$(cmd_decide "$pr" "$n")"
    echo "regate-failed:$decision"
    return 1
  fi
  if ! run_step "${MC_MERGE_CMD:-}" "$branch"; then
    decision="$(cmd_decide "$pr" "$n")"
    echo "merge-failed:$decision"
    return 1
  fi
  # post-merge regression。merge は済んでいるので失敗は差し戻しではなく
  # 「main が壊れた」アラーム — 沈黙させず非ゼロで上げて human に escalate させる。
  cmd_clear "$pr"
  if ! run_step "${MC_REGRESSION_CMD:-}" "$branch"; then
    echo "merged:regression-failed"
    return 2
  fi
  echo "merged"
  return 0
}

main() {
  local action="${1:-}"
  case "$action" in
    decide)  shift; cmd_decide "$@" ;;
    clear)   shift; cmd_clear "$@" ;;
    process) shift; cmd_process "$@" ;;
    *) echo "usage: merge-coordinator.sh {decide <pr> <N>|clear <pr>|process <pr> <branch> <N>}" >&2; return 2 ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
