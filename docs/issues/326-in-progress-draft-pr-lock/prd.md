# PRD: Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ

## Problem

**現状どうなっているか**

full-autopilot の dispatch（`lib/full-autopilot-dispatch.sh` の `cmd_select`）は、同一 Issue の二重 claim を防ぐ排他を **`/tmp` の issue-lease（揮発・TTL・dispatcher session スコープ）だけ**に依存しており、**GitHub state（open PR / `in-progress` ラベル）を一切参照しない**。

また `in-progress` ラベルの付与は現状 discover（壁打ち）step で行う設計（`docs/workflow/issue-ready-flow.md` step 2 "Acquires in-progress lock"）で、**Draft PR の作成とは連動していない**。skill-gate の衝突検知も label ではなく worktree のファイルシステム走査（`docs/issues/<N>/`）に依存しており、ラベルが真実源として機能していない。

**それによって何が困るか**

1. **真実源のずれ** — Draft PR がある＝実装中、にもかかわらず `in-progress` が付かないケースが生じる。実例: #324 は Draft PR #325 があるのに `in-progress` ラベルなし（discover を経ず fast-batch で実装に進んだため）。GitHub state を見ても「この Issue は着手済みか」が判定できない。
2. **二重 dispatch リスク** — dispatcher がクラッシュして lease TTL が切れた後に復帰すると、Draft PR ＋ 作業が残っているのに揮発 lease は消えており、同一 Issue を再 dispatch して headless worker を二重起動しうる。救済は #316 `branch-lease-guard`（push を hard block）のみで、worker は無駄に走ってから書き戻しの瞬間に壁に当たる（計算資源の空費）。

## Why now

full-autopilot（#318, v3.25.0）が無人並列で複数 Issue を回す運用に入ったため、二重 dispatch の冪等ガード不在が実害（無駄な worker 起動・トークン空費）に直結するようになった。#324/#325 で「Draft PR があるのに in-progress なし」が実際に観測され、真実源のずれが顕在化している。

## Outcome

- GitHub state（open PR の有無・`in-progress` ラベル）が「その Issue は着手済みか」の真実源として機能する。
- Draft PR が存在する Issue に `in-progress` が**必ず**付く（経路＝discover / autopilot / fast-batch を問わず）。
- full-autopilot dispatch が、open PR または `in-progress` を持つ Issue を select 対象から**冪等に除外**する。揮発 lease がクラッシュ復帰で消えても二重 dispatch しない。

## What

### ① Draft PR 作成時の `in-progress` 自動付与
Draft PR が作られた時点で、リンクされた Issue へ `in-progress` ラベルを付与する。Issue 番号は PR body の `Closes #<N>` または branch 名プレフィックス `<N>-...` から解決する。**付与メカニズムは hook（推奨）**: `gh pr create --draft` を検知する PostToolUse hook で自動付与する（既存 hook 群＝#316 branch-lease-guard 等と同じアーキテクチャ。skill 群は未編集のまま＝skill-gate を概念上の owner に保つ）。

### ② full-autopilot dispatch の GitHub-state プリフィルタ
dispatch の候補列挙に「open PR を持つ Issue / `in-progress` ラベルを持つ Issue は select 対象から除外」するプリフィルタを追加する。`cmd_select` の**純粋性を保つ**ため、GitHub 問い合わせは呼び出し側（`full-autopilot-run.sh`）か **env 注入可能なフック**として実装し、`cmd_select` 自体は lease-store 合成の純粋ロジックのまま据え置く（既存の env 注入パターンを踏襲）。

## Non-Goals

- **`in-progress` の除去ライフサイクル全般** — merge 時は Issue が close され open キューから自然に外れるため、付与を主眼とする。放棄 Draft PR（close-without-merge）の除去は ④ Open Question で要否を判断（最小スコープなら別 Issue へ defer）。
- **skill-gate の衝突検知を label ベースへ全面移行** — 本 Issue は「ラベルを真実源に近づける」ところまで。FS 走査からの全面置換は別 Issue。
- **discover step の既存 in-progress 付与の削除** — Draft PR 付与は補完（fast-batch 等 discover を飛ばす経路の安全網）であり、discover 側は据え置く。二重付与は冪等で害なし。

## Open Questions

1. **付与メカニズム（要判断）** — (a) PostToolUse hook で `gh pr create --draft` を検知し自動付与【推奨】 / (b) `docs/workflow/workflow-detail.md` の Draft PR Locking 手順＋各スキルに付与を明記（ドキュメント駆動） / (c) skill-gate に「Draft PR 検知時に in-progress を同期」する責務を新設。推奨は (a)（robust・skill 非編集・既存 hook 流儀）。
2. **dispatch プリフィルタの実装位置** — `cmd_select` の純粋性維持のため、(b) 呼び出し側＋env 注入を推奨。`cmd_select` 内に直接 `gh` を入れる (a) はテスタビリティを損なうため非推奨。→ 技術判断として (b) で進める想定（異論あれば指摘）。
3. **「busy」判定の GitHub 問い合わせ単位** — 候補ごとに `gh pr list --search "<N> in:title"` / `gh issue view <N> --json labels` を引くか、一括取得してから突合するか（API 回数 vs 実装簡潔性）。→ 実装詳細として design phase で確定。
4. **放棄 Draft PR の in-progress 除去** — 本 Issue に含める（hook が `gh pr close` / merge でも除去）か、別 Issue へ defer するか。→ **要判断**（最小スコープを好むなら defer）。
