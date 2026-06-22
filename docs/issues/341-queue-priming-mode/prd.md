# PRD: batch-discovery — 壁打ちを最前倒し一括化し ready-to-go 準備を並列バックグラウンド自走させる

## Problem

複数 Issue をまとめて full-autopilot のキュー（`ready-to-go`）に積みたい実運用で、**人間の壁打ち時間がボトルネック**になる。

- **現状（autopilot）**: 1 Issue 逐次。Gate ①（要件壁打ち）が Issue ごとに対話的・ブロッキング。N 件あると壁打ちが N 回直列に発生し、人間の拘束時間が件数に比例する。
- **現状（full-autopilot）**: 入力は **すでに `ready-to-go` 済み**の Issue 群。`ready-to-go` 化（= DoR ＋ plan review PASS の準備）そのものは射程外で、結局 per-issue 壁打ちに戻る。
- **困りごと**: 「ready-to-go 化の準備」を、人間の壁打ちを最小化しつつ複数 Issue 並列で進めるモードが存在しない。人間の関与が「Issue ごとに逐次」なので拘束時間が件数比例になる。

stockbot-jp の実運用（板読みトラック等 7+ Issue を一括 ready-to-go 化）で顕在化。本機能が無いため、セッション内で worktree 並列 worker を手組みして代替している。

## Why now

stockbot-jp の実運用で 7+ Issue 一括投入の痛みが顕在化し、毎回その場で worktree 並列 worker を手組みする運用負債が積み上がっている。full-autopilot（#318/#329）と worktree 播種（#329）・lease/dispatcher 基盤が出揃った今、それらを準備フェーズに転用すれば最小の新規実装で構築でき、機会コストが最小。放置するほど「壁打ちが件数比例」のまま運用知見が積み上がる。

## Outcome

- **主指標（合否基準）**: N 件投入しても、**人間の対話回数が Issue 件数に依存せず定数回に圧縮される**（理想は front-loaded 壁打ち1回 ＋ 必要時のみ最終承認1回）。
- **副次条件**: 壁打ち解消後、対象 Issue が **worktree 隔離で並列**に PRD→US→plan+AT→plan review PASS→Draft PR→`ready-to-go` まで自走し、full-autopilot キューへ一貫して受け渡される。
- 既存 autopilot / full-autopilot の三ゲート不変条件（AL-1）との整合が文書化される。

## What

1. **新スキル `batch-discovery`**（独立スキル）。`defining-requirements` の壁打ちを **複数 Issue 横断でバッチ化**する。full-autopilot 本体は書き換えない（疎結合 C3）。
2. **横断バッチ壁打ち（front-loaded・人間 1 回）**: 対象 Issue 群を全読み込み（自律）→ 各 Issue で **人間にしか決められない点だけ**（トレードオフ / 割り切り / スコープ取捨 / リスク許容度 / 合否基準）を抽出（自律）→ **全 Issue 横断で 1 バッチ提示**し人間が一度のセッションで全部答える。Dialog economy（#254）の「人間判断点のみ・最小質問」を N Issue 分に拡張、AskUserQuestion の multi-question を活用。Issue 本文・docs から導出可能な要件は質問せず自律ドラフト。
3. **並列自走（バックグラウンド）**: 疑問が解消した Issue から順に、**worktree 隔離の headless worker を並列起動**して ready-to-go 準備（PRD→US→plan+AT→reviewing-deliverables PASS→Draft PR→`ready-to-go`）を自走。full-autopilot の dispatcher / lease-store / worktree 播種（#329）の lib を準備フェーズへ**転用**する。
4. **実装順序の記録による軽量な順序制御**: 依存関係のある Issue 群（keystone→後続）では、**実装順序を共有真実源に記録し、その順で worker を進める**軽量方式。フルな barrier / 動的依存解決は採らない。
5. **選別ピックアップ式の最終承認ゲート（人間・最大 1 回）**: 準備完了後、全成果物の一括承認は求めず、準備フェーズ（reviewer-oracle 含む）が検出した **「ユーザーレビューで判断が覆りうる点（リスク / トレードオフ / 重要な割り切り）」だけを選別提示**し、その点について承認を得てから `ready-to-go` を付与する。覆りうる点が無ければ最終承認はスキップ可能（= 定数回をさらに削減）。
6. **AL-1 整合の文書化**: 準備フェーズの人間ゲートを「横断バッチ壁打ち 1 回（Gate ① 集約）＋ 選別最終承認 最大 1 回（Gate ② 相当を覆りうる点に絞って集約）」として AL-1（3 ゲート不変条件）との整合を明文化。Gate ③（merge）は full-autopilot 側の責務として不変。
7. 各変更に bats 受け入れテストを追加（AL-3 deterministic AT gate を満たす）。

## Non-Goals

- **full-autopilot 本体（収束レール・merge coordinator）の再設計**はしない — batch-discovery は準備フェーズ専用の薄いスキルで、消化は full-autopilot に手渡す（疎結合 C3）。
- **フルな依存解決 / barrier 同期**はしない — MVP は「実装順序の記録 → その順で進める」軽量方式に留める。動的な依存グラフ解決・設計依存の双方向 barrier は将来 Issue。
- **AC 承認ゲートそのものの撤廃**はしない — 横断バッチに集約するだけで、false-green の外部アンカー（AL-1 Gate ① の AC 承認）は保つ。
- **キューの GitHub webhook 化**は対象外（full-autopilot #329 の動的 enqueue で足りる）。
- **`full-autopilot --prime` サブモード化**は採らない（独立スキル `batch-discovery` とする / Open Question で決定済み）。

## Open Questions

- 横断バッチ壁打ちで、AskUserQuestion の 1 メッセージ最大 4 質問という制約を N Issue × 複数判断点でどう束ねるか（Issue ごとにグルーピングするか、判断軸ごとに横断束ねるか）。→ plan で詰める。
- 「ユーザーレビューで覆りうる点」の検出基準（どの finding 種別 / priority を最終承認対象に昇格させるか）。→ plan で詰める。デフォルトは「トレードオフ・意図的割り切り・スコープ取捨に該当する finding」を昇格。
- 実装順序の記録先（research doc / 専用 manifest ファイル / Issue 本文のメタ）と、worker dispatcher がそれを読む経路。→ plan で詰める。
- 準備フェーズ worker の収束オラクル — ready-to-go の DoR（plan review PASS）をどう deterministic に判定するか（full-autopilot の `__default_result` merge-ready 照合の類推）。→ plan で詰める。
