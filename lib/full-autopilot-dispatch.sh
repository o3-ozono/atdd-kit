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
#   FAD_BUSY_CMD      issue の busy 判定コマンド（テスト注入用）。空なら既定実装を使用。
#                     形式: "$FAD_BUSY_CMD <issue>" → exit 0 = busy、exit 1 = idle
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

# ── GitHub-state busy 判定 ────────────────────────────────────────────────────
#
# is_issue_busy <issue>
# Returns 0 (true) if the issue has an open PR or the "in-progress" label.
# Returns 1 (false) otherwise.
#
# Env injection: if FAD_BUSY_CMD is set, delegates to "$FAD_BUSY_CMD <issue>"
# so tests can stub the GitHub API calls without network access (C1 純粋性維持).
# The cmd_select body itself never calls gh directly (stays pure w.r.t. lease logic).
is_issue_busy() {
  local issue="$1"

  # Env injection path (tests/integration callers)
  if [ -n "${FAD_BUSY_CMD:-}" ]; then
    $FAD_BUSY_CMD "$issue"
    return $?
  fi

  # Default implementation — requires gh
  if ! command -v gh >/dev/null 2>&1; then
    return 1  # gh unavailable → assume not busy (fail-safe: don't over-block)
  fi

  # Check for open PR on any branch whose head starts with "<issue>-"
  local open_prs
  open_prs=$(gh pr list --state open --json number,headRefName \
    --jq --arg n "$issue" '[.[] | select(.headRefName | startswith($n + "-"))] | length' \
    2>/dev/null || echo "0")
  [ "${open_prs:-0}" -gt 0 ] && return 0

  # Check for in-progress label
  local has_label
  has_label=$(gh issue view "$issue" --json labels \
    --jq '[.labels[].name] | map(select(. == "in-progress")) | length' \
    2>/dev/null || echo "0")
  [ "${has_label:-0}" -gt 0 ] && return 0

  return 1
}

# キュー候補から issue-lease を取得できたものを最大 K 件選ぶ。
# GitHub-state プリフィルタ（is_issue_busy）で busy な issue を lease 取得前に除外する（C2）。
# cmd_select 自身は lease-store 合成の純粋ロジックを維持し、GitHub 問い合わせを内蔵しない（C1）。
cmd_select() {
  local k="$1"; shift
  local count=0 issue
  for issue in "$@"; do
    [ "$count" -ge "$k" ] && break
    # GitHub-state prefilter: skip busy issues before attempting lease acquisition
    if is_issue_busy "$issue"; then
      continue
    fi
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
