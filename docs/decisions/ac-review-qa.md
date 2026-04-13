# AC Review — QA (Issue #41)

## 総合評価

NEEDS REVISION

---

## 指摘事項

### AC1: plan 成果物に `### Agent Composition` セクションが含まれ、Phase 3/Phase 4 のエージェント人数・フォーカス観点が表形式で記載される

**テスト可能性:** 「表形式で記載される」は SKILL.md のテンプレートを grep または bats で検証可能。ただし「エージェント人数・フォーカス観点」という表の列定義が AC 本文に書かれておらず、テスト時の期待値が一意に定まらない。テンプレートの列名（例: Role / Count / Focus）を AC 本文または別の参照先で明記すべき。

**境界条件:** AC1 は task type を限定していないが、Agent Composition Table（autopilot.md）では research タスクで Researcher（variable-count）を使い、documentation タスクで Writer（fixed 1）を使う。これらのタスクタイプでも同じ `### Agent Composition` セクションを plan 成果物に含めるかが不明確。タスクタイプ別の出力差異を AC で明示する必要がある。

### AC2: `skills/plan/SKILL.md` の Step 4 と Step 6 に Agent Composition の導出ステップとテンプレートが明記されている

**テスト可能性:** ドキュメントの存在確認として客観的に検証可能。ただし「導出ステップ」と「テンプレートが明記されている」の判定基準が曖昧。「Step 4 に Agent Composition セクションが存在する」「Step 6 のテンプレートブロックに `### Agent Composition` ヘッダーが含まれる」のように、grep で確認できる具体的な記述に修正を推奨。

**現状との差分確認:** 現行 SKILL.md の Step 4 は Implementation Strategy、Step 6 は Post to Issue Comment に該当する。Step 4 に「どのように Agent Composition を導出するか」のステップを追加することを意図しているなら、Step 5 (Readiness Check) との順序関係も明記が必要。

### AC3: plan Step 5 の Readiness Check に「Phase 3/4 の Variable-Count Agents が具体化されている」項目が追加されている

**テスト可能性:** SKILL.md の Readiness Check テーブルに該当行が存在するか grep で確認可能。ただし「具体化されている」の判定基準が曖昧。既存 Readiness Check の記法（Bad/Good 例）に合わせて、Bad 例と Good 例を AC に含めるべき。

例:
- Bad: "Reviewer x N"（人数が未定）
- Good: "Reviewer x 2: (1) セキュリティ観点 (2) パフォーマンス観点"

### AC4: Issue が `ready-to-go` で autopilot が Phase 3/4 に進むとき、Variable-Count Agents の spawn で追加承認要求が発生しない

**テスト可能性（最大の懸念）:** 「追加承認要求が発生しない」は LLM の振る舞いに関するテストであり、bats/grep での静的検証が困難。AC4 を検証するには、autopilot.md の Variable-Count Agents セクションのテキストが「plan 承認済み構成から spawn」という記述に変更されていることを grep で確認する、静的検証 AC として再定義すべき。

動的振る舞い（実際に承認要求が出ないこと）を検証するには eval ケースが必要だが、現 AC にそのような言及がない。eval ケースの追加要否を明示すること。

**境界条件（重要）:** 以下の境界条件が AC4 でカバーされていない:
1. Phase 3 のみが対象か Phase 4 の Reviewer spawn も対象か（Issue 本文の User Story では「Phase 3/4」と記載されているが AC4 は「Phase 3/4」とのみ書いており、Phase 3（Researcher/Developer）と Phase 4（Reviewer）の両方で承認不要となるのか明確でない）
2. `ready-to-go` ラベルがない状態（`needs-plan-revision` → 修正後 → `ready-to-go`）でも同様に動作するか

### AC5: `commands/autopilot.md` の Variable-Count Agents セクションが plan-based に改訂され、Plan Review Round で Agent Composition もレビュー対象と明記されている

**テスト可能性:** 2 つの条件が混在している。「Variable-Count Agents セクションが plan-based に改訂」と「Plan Review Round で Agent Composition もレビュー対象と明記」は独立した検証可能な条件であり、AC を分割するか Given/When/Then 形式で 2 つの Then として明記すべき。

**エラーケース:** 現行の autopilot.md には Variable-Count Agents セクションで「ユーザーへの承認要求」手順が明記されている（4 ステップ）。この手順を削除・変更した場合、既存のドキュメントと整合が取れているかを Readiness Check で確認する AC が必要。

### AC6: Plan Review Round の Developer/QA への SendMessage レビュー観点に Agent Composition が含まれる

**テスト可能性:** autopilot.md の Plan Review Round セクションに「Agent Composition」というキーワードが含まれるかで grep 検証可能。AC として最もシンプルで明確。

---

## 追加/削除/修正提案

### 修正提案: AC1 にテンプレート列定義を追加

現行: 「Phase 3/Phase 4 のエージェント人数・フォーカス観点が表形式で記載される」

修正案:
- **Given:** plan スキルが development タスクで実行されたとき
- **When:** plan 成果物（Issue コメント）が投稿されると
- **Then:** `### Agent Composition` セクションに、Phase 3 と Phase 4 それぞれのエージェント（Role / Count / Focus）が表形式で記載されている

補足: research/documentation タスクの扱い（Variable-Count Agents の有無）を別 AC か注記で明示すること。

### 修正提案: AC4 を静的検証 AC に再定義

現行: 「Variable-Count Agents の spawn で追加承認要求が発生しない」（動的振る舞い）

修正案:
- **Given:** `commands/autopilot.md` の Variable-Count Agents セクションを確認するとき
- **When:** Phase 3/4 の spawn 手順を参照すると
- **Then:** 手順に「ユーザーへの承認要求（presents the proposed composition to the user for approval）」ステップが存在せず、「plan 承認済み Agent Composition から直接 spawn する」旨が明記されている

動的振る舞いをカバーする場合は別途 eval AC として追加する。

### 追加提案: AC7（タスクタイプ別 Agent Composition の扱い）

- **Given:** plan スキルが research または documentation タスクで実行されたとき
- **When:** plan 成果物（Issue コメント）が投稿されると
- **Then:** `### Agent Composition` セクションが含まれる（または明示的に「該当なし」と記載される）

理由: research/documentation タスクでも autopilot は Variable-Count Agents（Researcher/Writer）を使うため、plan 成果物でどう扱うかを明示する必要がある。現 AC セットに境界条件として欠落している。

### 追加提案: AC8（既存 Variable-Count Agents 承認フローとの後方互換性）

- **Given:** autopilot.md の変更後に `commands/autopilot.md` の Autonomy Rules セクションを確認するとき
- **When:** Variable-Count Agents に関する記述を参照すると
- **Then:** 既存の Autonomy Rule（Agent re-generation 禁止）との整合が取れており、矛盾する記述が存在しない

理由: 現行 autopilot.md の Autonomy Rule 5 は「Phase 3/4 でエージェントを新規生成しない」例外として Variable-Count Agents を扱っている。plan 承認に統合した場合、このルールとの整合確認が必要。

---

## 補足

### Readiness Check 項目（AC3）のフォーマット整合

現行 SKILL.md の Readiness Check テーブルは「Bad / Good」列を持つ。AC3 で追加を求めている新規項目も同様の形式（Check / Bad / Good）で記述されるべきことを実装者に明示すること。

### Phase 3/4 スコープの明確化

Issue 本文の User Story では「Phase 3/4 のエージェント構成を plan 承認時に一括確認」と記述されている。しかし Phase 3 と Phase 4 では Variable-Count Agents の性質が異なる:

- Phase 3: Researcher（research タスク）— テーマ数に依存
- Phase 4: Reviewer（development/bug/documentation/refactoring タスク）— レビュー観点数に依存

両 Phase を「同じ `### Agent Composition` テーブルの行として列挙する」のか「Phase ごとに分けた表を作る」のかが AC から読み取れない。実装前に明示すること。

### リグレッションリスク

| リスク | 対応状況 |
|--------|---------|
| plan スキルの既存テンプレート（Step 6）への追加で既存 plan 出力フォーマットが壊れる | AC に言及なし — 実装者が注意すること |
| autopilot.md の Variable-Count Agents 手順変更で既存 Phase 4 Reviewer spawn が壊れる | AC8（追加提案）でカバー推奨 |
| `docs/workflow-detail.md` の「Variable-Count Agents with user approval」言及との矛盾 | AC5 でカバーされているが、docs/ 変更範囲を明示すること |
