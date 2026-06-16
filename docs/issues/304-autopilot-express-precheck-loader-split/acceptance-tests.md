# Acceptance Tests: autopilot SKILL.md ローダ分割 ＋ express 適格プリチェック

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [regression] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。
     regression AT は将来の全ブランチで永続実行されるため、時点固定値（version 番号・日付・行数の数値）を
     exact-pin せず不変条件を assert する（#289）。-->

## AT-100: 共有判定基準の抽出（FS-1）

- [x] [regression] AT-101: route-eligibility.md が単一ソースとして存在する
  - Given: 経路判定基準は従来 session-start/SKILL.md に散文で 1 箇所だけ存在した
  - When: `docs/methodology/route-eligibility.md` を読む
  - Then: express 適格信号 / autopilot 信号 / 曖昧時フォールバック / 不変条件（推奨のみ・auto-route しない）の 4 要素がすべて記載されている

- [x] [regression] AT-102: session-start が信号を二重定義せず route-eligibility.md を参照する
  - Given: route-eligibility.md に判定信号が集約された。#302 既存 pin（`tests/test_session_start_task_recommendation.bats` の AC2/AC3/AC4）は信号文字列を grep しているため、参照先を route-eligibility.md へ追従させる前提（AT-204 参照）
  - When: `skills/session-start/SKILL.md` を読む
  - Then: Step 3 経路判定が route-eligibility.md への参照に置換され、判定信号の本文が session-start に重複して残っていない（信号は route-eligibility.md が単一ソース）。Step 3 見出し・推奨経路列ヘッダは構造として session-start に残る

## AT-200: autopilot SKILL.md のローダ分割（FS-2 / CS-2）

- [x] [regression] AT-201: 分割後の autopilot SKILL.md が行バジェット pin を満たす
  - Given: 分割前は 280/280 行で第 3 回引き上げ不可
  - When: `wc -l skills/autopilot/SKILL.md` を取る
  - Then: 行数が行バジェット pin の上限（≤280）以下であり、行バジェット pin の数値自体は引き上げられていない（不変条件: pin 上限は不変）

- [x] [regression] AT-202: 分割後も autopilot BATS 構造 pin が全 green
  - Given: SKILL.md には BATS が grep で直接参照する pin 文字列（canonical Workflow script・args ガード・freeze/audit 配管・User gates 番号リスト）が多数ある
  - When: `bats tests/test_autopilot_skill.bats` を実行する
  - Then: 全テストが green（pin が指す挙動規定が分割で漏れず、本体据え置き or 参照先 doc 追従のいずれかで担保されている）

- [x] [regression] AT-203: SKILL.md の docs ポインタが実在 doc を指す
  - Given: stub 化により SKILL.md は docs/methodology へのポインタを持つ
  - When: SKILL.md 中の `docs/methodology/*.md` 参照を実ファイルと照合する
  - Then: すべての参照が実在ファイルを指す（リンク切れなし）

- [x] [regression] AT-204: session-start 経路判定 BATS スイートが FS-1 後も green（#302 pin の参照先追従）
  - Given: FS-1 で session-start Step 3 の信号本文を route-eligibility.md へ移し、session-start は doc 参照へ置換した。`tests/test_session_start_task_recommendation.bats` の #302-AC2/AC3/AC4 5 件は信号文字列（docs/README/typo・CI/hooks/depend/security・label/keyword/LLM・doubt/曖昧・推奨のみ）を grep pin している（単一の `test_session_start_skill.bats` は実在せず、session-start テストは 6 ファイルに分割済み）
  - When: `bats tests/test_session_start_task_recommendation.bats` を実行する
  - Then: 全テストが green。信号 grep の 5 pin は grep ターゲットが route-eligibility.md へ振り替えられて green を維持し（pin の削除・緩和ではなく参照先更新）、`#302-AC1` 推奨経路列ヘッダと `#302-AC2: Step 3 見出し存在` は session-start 本体に残る構造として不変のまま green

## AT-300: express 適格プリチェック（FS-3）

- [x] [regression] AT-301: express 適格 Issue で続行確認を一度だけ提示する
  - Given: 直接 `/atdd-kit:autopilot <issue>` 起動・対象 Issue が route-eligibility.md 基準で express 適格（doc-grade）
  - When: autopilot がプリチェックを評価する
  - Then: 「この Issue は express の方が低コストです。autopilot で続行しますか？（ok で続行）」を一度だけ提示し、明示続行が無ければ進めない

- [x] [regression] AT-302: express 非適格 Issue では無言で従来どおり続行する
  - Given: 対象 Issue が express 適格信号を満たさない
  - When: autopilot がプリチェックを評価する
  - Then: 続行確認を提示せず、従来どおり autopilot を続行する

- [x] [regression] AT-303: プリチェックは route-eligibility.md を判定基準として参照する
  - Given: 判定基準は route-eligibility.md に集約されている
  - When: autopilot SKILL.md（または移設先 doc）のプリチェック記述を読む
  - Then: 判定が route-eligibility.md を参照し、autopilot 側に判定信号を inline 複製していない（二重管理なし）

## AT-400: 不変条件（CS-1 / CS-3）

- [x] [regression] AT-401: User gate は exactly three のまま（AL-1 堅持）
  - Given: express プリチェックは Gate ①（requirements approval）の手前の pre-flight advisory
  - When: autopilot SKILL.md の User gates 番号リストを数える
  - Then: gate 数は 3 のまま（プリチェックは gate にカウントされない・4 つに増えない）

- [x] [regression] AT-402: auto-route 禁止（推奨のみ）
  - Given: #302 Q3 と整合し、ユーザーが経路の最終選択権を保持する
  - When: プリチェック記述を読む
  - Then: express への自動切替（auto-route）を一切行わず、提示までに留めることが明記されている

- [x] [regression] AT-403: プリチェックは Gate ① の手前に位置する
  - Given: pre-flight advisory として Gate ① より前に評価される
  - When: autopilot Flow / SKILL.md のステップ順序を読む
  - Then: プリチェックが requirements approval（Gate ①）より前に位置する

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [regression] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
