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
#   FA_RESULT_CMD <i>  → "merge-ready" | "failed" を出力（既定: worker stdout json の is_error 判定。
#                        gh ラベル(merge-ready)での二重確認が要るなら FA_RESULT_CMD を差し替える）
#   FA_MERGE_CMD  <i>  → merge-ready を統合（既定: merge-lease 保持下で merge-coordinator process）
#
# Env: FA_SESSION（既定 full-autopilot）/ FA_POLL_INTERVAL（既定 0.2）/ LEASE_STORE_DIR
# CLI: full-autopilot-run.sh <K>

set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# lease store をリポジトリ単位にスコープ（/tmp 共有での issue 番号衝突を防ぐ）。
# lease-store.sh は source 時に LEASE_STORE_DIR を読むので、source 前に既定を確定させる。
if [ -z "${LEASE_STORE_DIR:-}" ]; then
  __repo_root="$(git -C "${FA_REPO:-.}" rev-parse --show-toplevel 2>/dev/null || pwd)"
  __repo_key="$(printf '%s' "$__repo_root" | (shasum 2>/dev/null || sha1sum 2>/dev/null) | cut -c1-12)"
  export LEASE_STORE_DIR="/tmp/claude-leases/${__repo_key:-default}"
fi
. "$HERE/lease-store.sh"

# session は dispatcher ごとに一意（既定 session 名が衝突すると holder 一致で排他が崩れる #318）。
SESSION="${FA_SESSION:-full-autopilot-$$}"
POLL="${FA_POLL_INTERVAL:-0.2}"
RUNDIR="${FA_RUNDIR:-$(mktemp -d)}"
export RUNDIR SESSION   # 外部 launcher / result / merge フックからも参照できるように

# ---- 既定フック（本番）。テストは env で差し替える。 ----
__default_queue() { gh issue list --label ready-to-go --json number --jq '.[].number' 2>/dev/null; }
# worker を起動する worktree を確定（SKILL flow step 3: 1 issue = 1 worktree 隔離）。
# 既定は <repo の親>/<repo 名>-<issue>。FA_WORKTREE_DIR（'{i}' を issue で置換）で明示上書き、
# FA_NO_WORKTREE=1 で従来どおり cwd 起動（テスト/単純構成向け）。解決不能なら空（=cwd 起動）。
__worker_worktree() {
  local i="$1"
  [ -n "${FA_NO_WORKTREE:-}" ] && { echo ""; return; }
  if [ -n "${FA_WORKTREE_DIR:-}" ]; then printf '%s\n' "${FA_WORKTREE_DIR//\{i\}/$i}"; return; fi
  local root name
  root="$(git -C "${FA_REPO:-.}" rev-parse --show-toplevel 2>/dev/null)" || { echo ""; return; }
  [ -n "$root" ] || { echo ""; return; }
  name="$(basename "$root")"
  printf '%s\n' "$(dirname "$root")/${name}-${i}"
}

# #329: プラグイン有効化設定(.claude/settings.local.json: enabledPlugins + extraKnownMarketplaces)を
# worktree に播種する。gitignore 対象で worktree には複製されないため、headless `claude -p` worker が
# atdd-kit プラグインを読み込めず「Unknown command: /atdd-kit:autopilot」で即失敗する。冪等
# （source 不在なら no-op / 既存と一致なら skip）。
__seed_worktree_settings() {
  local wt="$1" root src
  root="$(git -C "${FA_REPO:-.}" rev-parse --show-toplevel 2>/dev/null)" || return 0
  src="$root/.claude/settings.local.json"
  [ -f "$src" ] || return 0
  mkdir -p "$wt/.claude"
  if [ ! -f "$wt/.claude/settings.local.json" ] || ! cmp -s "$src" "$wt/.claude/settings.local.json"; then
    cp "$src" "$wt/.claude/settings.local.json"
  fi
}

__default_launch() {
  local i="$1" wt
  wt="$(__worker_worktree "$i")"
  if [ -n "$wt" ]; then
    # worktree が無ければ issue ブランチで作成（既存ブランチ→そのまま add / 無ければ -b で新規）。
    if [ ! -d "$wt" ]; then
      local branch; branch="$(__resolve_branch "$i")"
      git -C "${FA_REPO:-.}" worktree add "$wt" "$branch" >/dev/null 2>&1 \
        || git -C "${FA_REPO:-.}" worktree add -b "$branch" "$wt" >/dev/null 2>&1 || true
    fi
    # #329: 起動前に必ずプラグイン設定を播種（無いと Unknown command で落ちる）。
    __seed_worktree_settings "$wt"
  fi
  # FA_HANDOFF=1 が hand-off の安全マーカー（autopilot は env が在るときだけ hand-off を honor）。
  # RUNDIR は絶対パス（mktemp -d）なので worktree へ cd しても出力先は不変。
  # worktree 指定時に cd 失敗（作成失敗・権限不足）したら起動を中止する。失敗を握り潰して
  # メインチェックアウトで worker を走らせると別ブランチを汚染するため fail-closed（exit 1 →
  # out.json 不在 → __default_result が "failed" を返す）。
  ( if [ -n "$wt" ]; then cd "$wt" || { echo "launch: cd to worktree failed: $wt" >&2; exit 1; }; fi
    FA_HANDOFF=1 claude -p "/atdd-kit:autopilot $i --hand-off" \
      --output-format json --permission-mode acceptEdits \
      --allowed-tools "Bash Read Edit Write Glob Grep Workflow ToolSearch TaskCreate TaskUpdate TaskList" \
      > "$RUNDIR/$i.out.json" 2>"$RUNDIR/$i.err" < /dev/null )
}
__default_result() {
  local i="$1"
  # US-3 / 真因3: is_error:false 自己申告 ＋ GitHub merge-ready ラベル二重確認
  if [ -f "$RUNDIR/$i.out.json" ] && grep -q '"is_error":false' "$RUNDIR/$i.out.json" 2>/dev/null; then
    # merge-ready ラベルが Issue に存在することを gh で照合（produce→consume の往復検証）
    if gh issue view "$i" --json labels --jq '.labels[].name' 2>/dev/null | grep -q '^merge-ready$'; then
      echo "merge-ready"
    else
      echo "failed"
    fi
  else
    echo "failed"
  fi
}
# issue から PR ブランチを解決（autopilot 規約 <issue>-*）。FA_BRANCH で明示上書き可。
__resolve_branch() {
  local i="$1" b
  [ -n "${FA_BRANCH:-}" ] && { echo "$FA_BRANCH"; return; }
  b="$(git -C "${FA_REPO:-.}" branch --list "${i}-*" 2>/dev/null | head -1 | sed 's/^[* ]*//')"
  [ -n "$b" ] && echo "$b" || echo "$i"
}
__default_merge() {
  local i="$1" branch rc
  branch="$(__resolve_branch "$i")"
  # merge-lease（容量1）保持下で coordinator に委譲。MC_*_CMD に **実 git ステップを配線**する
  # （配線しないと process() の各ステップが空コマンド＝no-op success になり実際には merge されない）。
  # 再ゲート/回帰は FA_GATE_CMD / FA_REGRESSION_CMD で注入（既定はプロジェクトの AT スイート想定）。
  # merge-lease（容量1）を bounded retry で取得（並行 dispatcher の一時競合を吸収）。
  local mtries=0 mmax="${FA_MERGE_LEASE_RETRIES:-10}"
  until bash "$HERE/lease-store.sh" acquire merge main-merge "$SESSION"; do
    mtries=$(( mtries + 1 ))
    [ "$mtries" -ge "$mmax" ] && return 3
    sleep "${FA_MERGE_LEASE_WAIT:-1}"
  done
  MC_REBASE_CMD="bash $HERE/fa-merge-steps.sh rebase" \
  MC_REGATE_CMD="${FA_GATE_CMD:-true}" \
  MC_MERGE_CMD="bash $HERE/fa-merge-steps.sh merge" \
  MC_REGRESSION_CMD="${FA_REGRESSION_CMD:-true}" \
    bash "$HERE/merge-coordinator.sh" process "$i" "$branch" "${FA_ESCALATE_N:-3}"
  rc=$?
  bash "$HERE/lease-store.sh" release merge main-merge "$SESSION"
  return $rc
}

# プロセスツリーを再帰 kill（macOS bash 3.2 に setsid が無いので pgrep -P で子孫を辿る）。
# サブシェル PID だけを kill すると実 `claude -p` 孫プロセスが孤児化するため、子孫から先に落とす。
__kill_tree() {
  local p="$1" c
  for c in $(pgrep -P "$p" 2>/dev/null); do __kill_tree "$c"; done
  kill "$p" 2>/dev/null || true
}

QUEUE_CMD="${FA_QUEUE_CMD:-__default_queue}"
LAUNCH_CMD="${FA_LAUNCH_CMD:-__default_launch}"
RESULT_CMD="${FA_RESULT_CMD:-__default_result}"
MERGE_CMD="${FA_MERGE_CMD:-__default_merge}"
NOTIFY_CMD="${FA_NOTIFY_CMD:-}"
NOTIFY_LEVEL="${FA_NOTIFY_LEVEL:-normal}"   # quiet | normal | verbose（サービス非依存の粒度）
TIMEOUT="${FA_WORKER_TIMEOUT:-3600}"        # worker の wall-clock 上限秒（0=無効）

# イベントを粒度クラスに分類: alert（要注意・常に通知）/ milestone（節目）/ detail（詳細）。
__event_class() {
  case "$1" in
    escalate|merge-failed|worker-failed) echo alert ;;
    dispatch|merged)                     echo milestone ;;
    merge-ready|progress|log)            echo detail ;;
    *)                                   echo milestone ;;
  esac
}

# 通知フック（サービス非依存）。FA_NOTIFY_CMD に notifier を設定すると issue ごとに通知が
# 流れる（opt-in 通知 addon が実装を提供）。FA_NOTIFY_LEVEL でイベント粒度を段階制御:
#   quiet   = alert のみ（要注意イベントだけ） / normal = alert + milestone（既定） /
#   verbose = 全イベント（detail 含む）。未設定/失敗でも本体は止めない。
notify() {
  [ -z "$NOTIFY_CMD" ] && return 0
  local cls; cls="$(__event_class "$1")"
  case "$NOTIFY_LEVEL" in
    quiet)   [ "$cls" = "alert" ] || return 0 ;;
    verbose) : ;;                                  # 全部通す
    *)       [ "$cls" = "detail" ] && return 0 ;;  # normal: detail を落とす
  esac
  # notifier 失敗を握り潰さず FA_LOG に記録（escalation 等の無音喪失を防ぐ）。
  if ! $NOTIFY_CMD "$1" "$2" "${3:-}" >/dev/null 2>&1; then
    log_line "notify-failed event=$1 issue=$2"
  fi
}

# graceful shutdown 時に in-flight worker を kill し、保持中の issue-lease を解放する
# （trap が無いと Ctrl-C/SIGTERM で lease が TTL まで孤児化する #318）。
__HELD_ISSUES=""
__HELD_PIDS=""
__cleanup() {
  local h
  for h in $__HELD_PIDS; do __kill_tree "$h"; done
  for h in $__HELD_ISSUES; do cmd_release issue "$h" "$SESSION"; done
  log_line "cleanup: released in-flight leases on shutdown"
}
# in-flight の issues/pids 配列から held トラッカを再構築（bash 動的スコープで run() の local を参照）。
__rebuild_held() {
  __HELD_ISSUES=""; __HELD_PIDS=""; local x
  if [ "${#issues[@]}" -gt 0 ]; then for x in "${issues[@]}"; do [ -n "$x" ] && __HELD_ISSUES="$__HELD_ISSUES $x"; done; fi
  if [ "${#pids[@]}" -gt 0 ]; then for x in "${pids[@]}"; do [ -n "$x" ] && __HELD_PIDS="$__HELD_PIDS $x"; done; fi
}

run() {
  local K="${1:-2}"
  mkdir -p "$RUNDIR"
  trap '__cleanup' INT TERM
  # 通知先プリフライト確認（US-2 / 真因2）
  if [ -z "$NOTIFY_CMD" ]; then
    log_line "preflight: NOTIFY_CMD unset — no notifications will be sent"
  else
    log_line "preflight: NOTIFY_CMD=$NOTIFY_CMD"
  fi

  local pids=() issues=() starts=() active=0 done_set=""
  # 動的キュー再評価フラグ: 初回は必ず1回評価
  local need_refill=1
  while :; do
    # 空きスロット充填時に $QUEUE_CMD を再評価（動的 enqueue / US-1 / 真因1）
    if [ "$need_refill" -eq 1 ] && [ "$active" -lt "$K" ]; then
      need_refill=0
      local qline
      while IFS= read -r qline; do
        [ -z "$qline" ] && continue
        # dedup: lease 保持中 / in-flight / 完了済みを除外
        local already=0
        local _x
        for _x in "${issues[@]+"${issues[@]}"}"; do [ "$_x" = "$qline" ] && already=1 && break; done
        [ "$already" -eq 1 ] && continue
        case " $done_set " in *" $qline "*) continue ;; esac
        # lease 取得できたものだけ起動
        if cmd_acquire issue "$qline" "$SESSION"; then
          ( $LAUNCH_CMD "$qline"; echo $? > "$RUNDIR/$qline.rc" ) &
          pids+=("$!"); issues+=("$qline"); starts+=("$(date +%s)"); active=$(( active + 1 ))
          log_line "launch issue=$qline active=$active"; notify dispatch "$qline"
          [ "$active" -ge "$K" ] && break
        else
          log_line "skip issue=$qline (lease held elsewhere)"
        fi
      done < <($QUEUE_CMD)
    fi
    __rebuild_held
    # キューが空 かつ in-flight ゼロ で終了
    [ "$active" -eq 0 ] && [ "$need_refill" -eq 0 ] && break
    # in-flight が無く次回の refill が必要な場合は refill させてから再チェック
    [ "$active" -eq 0 ] && continue
    # いずれかの worker 完了を待つ（kill -0 poll, bash 3.2 移植）。
    # FA_WORKER_TIMEOUT(>0) 超過の worker は kill して失敗扱い（ハングで dispatcher が永久停止しない）。
    local done_idx=-1 timed_out=0
    while [ "$done_idx" -lt 0 ]; do
      local j=0
      while [ "$j" -lt "${#pids[@]}" ]; do
        if [ -n "${pids[$j]}" ] && ! kill -0 "${pids[$j]}" 2>/dev/null; then done_idx="$j"; break; fi
        j=$(( j + 1 ))
      done
      if [ "$done_idx" -lt 0 ] && [ "$TIMEOUT" -gt 0 ]; then
        local now2 j2=0; now2="$(date +%s)"
        while [ "$j2" -lt "${#pids[@]}" ]; do
          if [ -n "${pids[$j2]}" ] && [ $(( now2 - ${starts[$j2]} )) -gt "$TIMEOUT" ]; then
            __kill_tree "${pids[$j2]}"; wait "${pids[$j2]}" 2>/dev/null || true
            done_idx="$j2"; timed_out=1; break
          fi
          j2=$(( j2 + 1 ))
        done
      fi
      [ "$done_idx" -lt 0 ] && sleep "$POLL"
    done
    local di="${issues[$done_idx]}"
    pids[$done_idx]=""; issues[$done_idx]=""; starts[$done_idx]=""; active=$(( active - 1 ))
    done_set="$done_set $di"

    if [ "$timed_out" -eq 1 ]; then
      log_line "worker-timeout issue=$di (>${TIMEOUT}s)"; notify worker-failed "$di" "timeout >${TIMEOUT}s"
    else
      # 結果判定 → merge-ready なら coordinator へ
      local status; status="$($RESULT_CMD "$di")"
      if [ "$status" = "merge-ready" ]; then
        notify merge-ready "$di"
        local mout mrc
        mout="$($MERGE_CMD "$di" 2>&1)"; mrc=$?
        if [ "$mrc" -eq 0 ]; then
          log_line "merged issue=$di"; notify merged "$di"
        elif [ "$mrc" -eq 2 ]; then
          # exit 2 = post-merge regression 失敗 = main 破損。常に escalate（@mention）で上げる。
          log_line "merge-regression-failed issue=$di (main may be broken: $mout)"
          notify escalate "$di" "post-merge regression failed — main may be broken: $mout"
        elif [ "$mrc" -eq 3 ]; then
          # exit 3 = merge-lease を retry 上限まで取得できず（並行競合）。false merge-failed にせず escalate。
          log_line "merge-deferred issue=$di (merge-lease busy after retries)"
          notify escalate "$di" "merge-lease busy — could not serialize merge after retries"
        else
          log_line "merge-failed issue=$di ($mout)"
          case "$mout" in
            *escalate*) notify escalate "$di" "$mout" ;;
            *)          notify merge-failed "$di" "$mout" ;;
          esac
        fi
      else
        log_line "worker-failed issue=$di"; notify worker-failed "$di"
      fi
    fi
    # issue-lease を解放（スロットを空ける＝数珠つなぎ）＋次ラウンドで再評価
    cmd_release issue "$di" "$SESSION"
    need_refill=1
    __rebuild_held
  done
  trap - INT TERM
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
