# User Stories: full-autopilot の使い勝手再設計（真因0-4 一括）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-0（真因0 — 最大レバー: Issue 起票コスト / Gate ①維持）

**I want to** Issue を意図3点（痛み / 望む結果 / スコープ境界）だけで起票でき、AC・サブタスク・完了条件・User Story は Claude が生成し、人間は AC セットをワンタップ承認するだけにする,
**so that** queue に1件積むコストを下げつつ、AC 承認ゲート（Gate ①: authoring は Claude、approval は人間）と always-sync 経路を壊さずに済む.

<!-- PRD 由来: Outcome / What#1。`templates/issue/{ja,en}/development.yml` を意図シードに軽量化し、Problem/Outcome/スコープを required・AC/サブタスク/完了条件/User Story を任意化。`.github/ISSUE_TEMPLATE/` への always-sync 経路（session-start E2）を壊さない。 -->

### US-1（真因1 — queue 動的化）

**I want to** full-autopilot を走らせながら追加投入した `ready-to-go` Issue を、現行セッションが空きスロット充填時に拾える,
**so that** 走行中に積んだ Issue を次セッションまで待たずに処理できる.

<!-- PRD 由来: Outcome / What#2。`lib/full-autopilot-run.sh:156` の起動時1回 freeze をやめ、空きスロット充填時に `ready-to-go` を再評価する動的 enqueue にする。 -->

### US-2（真因2 — 通知の起動時確認）

**I want to** full-autopilot 起動時に通知先（webhook 等）が確認され session に inject される、または軽量通知が既定有効化される,
**so that** 無人運転中の進捗・エスカレーションが人に届き「起動したら blind」を避けられる.

<!-- PRD 由来: Outcome / What#3。既定 OFF の Discord addon / `FA_NOTIFY_CMD` 機構を、起動時に通知先を一度確認する方針に変更。 -->

### US-3（真因3 — merge-ready 外部二重確認）

**I want to** `merge-ready` 判定が worker 自己申告（`is_error:false`）だけに依存せず、GitHub の `merge-ready` ラベルで二重確認され、ラベル不在なら fail に倒れる,
**so that** 偽陽性 merge（false-green）を外部アンカーで防げる.

<!-- PRD 由来: Outcome / What#4。既定 `FA_RESULT_CMD` に `merge-ready` ラベル照合を追加。 -->

### US-4（真因4 — route-eligibility 必須チェック）

**I want to** skill-gate が route-eligibility を必須チェックし、不適合モードを抑止する（override 可）,
**so that** ユーザーがどのモードを使うべきか縛られ、適切なルートに導かれる.

<!-- PRD 由来: Outcome / What#5。`docs/methodology/route-eligibility.md` の判定を skill-gate で強制する。 -->

### US-5（doc 整合 — DoR 記述の修正）

**I want to** full-autopilot SKILL.md の `ready-to-go` 前提記述が正典 DoR（ready-to-go = DoR ＋ plan review PASS）と整合している,
**so that** ドキュメント間の食い違い（SKILL.md:29 の「ready-to-go の前提 = PRD 承認済み」とのズレ）で混乱しない.

<!-- PRD 由来: Outcome / What#6。`skills/full-autopilot/SKILL.md:29` を正典 `docs/methodology/definition-of-ready.md` に合わせて修正。 -->

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS-1（受け入れテスト整備 — AL-3 deterministic AT gate）

**I want to** US-0〜US-5 の各変更に bats 受け入れテストが付随している,
**so that** AL-3 deterministic AT gate を満たし、各真因の修正が回帰したときに検知できる.

<!-- PRD 由来: What#7。各変更に bats 受け入れテストを追加。 -->
