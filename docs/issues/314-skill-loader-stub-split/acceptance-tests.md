# Acceptance Tests: 全 Skill の SKILL.md ローダー stub 分割（行数バジェット恒久対策）— research

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

> 本 Issue は research。成果物は `docs/methodology/skill-loader-split.md` のみ（Skill 実改変なし）。
> AT は (a) methodology doc が PRD What 1-6 / US FS-1〜FS-6 を網羅すること、(b) CS-1〜CS-3 の構造・非混入・language policy 制約を、
> 既存 `tests/test_phase_test_policy.bats`（AT-300〜AT-312, methodology doc 構造 pin の先例）に倣って機械検証する。
> `[regression]` AT は invariant を assert し、行数・バージョン・日付の point-in-time 値を exact-pin しない（#289 教訓）。
> 実テストファイル（`tests/acceptance/AT-*`）の作成は running-atdd-cycle（Step 4）が担う。本 spec は `[planned]` まで。

## AT-314-1: 標準分割パターンが文書化されている（FS-1）

- [ ] [planned] AT-314-1: skill-loader-split.md に Split Pattern 節と stub/分離の基準が存在する
  - Given: 成果物 `docs/methodology/skill-loader-split.md` が存在する
  - When: `## Split Pattern` 節を読む
  - Then: 「stub に残すもの」「分離するもの」両基準が箇条書きで列挙され、分離先が `docs/methodology/<skill>-*.md` 形式のポインタとして例示されている（`grep -qF 'docs/methodology/'` が成功）

## AT-314-2: 全 Skill 棚卸し表が実測と一致する（FS-2）

- [ ] [planned] AT-314-2a: Skill Inventory 表が全 20 SKILL.md を網羅し行数が実測と一致する
  - Given: skill-loader-split.md に `## Skill Inventory` 表がある
  - When: `for f in skills/*/SKILL.md; do wc -l "$f"; done` の実測行数と表の現行行数列を突き合わせる
  - Then: 表に 20 行（全 SKILL.md）が存在し、各行の現行行数が実測値と一致する

- [ ] [planned] AT-314-2b: 逼迫度しきい値が明示され各 Skill がランク分類されている
  - Given: Skill Inventory 節に逼迫度しきい値の数値定義がある
  - When: 各 Skill 行の逼迫度ランク（CRITICAL/HIGH/MEDIUM/LOW）をしきい値定義に照らす
  - Then: ランクがしきい値定義から機械的に導け、autopilot=CRITICAL（279/280）が含まれる

- [ ] [planned] AT-314-2c: session-start の pin 未設置が finding として記録されている
  - Given: Skill Inventory 表に session-start 行がある
  - When: session-start の pin 上限列と備考を読む
  - Then: pin 上限が "none"（未ガード）と明記され、備考に budget pin 未設置の逼迫リスクが記述されている

## AT-314-3: i18n / 既存 AT 影響分析が方針付きで存在する（FS-3）

- [ ] [planned] AT-314-3a: Impact Analysis が 3 観点を影響＋対応方針で整理している
  - Given: skill-loader-split.md に `## Impact Analysis` 節がある
  - When: string-pin 系 AT / テンプレート同期 / 行数 pin テストの 3 観点を読む
  - Then: 3 観点すべてが区別され、各々に「影響」と「対応方針」が対で記述されている

- [ ] [planned] AT-314-3b: string-pin 移行ルール（両 pin 棚卸し＋@covers 広域化）が明記されている
  - Given: Impact Analysis 節の string-pin 観点
  - When: 検証文字列が detail doc へ移る場合の対応方針を読む
  - Then: 「分離元・分離先の両 pin 棚卸し」と「@covers の付け替え／広域化」が明記されている

## AT-314-4: autopilot が reference implementation として参照されている（FS-4）

- [ ] [planned] AT-314-4: autopilot 先例（#283/#304）の分離実例が表で示されている
  - Given: skill-loader-split.md の Split Pattern または専用節
  - When: autopilot の分離先 detail doc 一覧を読む
  - Then: `autopilot-iron-law.md` 等の実在 detail doc 名が列挙され、各行が「SKILL.md ポインタ ↔ 分離先 doc」の対応になっている

## AT-314-5: 分割後 pin 運用が DEVELOPMENT.md と整合している（FS-5）

- [ ] [planned] AT-314-5: Pin Operation 節が DEVELOPMENT.md ルールを引用し stub/detail 双方の pin 方針を述べる
  - Given: skill-loader-split.md に `## Pin Operation` 節がある
  - When: 分割後の pin 運用記述を読む
  - Then: DEVELOPMENT.md の「SKILL.md Line-Budget Raises（2 回まで・3 回目で loader stub 分割）」が引用され、stub budget pin と分離先構造 pin の双方の設置方針が述べられている

## AT-314-6: 優先度順の適用計画が存在する（FS-6）

- [ ] [planned] AT-314-6: Rollout Plan が逼迫度降順で派生 Issue 計画を示す
  - Given: skill-loader-split.md に `## Rollout Plan` 節がある
  - When: 適用順序の表を読む
  - Then: 逼迫度ランク降順に並び、各行に「対象 Skill / 推定派生 Issue スコープ / 前提依存」が記載され、FS-2 しきい値への依存が明記されている

## AT-314-CS1: 成果物の構造ピン（CS-1）

- [ ] [planned] AT-314-CS1a: skill-loader-split.md が Loaded-by メタコメントで始まる
  - Given: 成果物 `docs/methodology/skill-loader-split.md` が存在する（`test_phase_test_policy.bats` AT-312b に倣う）
  - When: `head -3 docs/methodology/skill-loader-split.md` を読む
  - Then: 冒頭に `> **Loaded by:**` メタコメントが存在する

- [ ] [planned] AT-314-CS1b: docs/methodology/README.md に skill-loader-split.md が登録されている
  - Given: `docs/methodology/README.md` の Documents 表（`test_phase_test_policy.bats` AT-312a に倣う）
  - When: `grep -q 'skill-loader-split' docs/methodology/README.md` を実行
  - Then: 登録行がヒットする（exit 0）

## AT-314-CS2: 実装非混入（CS-2, regression）

- [ ] [planned] [regression] AT-314-CS2: 本 Issue の diff が SKILL.md を 1 行も変更しない
  - Given: 本 Issue ブランチ（research フェーズ）
  - When: `git diff main...HEAD -- skills/` を実行する（invariant: research は Skill 実改変を含まない）
  - Then: 出力が空である（`skills/*/SKILL.md` への変更が存在しない）。※ 特定行数・特定 SHA を pin せず「skills/ 配下 diff 空」という不変条件を assert する

## AT-314-CS3: language policy 準拠（CS-3, regression）

- [ ] [planned] [regression] AT-314-CS3a: skill-loader-split.md に日本語文字が含まれない
  - Given: 成果物 `docs/methodology/skill-loader-split.md`（`test_phase_test_policy.bats` AT-311 に倣う・English-only invariant）
  - When: `grep -P '[ぁ-んァ-ヶ一-龥]' docs/methodology/skill-loader-split.md` を実行する
  - Then: ヒットが無い（exit 1 / 日本語文字 0）。LLM-facing doc の English-only を恒久 invariant として監視

- [ ] [planned] [regression] AT-314-CS3b: skill-loader-split.md の `*.ja.md` 翻訳が存在しない
  - Given: `docs/methodology/` 配下
  - When: `ls docs/methodology/skill-loader-split.ja.md` を確認する（invariant: LLM-facing は翻訳を持たない）
  - Then: ファイルが存在しない（翻訳同期負債を発生させない）

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
