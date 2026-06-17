#!/usr/bin/env bash
# lib/full-autopilot-run.sh — full-autopilot dispatcher ランタイム（数珠つなぎ本体）
#
# Issue #318 (b)。`ready-to-go` キューを K 並列で消化する実行ループ:
#   queue 取得 → dispatch select（issue-lease 取得）→ headless worker 起動 →
#   完了監視 → merge-ready なら merge coordinator（容量1直列）→ issue-lease 解放 →
#   スロットが空けばキューから次（数珠つなぎ）。queue 空 かつ in-flight ゼロ で終了。
#
# 移植性: macOS 標準 bash 3.2 で動く（連想配列・`wait -n` 不使用、indexed 配列 ＋ kill -0 poll）。
#
# 注入可能フック（既定=本番、テストはモック注入）:
#   FA_QUEUE_CMD       → ready-to-go issue 番号を1行ずつ出力（既定: gh issue list --label ready-to-go）
#   FA_LAUNCH_CMD <i>  → issue i の worker を foreground 実行し成否を exit code で返す
#                        （既定: claude -p "/atdd-kit:autopilot <i> --hand-off" … 本スクリプトが background 化）
#   FA_RESULT_CMD <i>  → "merge-ready" | "failed" を出力（既定: stdout json + gh ラベル判定）
#   FA_MERGE_CMD  <i>  → merge-ready を統合（既定: merge-lease 保持下で merge-coordinator process）
#
# Env: FA_SESSION（既定 full-autopilot）/ FA_POLL_INTERVAL（既定 0.2）/ LEASE_STORE_DIR
# CLI: full-autopilot-run.sh <K>

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lease-store.sh"

SESSION="${FA_SESSION:-full-autopilot}"
POLL="${FA_POLL_INTERVAL:-0.2}"
RUNDIR="${FA_RUNDIR:-$(mktemp -d)}"
export RUNDIR SESSION   # 外部 launcher / result / merge フックからも参照できるように

# ---- 既定フック（本番）。テストは env で差し替える。 ----
__default_queue() { gh issue list --label ready-to-go --json number --jq '.[].number' 2>/dev/null; }
__default_launch() {
  local i="$1"
  # FA_HANDOFF=1 が hand-off の安全マーカー（autopilot は env が在るときだけ hand-off を honor）。
  FA_HANDOFF=1 claude -p "/atdd-kit:autopilot $i --hand-off" \
    --output-format json --permission-mode acceptEdits \
    --allowed-tools "Bash Read Edit Write Glob Grep Workflow ToolSearch TaskCreate TaskUpdate TaskList" \
    > "$RUNDIR/$i.out.json" 2>"$RUNDIR/$i.err" < /dev/null
}
__default_result() {
  local i="$1"
  if [ -f "$RUNDIR/$i.out.json" ] && grep -q '"is_error":false' "$RUNDIR/$i.out.json" 2>/dev/null; then
    echo "merge-ready"
  else
    echo "failed"
  fi
}
__default_merge() {
  local i="$1"
  # merge-lease（容量1）保持下で coordinator に委譲。branch は autopilot 規約 <issue>-*。
  bash "$HERE/lease-store.sh" acquire merge main-merge "$SESSION" || return 3
  bash "$HERE/merge-coordinator.sh" process "$i" "$i" "${FA_ESCALATE_N:-3}"
  local rc=$?
  bash "$HERE/lease-store.sh" release merge main-merge "$SESSION"
  return $rc
}

QUEUE_CMD="${FA_QUEUE_CMD:-__default_queue}"
LAUNCH_CMD="${FA_LAUNCH_CMD:-__default_launch}"
RESULT_CMD="${FA_RESULT_CMD:-__default_result}"
MERGE_CMD="${FA_MERGE_CMD:-__default_merge}"

run() {
  local K="${1:-2}"
  mkdir -p "$RUNDIR"
  # キュー取得
  local queue=() qline
  while IFS= read -r qline; do [ -n "$qline" ] && queue+=("$qline"); done < <($QUEUE_CMD)

  local pids=() issues=() qi=0 active=0
  while [ "$qi" -lt "${#queue[@]}" ] || [ "$active" -gt 0 ]; do
    # 空きスロットを埋める（issue-lease を取れたものだけ起動）
    while [ "$active" -lt "$K" ] && [ "$qi" -lt "${#queue[@]}" ]; do
      local issue="${queue[$qi]}"; qi=$(( qi + 1 ))
      if cmd_acquire issue "$issue" "$SESSION"; then
        ( $LAUNCH_CMD "$issue"; echo $? > "$RUNDIR/$issue.rc" ) &
        pids+=("$!"); issues+=("$issue"); active=$(( active + 1 ))
        log_line "launch issue=$issue active=$active"
      else
        log_line "skip issue=$issue (lease held elsewhere)"
      fi
    done
    [ "$active" -eq 0 ] && break
    # いずれかの worker 完了を待つ（kill -0 poll, bash 3.2 移植）
    local done_idx=-1
    while [ "$done_idx" -lt 0 ]; do
      local j=0
      while [ "$j" -lt "${#pids[@]}" ]; do
        if [ -n "${pids[$j]}" ] && ! kill -0 "${pids[$j]}" 2>/dev/null; then done_idx="$j"; break; fi
        j=$(( j + 1 ))
      done
      [ "$done_idx" -lt 0 ] && sleep "$POLL"
    done
    local di="${issues[$done_idx]}"
    pids[$done_idx]=""; issues[$done_idx]=""; active=$(( active - 1 ))
    # 結果判定 → merge-ready なら coordinator へ
    local status; status="$($RESULT_CMD "$di")"
    if [ "$status" = "merge-ready" ]; then
      if $MERGE_CMD "$di"; then log_line "merged issue=$di"; else log_line "merge-failed issue=$di"; fi
    else
      log_line "worker-failed issue=$di"
    fi
    # issue-lease を解放（スロットを空ける＝数珠つなぎ）
    cmd_release issue "$di" "$SESSION"
  done
  log_line "drain-complete"
}

log_line() { printf '%s\n' "$1" >> "${FA_LOG:-/dev/stderr}"; }

main() {
  case "${1:-}" in
    ""|-h|--help) echo "usage: full-autopilot-run.sh <K>" >&2; return 2 ;;
    *) run "$@" ;;
  esac
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  main "$@"
fi
