# PRD: 新スキル `designing-ui` + 方法論 doc 2 本 — UI/UX 設計フロー（機能要件→UI要件→情報設計→ワイヤー→ビジュアル方針→実装連携）を新設

## Problem

`skills/writing-design-doc/SKILL.md` は**技術設計 doc**（アーキテクチャ上のトレードオフ記録）を担う。しかし GUI を持つプロダクトを開発するとき、**機能要件をどのように画面へ落とすか**——UI 要件の定義、情報設計、ワイヤーフレーム、ビジュアル方針、実装連携——を導く方法論が atdd-kit に存在しない。

結果として、プロダクト側が PRD を承認した後、UI 設計の工程が各自の属人的なやり方に委ねられ、6 ステップ ATDD フローとの接続点も曖昧になる。

1. **現状**: `defining-requirements` → `writing-plan-and-tests` の間で UI/UX 設計の工程を担うスキルも方法論 doc もない。
2. **困ること**: 画面を設計する意思決定（情報設計・ワイヤー・ビジュアル選択）が暗黙知になり、AT 設計が UI の構造を前提にできない。

## Why now

atdd-kit が GUI プロダクト（Web / iOS）のプロジェクトに dogfood として使われ始めており（`setup-web` / `setup-ios` スキルが既に存在）、UI 設計フェーズの穴が毎 Issue で繰り返し生じる。`writing-plan-and-tests` は計画フェーズを担うが、その入力として「UI 要件・ワイヤー・ビジュアル方針」が揃っていない状態で呼ばれるケースが増えている。早期に方法論を確立することで、後続の AT 設計精度と実装品質を底上げできる。

## Outcome

- 新スキル `designing-ui` が `skills/designing-ui/SKILL.md` として追加され、`claude skill atdd-kit:designing-ui <issue>` で起動可能になる
- 方法論 doc 2 本が `docs/methodology/designing-ui-doc1.md`・`docs/methodology/designing-ui-doc2.md` として追加される
  - doc1: UI 要件・情報設計・ワイヤーフレームの規律（骨格・配置・画面遷移まで。装飾なし）
  - doc2: ビジュアル方針・実装連携の規律（装飾の文法とプラットフォーム作法への落とし方）
- スキル・doc ともに「概念はプロダクト側 / UI 実装作法はプラットフォーム / 引き出し型対話 / アクセシビリティは横串」の中核思想を体現する
- 構造検証の BATS pin が追加される（スキルファイルと doc ファイルの存在確認）

## What

### スキル（`skills/designing-ui/SKILL.md`）

- **起動条件**: 明示起動（`claude skill atdd-kit:designing-ui <issue>`）および `writing-plan-and-tests` への接続ポイントとして呼び出し可能。`defining-requirements` 承認後、単独起動も可。
- **対話スタイル**: 引き出し型（push ではなく pull）。作り手の頭から設計を引き出す問いを順に立てる。
- **フェーズ順序**: UI 要件確認 → 情報設計 → ワイヤーフレーム → ビジュアル方針 → 実装連携 の 5 フェーズを順に駆動する。
- **成果物定義**:
  - `docs/issues/<NNN>/ui-requirements.md` — UI 要件（機能要件との対応表）
  - `docs/issues/<NNN>/information-architecture.md` — 情報設計（画面単位・階層・遷移）
  - `docs/issues/<NNN>/wireframes.md` — ワイヤーフレーム記述（ASCII / Mermaid 等で骨格を記述）
  - `docs/issues/<NNN>/visual-policy.md` — ビジュアル方針（プラットフォーム + Design system 選択根拠）
  - `docs/issues/<NNN>/implementation-handoff.md` — 実装連携メモ（コンポーネント・トークン・アクセシビリティ注記）
- **中核思想の適用**:
  - 「何を出すか」（概念・コンテンツ）はプロダクト側（PRD）が決める。スキルはそれを問いで引き出す。
  - 「どう見せるか」（実装の作法）は対象プラットフォーム（HIG / Material Design / Baseline 等）の規約に従う。独自判断 [独自] はその旨を明示する。
  - アクセシビリティ（WAI-ARIA / WCAG 2.2 / JIS Z 8520）はフェーズ横断の哲学として扱い、ワイヤーフェーズから組み込む。
- **責任境界**:
  - このスキルは UI 設計の対話駆動と成果物生成を担う。コード実装・AT 実装・プラン作成は担わない。
  - `writing-design-doc` との住み分け: 技術アーキテクチャのトレードオフ記録は `writing-design-doc`。画面設計の工程駆動は `designing-ui`。

### 方法論 doc 2 本（`docs/methodology/`）

**doc1: `designing-ui-doc1.md` — UI 要件・情報設計・ワイヤーフレーム**

- UI 要件の定義規律: 機能要件との対応付け、画面単位の確定方法
- 情報設計の規律: 画面の単位は情報設計フェーズで確定する（ワイヤー前に固める）
- ワイヤーフレームの規律: 骨格・配置・遷移を記述。装飾（色・フォント・余白）はこのフェーズに含めない
- ゲシュタルト原則（近接・類同・連続・閉合）は doc2 以降の文脈として位置づける（doc1 ではワイヤー骨格に留める）

**doc2: `designing-ui-doc2.md` — ビジュアル方針・実装連携**

- 「装飾の文法」としての原則: ゲシュタルト原則 / Typography / Color / Spacing / Component 選択
- プラットフォーム別作法への落とし方: HIG（iOS / macOS）・Material Design（Android）・Baseline（Web）の選択意思決定
- Design system 再利用の規律: 既存 Design system がある場合のコンポーネント・トークン活用
- アクセシビリティ実装連携: WAI-ARIA ロール・WCAG 2.2 達成基準・JIS Z 8520 への対応注記の書き方
- 実装連携メモの書き方: エンジニアへの handoff として必要な情報の粒度

### BATS 構造検証

- `tests/` 配下の既存構造検証 BATS に、`skills/designing-ui/SKILL.md` の存在確認 pin を追加
- `docs/methodology/designing-ui-doc1.md` / `docs/methodology/designing-ui-doc2.md` の存在確認 pin を追加

### バージョン・変更記録

- `CHANGELOG.md` に本 Issue 変更を記録
- `plugin.json` の minor version bump（新スキル追加 = minor; DEVELOPMENT.md Versioning 準拠）

## Non-Goals

- **スキル本体で AT / Plan を生成しない**: `designing-ui` は UI 設計成果物のみを生成する。Acceptance Test の実装・Plan 文書は `writing-plan-and-tests` の担当であり、本 Issue のスコープ外。
- **doc 本文の内容を PRD で規定しない**: doc1 / doc2 の本文（各節の詳細記述）は実装ワーカーが `SKILL.md` と PRD の What 節を見て作成する。PRD は構成要件・規律のみを示す。
- **既存スキルの変更**: `writing-design-doc`・`defining-requirements`・`writing-plan-and-tests` 本体は変更しない。接続記述の追記のみ許容する（ただし AT で検証可能な範囲に限る）。
- **デザインツール連携（Figma / Pencil 等）**: 本 Issue では atdd-kit 内の方法論 doc とスキルのみを対象とする。外部デザインツールとの統合は別 Issue で扱う。
- **プラットフォーム固有の詳細設計規約の作成**: HIG / Material Design 等の要約・翻訳は行わない。参照規格への参照を示すにとどめる。

## Open Questions

1. **`docs/methodology/` ディレクトリの新設是非** — `docs/workflow/` と並列で `docs/methodology/` を新設するか、既存の `docs/workflow/` や `docs/` 直下に配置するか。
   → **Resolved（Gate ① 承認）**: `docs/methodology/` を新設する。UI/UX 設計方法論は workflow 記述とは独立した文書であり、同じ `docs/` 直下の別カテゴリとして扱うのが適切。

2. **単一 Issue で `designing-ui` スキル + doc 2 本を一括実施するか、Issue を分割するか** — スキルと doc を別 Issue にするとリリース順序の依存が生じる。
   → **Resolved（Gate ① 承認）**: 単一 Issue で一括実施する。スキルと doc は一体の成果物であり、分割するとスキルが doc なしで公開される中間状態が生まれる。

3. **成果物ファイル名の確定** — `ui-requirements.md` / `information-architecture.md` / `wireframes.md` / `visual-policy.md` / `implementation-handoff.md` の命名。
   → **Resolved（Gate ① 承認）**: 上記命名で確定。英語小文字ケバブ、意味が自明な名前を選択。
