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
- Draft PR が merge されず close（放棄）された Issue からは `in-progress` が**除去**され、ラベルが実態に追従する（付与と除去の対称ライフサイクル）。
- full-autopilot dispatch が、open PR または `in-progress` を持つ Issue を select 対象から**冪等に除外**する。揮発 lease がクラッシュ復帰で消えても二重 dispatch しない。

## What

### ① Draft PR 作成時の `in-progress` 自動付与（確定: hook）
Draft PR が作られた時点で、リンクされた Issue へ `in-progress` ラベルを付与する。Issue 番号は PR body の `Closes #<N>` または branch 名プレフィックス `<N>-...` から解決する。**付与メカニズムは hook**: `gh pr create --draft` を検知する PostToolUse hook で自動付与する（既存 hook 群＝#316 branch-lease-guard 等と同じアーキテクチャ。skill 群は未編集のまま＝skill-gate を概念上の owner に保つ）。

### ③ Draft PR 放棄（close/merge）時の `in-progress` 除去（確定: 本 Issue に含める）
同じ hook 機構で、Draft PR が merge されず close された時点（`gh pr close`）にリンク Issue から `in-progress` を除去する。merge 経路は Issue が close され open キューから自然消滅するため除去は必須ではないが、対称性のため merge 時も冪等に除去してよい（既に label が無い場合は no-op）。付与と除去で同じ Issue 番号解決ロジックを共有する。

### ② full-autopilot dispatch の GitHub-state プリフィルタ
dispatch の候補列挙に「open PR を持つ Issue / `in-progress` ラベルを持つ Issue は select 対象から除外」するプリフィルタを追加する。`cmd_select` の**純粋性を保つ**ため、GitHub 問い合わせは呼び出し側（`full-autopilot-run.sh`）か **env 注入可能なフック**として実装し、`cmd_select` 自体は lease-store 合成の純粋ロジックのまま据え置く（既存の env 注入パターンを踏襲）。

## Non-Goals

- **skill-gate の衝突検知を label ベースへ全面移行** — 本 Issue は「ラベルを真実源に近づける」ところまで。FS 走査からの全面置換は別 Issue。
- **discover step の既存 in-progress 付与の削除** — Draft PR 付与は補完（fast-batch 等 discover を飛ばす経路の安全網）であり、discover 側は据え置く。二重付与は冪等で害なし。

## Open Questions（解決済み）

1. **付与メカニズム** — ✅ **(a) PostToolUse hook で `gh pr create --draft` を検知し自動付与**（robust・skill 非編集・既存 hook 流儀）。
2. **dispatch プリフィルタの実装位置** — ✅ **(b) 呼び出し側＋env 注入**。`cmd_select` の純粋性を維持し、GitHub 問い合わせは注入可能にしてテスタビリティを保つ。
3. **「busy」判定の GitHub 問い合わせ単位** — 候補ごとに引くか一括取得して突合するか（API 回数 vs 実装簡潔性）。→ 実装詳細として design phase で確定。
4. **放棄 Draft PR の in-progress 除去** — ✅ **本 Issue に含める**（hook が `gh pr close`/merge 時にも除去。What ③）。
