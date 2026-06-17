# PRD: bugfix 専用の軽量ルート（フル機能ルートと分離）

## Problem

現状 autopilot / フロースキルは、機能追加もバグ修正も **同じ単一ルート**（PRD → User Stories → Plan + Acceptance Tests → ATDD → レビュー → マージ）を通る。

バグ修正の本質は確立した方法論上 **「再現 → 根本原因特定 → 最小修正 → 回帰テスト追加」**（Zeller『Why Programs Fail: A Guide to Systematic Debugging』、Scientific Debugging）であり、フル PRD / User Stories は過剰になる。とりわけ Connextra 形式の User Story（「〜したい so that 〜」）はバグに対してほぼ定型化し、本質（再現・根本原因・回帰ガード）に直行できない。

その結果:
- バグ修正のたびに空回りする成果物（Connextra US 等）を作らされ、最短工程を取れない。
- 「報告されたバグが本当に再現するか」を実ツールで確かめる工程が単一ルートに明示的な居場所を持たない（`bug` Phase 4 は「再現」と述べるが駆動ツールが曖昧）。

## Why now

- #302（autopilot/express ルーティングステップ）と #305（User gate ワンタップ承認）が既にマージされ、**カテゴリ別ルートを載せる基盤が揃った**。
- 実例（stockbot-jp）でバグ修正にフル PRD→US→Plan→AT→ATDD を通し、US がほぼ定型で価値が薄く、本質に直行したかったという具体的痛みがある。
- autopilot の自律収束が普及するほど、カテゴリに合わない過剰工程のコストが積み上がる。今ルートを分離すれば以後のバグ修正すべてに効く。

## Outcome

完了時に以下が達成されている:

- **bugfix 専用の軽量ルートが存在し**、`再現確認（実ツール駆動）→ 根本原因診断 → 最小修正 → 回帰テスト green` の最短工程で回る。PRD / User Stories / Plan の作成を **スキップ** する。
- ルートは **既存スキルの再利用のみ**で構成され（重複ゼロ）、新規のメソドロジー・ステップ・スキルを増やさない。新設するのは既存スキルを束ねる **軽量オーケストレーションスキル 1 つ** と、#302 ルーティング拡張、bugfix 用 autopilot オラクルのみ。
- bugfix ルートは **autopilot で自律収束**でき、収束オラクル = **回帰テスト green ＋ 既存テスト非破壊（既存回帰なし）**（再現テストが赤→修正後に緑、を含む）。
- **再現確認が実ツール駆動**（web=Playwright CLI、iOS=Xcode/simulator MCP、other=CLI/スクリプト実行）で、報告バグの再現を firsthand 証拠で確認する工程として明示される。
- バグだと思ったら設計判断が要る大物だった場合に、**フル機能ルートへ昇格**する基準が定義されている。

## What

スコープ内（bugfix ルートのみ。flaky は次 Issue）:

1. **専用オーケストレーションスキルの新設**（仮称 `skills/fixing-bugs`）。既存スキルを次の順に連鎖し、`defining-requirements` / `extracting-user-stories` / `writing-plan-and-tests` を **スキップ**する:
   `bug`（intake / Issue 化 / トリアージ）→ `debugging`（Scientific Debugging で根本原因診断・分類 A/B/C）→ `running-atdd-cycle`（最小修正 ＋ 回帰テスト）→ `reviewing-deliverables`（レビュー）→ `merging-and-deploying`（User マージゲート）。

2. **再現工程の定義（2 層）**。新オーケストレーションスキルが platform-aware に配線する:
   - **1a. 再現確認（経験的・ツール駆動）** — `.claude/config.yml` の `platform` に応じ、web=Playwright CLI（`playwright-cli` / `verify` スキル）、iOS=Xcode/simulator MCP（＋`sim-pool`）、other=CLI/スクリプト実行 で実システムを動かし、報告バグが再現するか firsthand 証拠で確認する。
   - **1b. 失敗テストへの符号化** — 確認できた再現を **実行可能な failing test** に落とし、autopilot オラクルのアンカー（赤→修正後に緑）とする。

3. **#302 ルーティングの拡張**。Issue ラベル（`type:bug` 等）＋キーワード＋タスク内容から bugfix ルートを自動判定し、低確信時は User に確認（#305 ワンタップと整合）。明示コマンド（例 `/atdd-kit:autofix`）も併設。

4. **autopilot 対象化**。bugfix 用の収束オラクル = `回帰テスト green ＋ 既存回帰なし（＋再現テスト赤→緑）`。User gate は最小（原因合意 = 任意 ＋ マージ）。

5. **フル機能ルートへの昇格基準**。`debugging` の Root Cause 分類が **Type A（AC Gap = 仕様/設計判断が必要）** の場合、bugfix 軽量ルートを離脱し `defining-requirements` 起点のフル機能ルートへ昇格する（既存の debugging→defining-requirements 連鎖を流用）。

## Non-Goals

- **flaky test fix ルート** — 次 Issue に分離。診断/回帰の背骨を bugfix ルートで先に確立し、その上に「非決定性の分類 → 決定化 → 反復検証」を載せる方が土台が安定するため。
- **既存 `bug` / `debugging` / `running-atdd-cycle` 等の本質的書き換え** — 再利用のみ。Issue 本文の「重複させない」方針に従う（必要な追補は新オーケストレーションスキル側に置く）。
- **新規メソドロジー・ステップ・スキルの追加** — リサーチで全工程が既存スキルにマッピング済み。再現確認も既存 `verify`/`playwright-cli`/Xcode MCP の再利用で賄う。
- **マージの自動化** — マージは常に User gate（autopilot Iron Law AL-1）を維持する。

## Open Questions

- 新オーケストレーションスキルの正式名称（`fixing-bugs` / `autofix-bug` 等）— plan で確定。
- `platform: other`（CLI/bash プロジェクト。atdd-kit 自身を含む）での再現確認ツールの具体化（bats / スクリプト実行のどこまでを必須とするか）— plan で確定。
- 原因合意ゲートを「任意」とするか「Type C 以外は任意・Type A は昇格で必須化」とするかの線引き — plan で確定。
- ルーティングの自動判定で bugfix と通常 enhancement の境界をどう閾値化するか（誤判定時の User 確認フロー）— plan で確定。
