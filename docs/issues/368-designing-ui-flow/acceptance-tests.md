# Acceptance Tests: 新スキル `designing-ui` + 方法論 doc 2 本 — UI/UX 設計フロー

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

## AT-368-1: designing-ui スキルの起動可能性（US-1）

- [ ] [planned] AT-368-1: `atdd-kit:designing-ui` が起動可能なスキルとして登録されている
  - Given: リポジトリに `skills/designing-ui/SKILL.md` が存在する
  - When: SKILL.md の frontmatter を検査する
  - Then: `name: designing-ui` であり、`description` が `Use when` で始まる（トリガー条件のみ・ワークフロー要約を含まない）

## AT-368-2: UI 要件フェーズ成果物の定義（US-2）

- [ ] [planned] AT-368-2: SKILL.md が UI 要件フェーズと `ui-requirements.md` 生成を規定する
  - Given: `skills/designing-ui/SKILL.md`
  - When: 成果物定義と UI 要件フェーズ記述を検査する
  - Then: `docs/issues/<NNN>/ui-requirements.md` が成果物として記述され、機能要件と画面の対応を問いで引き出す旨が存在する

## AT-368-3: 情報設計フェーズ成果物の定義（US-3）

- [ ] [planned] AT-368-3: SKILL.md が情報設計フェーズと `information-architecture.md` 生成を規定する
  - Given: `skills/designing-ui/SKILL.md`
  - When: 情報設計フェーズ記述を検査する
  - Then: `docs/issues/<NNN>/information-architecture.md` が成果物として記述され、ワイヤー着手前に画面単位を確定する旨が存在する

## AT-368-4: ワイヤーフレームフェーズ成果物の定義（US-4）

- [ ] [planned] AT-368-4: SKILL.md がワイヤーフレームフェーズと `wireframes.md` 生成を規定する
  - Given: `skills/designing-ui/SKILL.md`
  - When: ワイヤーフレームフェーズ記述を検査する
  - Then: `docs/issues/<NNN>/wireframes.md` が成果物として記述され、装飾なしで骨格・配置・遷移を記述する旨が存在する

## AT-368-5: ビジュアル方針フェーズ成果物の定義（US-5）

- [ ] [planned] AT-368-5: SKILL.md がビジュアル方針フェーズと `visual-policy.md` 生成を規定する
  - Given: `skills/designing-ui/SKILL.md`
  - When: ビジュアル方針フェーズ記述を検査する
  - Then: `docs/issues/<NNN>/visual-policy.md` が成果物として記述され、プラットフォームと Design system の選択根拠（HIG / Material Design / Baseline 参照）を記録する旨が存在する

## AT-368-6: 実装連携フェーズ成果物の定義（US-6）

- [ ] [planned] AT-368-6: SKILL.md が実装連携フェーズと `implementation-handoff.md` 生成を規定する
  - Given: `skills/designing-ui/SKILL.md`
  - When: 実装連携フェーズ記述を検査する
  - Then: `docs/issues/<NNN>/implementation-handoff.md` が成果物として記述され、コンポーネント・トークン・アクセシビリティ注記の handoff 粒度が示される

## AT-368-7: 引き出し型 5 フェーズ順序の駆動（US-7）

- [ ] [planned] AT-368-7: SKILL.md が 5 フェーズを引き出し型で順に駆動する
  - Given: `skills/designing-ui/SKILL.md`
  - When: フェーズ順序と対話スタイル記述を検査する
  - Then: UI 要件確認 → 情報設計 → ワイヤーフレーム → ビジュアル方針 → 実装連携 の 5 フェーズが順に記述され、引き出し型（pull）対話である旨が明記される

## AT-368-8: 方法論 doc1 の存在と骨格規律（US-8）

- [ ] [planned] AT-368-8: `designing-ui-doc1.md` が UI 要件・情報設計・ワイヤーフレームの規律（装飾なし）を示す
  - Given: `docs/methodology/designing-ui-doc1.md`
  - When: doc1 の本文を検査する
  - Then: ファイルが存在し、UI 要件・情報設計・ワイヤーフレームの規律を含み、装飾（色・フォント・余白）をこのフェーズに含めない旨が記述される

## AT-368-9: 方法論 doc2 の存在と装飾・実装連携規律（US-9）

- [ ] [planned] AT-368-9: `designing-ui-doc2.md` がビジュアル方針・プラットフォーム作法・実装連携の規律を示す
  - Given: `docs/methodology/designing-ui-doc2.md`
  - When: doc2 の本文を検査する
  - Then: ファイルが存在し、ビジュアル方針・プラットフォーム別作法（HIG / Material Design / Baseline）・Design system 再利用・実装連携の規律を含む

## AT-368-10: writing-design-doc との住み分け明記（US-10）

- [ ] [planned] AT-368-10: SKILL.md が designing-ui と writing-design-doc の責任境界を明記する
  - Given: `skills/designing-ui/SKILL.md`
  - When: 責任境界（Responsibility Boundary）記述を検査する
  - Then: 「画面設計の工程駆動 = designing-ui」「技術アーキテクチャのトレードオフ記録 = writing-design-doc」の住み分けが明記される

## AT-368-11: 概念とプラットフォーム作法の分離（CS-1）

- [ ] [planned] AT-368-11: SKILL.md と doc に「概念=プロダクト側 / 作法=プラットフォーム / [独自] 明示」の中核思想が体現される
  - Given: `skills/designing-ui/SKILL.md`（および doc1/doc2）
  - When: 中核思想記述を検査する
  - Then: 「何を出すか=プロダクト側(PRD)」「どう見せるか=対象プラットフォーム規約」「独自判断は [独自] と明示」の記述が存在する

## AT-368-12: アクセシビリティの横串適用（CS-2）

- [ ] [planned] AT-368-12: アクセシビリティがフェーズ横断の哲学としてワイヤーフェーズから組み込まれる
  - Given: `skills/designing-ui/SKILL.md` と `docs/methodology/designing-ui-doc2.md`
  - When: アクセシビリティ記述を検査する
  - Then: `WAI-ARIA` / `WCAG 2.2` / `JIS Z 8520` が言及され、後付けではなくワイヤーフェーズから組み込む旨が記述される

## AT-368-13: designing-ui のスコープ限定（CS-3）

- [ ] [planned] AT-368-13: SKILL.md が UI 設計成果物のみを生成しコード実装・AT 実装・Plan 作成を担わない責任境界を守る
  - Given: `skills/designing-ui/SKILL.md`
  - When: スコープ・責任境界記述を検査する
  - Then: コード実装・Acceptance Test 実装・Plan 作成を担わず、UI 設計成果物のみを生成する旨が明記される

## AT-368-14: 成果物配置と命名の一貫性（CS-4）

- [ ] [planned] AT-368-14: 成果物が承認済み命名で `docs/issues/<NNN>/` 配下に、方法論 doc が `docs/methodology/` 配下に配置される
  - Given: `skills/designing-ui/SKILL.md` とリポジトリ構成
  - When: 成果物パスと doc 配置を検査する
  - Then: 5 成果物が `docs/issues/<NNN>/{ui-requirements,information-architecture,wireframes,visual-policy,implementation-handoff}.md` の承認済み命名で記述され、doc1/doc2 が `docs/methodology/` 配下に存在する

## AT-368-15: 構造検証 BATS pin（CS-5）

- [ ] [planned] AT-368-15: SKILL.md・doc1・doc2 の存在を確認する BATS pin が追加される
  - Given: 新規 BATS `tests/test_designing_ui_skill.bats`
  - When: `bats tests/test_designing_ui_skill.bats` を実行する
  - Then: `skills/designing-ui/SKILL.md`・`docs/methodology/designing-ui-doc1.md`・`docs/methodology/designing-ui-doc2.md` の存在を確認する pin が green で通過する

## AT-368-16: バージョンと変更記録の整合（CS-6）— regression 不変条件

- [ ] [planned] AT-368-16: plugin.json の version が CHANGELOG 最上位リリース見出しと一致し、新スキルが記録される
  - Given: `.claude-plugin/plugin.json` と `CHANGELOG.md`（マージ後）
  - When: version と最上位リリース見出しを突き合わせる
  - Then: plugin.json の `version` が CHANGELOG の最上位リリース見出しの値と等しく（point-in-time な特定値には固定しない不変条件）、`designing-ui` スキル追加が CHANGELOG に記録されている
