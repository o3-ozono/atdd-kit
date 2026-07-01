# PRD: defining-requirements / prd テンプレを 4 要素構造へ再編し問題定義品質規律を導入

## Problem

**事実**: 現行 `templates/docs/issues/prd.md` は 6 節構成（Problem / Why now / Outcome / What / Non-Goals / Open Questions）であり、各節にはコメント形式のガイダンス 1 行のみが付く。`defining-requirements` スキルは Problem 節を「Describe the concrete pain. Separate the current state and the consequence.」と 1 行で案内するにとどまり、問題定義の品質を担保する構造的規律（事実と課題の分離・1 PRD=1 課題・観察可能なゴール・下流からの還流）がテンプレ本体に存在しない。

**課題**: 品質規律が明示されていないため、実運用で以下が繰り返し発生する。

- 「現状どうなっているか（事実）」と「それによって何が困るか（課題）」が混在し、Problem 節が根拠の薄い課題主張になる。
- 1 つの PRD に複数の本質課題が詰め込まれ、スコープが発散する。
- Outcome が「実装完了」「ファイルを書き換える」など内部完了条件で書かれ、利用者視点の変化が記述されない。
- 下流（設計・AT・実装）で判明した制約が PRD へ還流されず、PRD と実装が乖離したまま進む。

## Why now

#367（機能優先度の方法論 doc 新設）と接続してプロダクト発見フェーズのドキュメント体系を整備する流れにあり、今 PRD テンプレの再設計を行うことで #367 の優先度節との整合が最初から取れる。autopilot / full-autopilot の稼働増により `defining-requirements` の呼び出し頻度が上がっており、品質規律の欠如が PRD ドリフトとして累積しやすい状況にある。改版コストは今が最小（既存 `docs/issues/*/prd.md` 資産は旧形式のまま温存でき、対応表があれば共存可能）。

## Outcome

以下の状態が観察可能な達成指標として満たされている。

- `templates/docs/issues/prd.md` が 4 要素構造（基礎項目 / 問題定義と背景 / ゴールと成功指標 / 機能要件）に再編されており、各要素に品質規律・ガイダンス・anti-pattern が記述されている。
- `defining-requirements` スキルが「事実と課題の分離」「1 PRD=1 課題」「観察可能なゴール」「下流からの還流」を対話で担保し、テンプレの品質規律と一致した問いかけを行う。
- 旧 6 節 ↔ 新 4 要素の対応表がテンプレ内または参照ドキュメントに存在し、既存 `docs/issues/*/prd.md` が対応表で読める。
- 新テンプレ構造を検証する BATS テストが CI で実行される。

## What

### 1. テンプレ再編（`templates/docs/issues/prd.md`）

6 節を以下の 4 要素構造へ置換する。各要素に品質規律ガイダンス（コメント形式）と anti-pattern 例を記述する。

| 新 4 要素 | 旧 6 節の対応節 | 追加・変更点 |
|-----------|----------------|-------------|
| **1. 基礎項目**（プロダクト名 / ターゲット / 制約） | （新設） | 新規。スコープ境界と前提制約を先頭に固定する |
| **2. 問題定義と背景**（事実と課題の分離） | Problem + Why now | 事実欄と課題欄を明示的に分離。Why now は「今やる背景」欄として統合 |
| **3. ゴールと成功指標** | Outcome | 観察可能・外部視点の記述規律（Marty Cagan *Inspired* Ch.7 参照）を明示 |
| **4. 機能要件**（優先度付き） | What + Non-Goals | Non-Goals を「スコープ外」欄として機能要件節に統合。優先度列（#367 方法論）のプレースホルダーを追加 |
| （存続）Open Questions | Open Questions | Resolved / Unresolved を明示するガイダンスを追加。未解決のみ列挙 [独自] |

*[独自]: Open Questions 節の Resolved 状態管理は Marty Cagan の文献範囲外であり、atdd-kit 運用慣行として独自に追加する。*

### 2. 品質規律と anti-pattern 集

テンプレ内コメントおよびスキルの問いかけに以下を組み込む（一次情報: Marty Cagan *Inspired* を基礎とし、[独自] を明示して整理）。

**品質規律（4 原則）**:
- **事実と課題の分離**: 問題定義では「現状どうなっているか（観察された事実）」と「それが何を引き起こすか（課題・影響）」を別欄に記述する（Inspired 参照）。
- **1 PRD = 1 本質課題**: 複数の本質課題があるなら PRD を分ける [独自]。
- **観察可能なゴール**: ゴールは利用者側で観察できる変化として記述する。内部完了条件（「〜を実装する」「〜ファイルを書く」）は不可（Inspired 参照）。
- **下流からの還流**: 設計・AT・実装で判明した制約を PRD へ戻す双方向接続を明示する [独自]。

**anti-pattern 集**:
- 事実と課題の混在（例: 「〇〇が不便だ」→ 事実か課題か不明）
- 複数課題の同居（例: 「A の問題と B の問題を解消する」を 1 PRD に詰める）
- 内部完了条件のゴール（例: 「テンプレートを書き換える」）
- 観察不可能な成功指標（例: 「品質が上がる」）

### 3. スキル更新（`skills/defining-requirements/SKILL.md`）

4 要素構造に沿った対話フローへ更新する。品質規律の 4 原則に対応する問いかけを Step 毎に組み込む（既存の 1 質問ずつ・AskUserQuestion ルールは維持）。

### 4. BATS テスト追加

新テンプレの構造（4 要素の見出し存在、事実/課題欄の分離、anti-pattern 警告の存在など）を検証する acceptance test を `tests/acceptance/` に追加する。

### 5. CHANGELOG.md 更新 + version bump

DEVELOPMENT.md Versioning 準拠で minor version を上げる。

## Non-Goals

- **既存 PRD 資産（`docs/issues/*/prd.md`）の一括マイグレーション**: 旧 6 節形式のファイルを新構造へ書き換えることは本 Issue のスコープ外。対応表で新旧が共存できれば十分。
- **優先度付け方法論の詳細定義（MoSCoW / RICE 等）**: 定義は #367 に委ねる。本 Issue は「優先度列のプレースホルダー追加」にとどまる。
- **`extracting-user-stories` / `writing-plan-and-tests` 等の downstream スキル更新**: PRD 出力形式変更に伴う影響調整は後続 Issue とする。
- **対話 UI フレームワーク（AskUserQuestion）の再設計**: ボタンラベル・選択肢の文言調整は含むが、UI フレームワーク自体の再設計は対象外。

## Open Questions

1. **対応表の置き場**: テンプレ内コメントに置くか、`docs/workflow/` 配下の別リファレンス doc に置くか。
   → **Resolved（Gate ① 承認）**: テンプレ内コメントを推奨。ただし実装フェーズで両案を評価し適切な方を選ぶ。
2. **案A（品質規律のみ追加）vs 案B（4 要素構造への再編）**: どちらを採用するか。
   → **Resolved（Gate ① 承認）**: 案B を採用。4 要素構造への再編とする。
3. **Open Questions 節の存廃**: 4 要素構造に Open Questions は含まれないが、Resolved 状態管理のために残すか廃止するか。
   → **Resolved（Gate ① 承認）**: 節は存続させ、Resolved / Unresolved ガイダンスを追加する。
