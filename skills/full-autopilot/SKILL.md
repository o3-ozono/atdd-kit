---
name: full-autopilot
description: "Use when you want to drain a queue of ready-to-go Issues unattended — dispatching parallel headless autopilot workers and serially merging their results, with the human involved only at the requirements 壁打ち."
---

# Full Autopilot

The **multi-Issue, parallel, hands-off** mode of atdd-kit. `autopilot` runs **one** Issue to a near-green hand-off; **full-autopilot** runs **many** Issues — dispatching parallel `autopilot` workers and serially merging their results — until the queue is empty. Human involvement narrows to **the requirements 壁打ち that places an Issue on the queue**; everything after is autonomous.

full-autopilot is a **thin orchestrator over `autopilot`** and does not rewrite it (疎結合 / C3). It wires three libraries:

| 役割 | 実装 | 担当 |
|------|------|------|
| issue / merge lease | `lib/lease-store.sh` | 並列排他（同一 issue 二重 claim 防止・merge 直列化） |
| dispatcher 選択 | `lib/full-autopilot-dispatch.sh` | K スロット下で issue-lease を取りつつ起動対象を選ぶ |
| merge coordinator | `lib/merge-coordinator.sh` | `merge-ready` を容量1で rebase→再ゲート→merge→regression、自動差し戻し→閾値 N でエスカレーション |

## autopilot Iron Law（hand-off モード）

full-autopilot は worker を `autopilot --hand-off` で起動する。AL-1 の三ゲートは hand-off モードで担い手が移る（①=queue 事前承認 / ②=reviewer-oracle / ③=merge coordinator）。詳細と正当性は `docs/methodology/autopilot-iron-law.md` §AL-1 under full-autopilot。**通常 autopilot の三ゲートは不変。**

## Trigger

- **Explicit:** `/atdd-kit:full-autopilot [--parallel K]`（既定 K=2）
- **Keyword-detected (confirm first):** full-autopilot / 無人並列 / キュー消化 の意図で `Run full-autopilot (queue drain, K=<K>)? Y/n` を確認してから起動。

## Input

- **キュー** = `ready-to-go` ラベルの open Issue 群（`gh issue list --label ready-to-go`）。**PRD が承認済み（壁打ち済み）であることが `ready-to-go` の前提。** PRD 未承認の Issue は queue に乗らない＝着手しない（暴走防止の安全弁 / C4）。
- 並列度 K（`--parallel`、既定 2）。

## Flow

1. **キュー取得.** `ready-to-go` の Issue 番号を優先度順（古い順 / 明示優先度ラベル）に列挙する。
2. **dispatch.** `lib/full-autopilot-dispatch.sh select <K-active> <issue...>` で、空きスロット分だけ issue-lease を取得できた Issue を選ぶ（他セッション claim 済みはスキップ）。
3. **worker 起動.** 選ばれた各 Issue について、独立 worktree を作り **headless プロセス**として起動する:
   ```
   FA_HANDOFF=1 claude -p "/atdd-kit:autopilot <issue> --hand-off" \
     --session-id <uuid> --output-format json \
     --permission-mode acceptEdits \
     --allowed-tools "Bash Read Edit Write Glob Grep Workflow ToolSearch TaskCreate TaskUpdate TaskList" \
     > <worker-out>.json 2>&1 < /dev/null   # run_in_background
   ```
   - `FA_HANDOFF=1` が hand-off の**安全マーカー**。autopilot はこの env が在るときだけ Gate ② を自動承認する（人間が素の `--hand-off` を打っても無視され3ゲート維持）。`lib/full-autopilot-run.sh` の launcher が設定する。
   - 各 worker は独立 top-level プロセスのため、内部で Workflow を回しても入れ子制約に当たらない（#318 検証済み）。
   - `--allowed-tools` は worker が必要とする最小集合に絞る（上記が既定。`gh`/`git` は Bash 経由）。未充填のまま実行しない。
   - `--session-id` を指定し transcript パス `~/.claude/projects/<munged-cwd>/<uuid>.jsonl` を確定させる。stdin は `< /dev/null`（3秒ストール回避）。stdout json は `> <worker-out>.json` にリダイレクトする。
4. **完了監視.** `run_in_background` は同期 stdout を返さずハンドルのみ返す。**完了通知を受けてから**リダイレクト先 `<worker-out>.json` を読み（`is_error` / `terminal_reason` / `total_cost_usd`）結果を判定する（実行中のポーリングが要るなら Monitor / 共有ファイル）。near-green→`merge-ready` ラベルが付けば成功。ログは3層回収（stdout json / session transcript / 入れ子 Workflow の `subagents/workflows/wf_*/`）し監査ログへ集約。
5. **merge coordinator（容量1直列）.** `merge-ready` PR を `lib/lease-store.sh acquire merge main-merge <self>`（容量1）保持下で1件ずつ `lib/merge-coordinator.sh process <pr> <branch> <N>`。成功で merge＋regression、失敗は自動差し戻し（新 autopilot イテレーション）→ N 回で human フラグ（Issue コメント）。
6. **数珠つなぎ.** worker 完了でスロットを解放し issue-lease を release（下記 Worker lifecycle 参照）、Step 2 に戻ってキューから次を取る。キューが空 かつ in-flight ゼロ で終了。

## 観測と通知（無人運転の可視化・エスカレーション）

hand-off は実行中に**人間へ対話的に質問しない**（gate ② は reviewer-oracle が自動承認）。人間に届けるのは2種類だけで、いずれも**非同期通知**:

- **進行状況** — どの issue が in-flight / merge-ready / merged か。
- **エスカレーション** — N 回失敗・解決不能（merge coordinator が `escalate` を返す）。ブロッキングな質問ではなく「見て」の通知。worker は止めず該当 issue を park、dispatcher は他 issue を進める。

3層で可視化する: **(1) GitHub state（永続・真実源）** ラベル／PR／Issue コメント、**(2) dispatcher イベントログ** `FA_LOG`、**(3) per-worker 3層ログ**。

**通知フック `FA_NOTIFY_CMD <event> <issue> <detail>`（サービス非依存）**: runtime が `dispatch` / `merge-ready` / `merged` / `merge-failed` / `worker-failed` / `escalate` で発火。既定 no-op。粒度は **`FA_NOTIFY_LEVEL`** で段階制御 — `quiet`（alert＝escalate/merge-failed/worker-failed のみ）/ `normal`（既定: alert＋milestone＝dispatch/merged）/ `verbose`（detail＝merge-ready/progress/log も含む全イベント）。具体的な通知先は **opt-in の通知 addon** が提供する（core はどのサービスにも依存しない）。同梱の **Discord addon**（`addons/discord/`, opt-in — session-start で `[y/N]` 確認 or `/atdd-kit:setup-discord`）は **issue ごとに forum スレッドを立て**状況・ログを流す。Slack 等も同契約で差し替え可。headless/cron の完全無人では対話セッション通知が人に届かないため webhook が確実。

```
FA_NOTIFY_CMD="bash .claude/addons/fa-notify-discord.sh" FA_DISCORD_WEBHOOK="<forum webhook>" \
FA_DISCORD_MENTION="<@USERID>" bash lib/full-autopilot-run.sh 2
```

## Worker lifecycle（timeout・完了検出・lease 解放）

ハング/クラッシュした worker が issue-lease を占有してスロットを枯らさないよう、各 worker は明示的に管理する:

- **完了検出**: バックグラウンドタスクの終了通知が一次シグナル。終了したら stdout json を読み `is_error` / `terminal_reason` で成否を判定（成功は `merge-ready` ラベルでも二重確認）。
- **timeout**: worker ごとに上限時間（既定の目安 `FA_WORKER_TIMEOUT`、例 30〜60 分）を設け、超過したらその worker を失敗扱いにして回収する（プロセス終了 ＋ 下記の lease 解放）。timeout 値は Issue 規模で調整。
- **lease 解放（3 経路すべてで解放されること）**:
  1. 正常完了 → `lib/lease-store.sh release issue <issue> <self>` を即時実行。
  2. 失敗 / timeout → 同上で即時 release し、必要なら再 dispatch 対象に戻す。
  3. dispatcher 自身がクラッシュして release を呼べない場合 → lease の **TTL（`LEASE_TTL_LOCAL`）が最終防衛**として stale 掃除で自動回収する（恒久ブロックを作らない）。
- **crash した worker**: merge-ready に到達していなければ未完了として扱い、issue-lease を解放したうえでキューに戻す（次ラウンドで再 dispatch）。

## Responsibility Boundary

| Concern | Owner |
|---------|-------|
| 複数 Issue の並列ディスパッチ・数珠つなぎ・merge 統合 | **full-autopilot**（this skill） |
| 1 Issue の near-green 収束（hand-off で merge-ready まで） | `autopilot`（`--hand-off`） |
| issue / merge lease の排他 | `lib/lease-store.sh`（#316 branch-lease と別 store） |
| branch 単位の write-back 排他 | `hooks/branch-lease-guard.sh`（#316） |
| 並列セッション衝突・`in-progress` ラベル | skill-gate |

full-autopilot は autopilot を**起動するだけ**で、autopilot の判断ロジック（gate・収束・レビュー）は autopilot 側に閉じる。

## Integration

- **Upstream:** `defining-requirements`（人間が壁打ちで `ready-to-go` Issue を queue に積む）
- **Wraps:** `autopilot`（`--hand-off`）
- **Depends on:** `lib/lease-store.sh`, `lib/full-autopilot-dispatch.sh`, `lib/merge-coordinator.sh`, `hooks/branch-lease-guard.sh`（#316）
