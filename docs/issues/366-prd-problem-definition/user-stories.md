# User Stories: defining-requirements / prd テンプレを 4 要素構造へ再編し問題定義品質規律を導入

## Functional Story

### US-1: PRD テンプレの 4 要素構造への再編

**I want to** `templates/docs/issues/prd.md` を 4 要素構造（基礎項目 / 問題定義と背景 / ゴールと成功指標 / 機能要件）で記述でき、各要素に品質規律・ガイダンス・anti-pattern が併記されている,
**so that** 問題定義の品質を担保する構造的規律（事実と課題の分離・1 PRD=1 課題・観察可能なゴール・下流からの還流）がテンプレ本体に存在し、ゼロから毎回導出せずに品質の高い PRD を書き始められる.

### US-2: 品質規律に沿った defining-requirements の対話

**I want to** `defining-requirements` スキルが「事実と課題の分離」「1 PRD=1 課題」「観察可能なゴール」「下流からの還流」の 4 原則に対応する問いかけを Step 毎に行う（既存の 1 質問ずつ・AskUserQuestion ルールは維持）,
**so that** テンプレの品質規律と一致した対話で PRD を作成でき、根拠の薄い課題主張・スコープ発散・内部完了条件のゴールを対話段階で防げる.

### US-3: 旧 6 節 ↔ 新 4 要素の対応表

**I want to** 旧 6 節（Problem / Why now / Outcome / What / Non-Goals / Open Questions）と新 4 要素の対応表がテンプレ内コメントまたは参照ドキュメントに存在する,
**so that** 既存の `docs/issues/*/prd.md`（旧形式）を一括マイグレーションせずとも対応表で読解でき、新旧 PRD が共存できる.

## Constraint Story (Non-Functional)

### CS-1: テンプレ構造を検証する BATS テストの CI 実行

**I want to** 新テンプレの構造（4 要素の見出し存在・事実/課題欄の分離・anti-pattern 警告の存在など）を検証する BATS acceptance test が `tests/acceptance/` に追加され CI で実行される,
**so that** テンプレ構造の劣化や品質規律の欠落がマージ前に自動検知され、PRD ドリフトの再発を防げる.

### CS-2: 既存 PRD 資産との後方互換

**I want to** 旧 6 節形式で書かれた既存 `docs/issues/*/prd.md` 資産がテンプレ再編後もそのまま有効なまま温存され、対応表を介して新構造として読める,
**so that** テンプレ変更が既存 Issue の成果物を壊さず、一括書き換えのコストを負わずに移行できる.
