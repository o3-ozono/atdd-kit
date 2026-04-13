# Issue #36 — Draft AC Set (from discover)

## Task Type
development

## Approach (approved)
**A (revised): DoD を全フロー共通ステップとして抽出**

- 共通フロー: 要件理解 → アプローチ探索 → DoD 導出
- コード変更タスクのみ追加: User Story 導出 → AC 導出 → UX/Interruption チェック

## User Story
**As a** atdd-kit を使う開発者（PO / Developer / QA エージェント含む），
**I want to** discover スキルが全タスクタイプで DoD を共通成果物として導出し、コード変更タスクでは User Story + AC を追加レイヤーとして導出するようにしたい，
**so that** タスクの完了条件が常に明示され、タスクタイプによって成果物の形式がバラバラにならない。

## DoD (Definition of Done)

1. discover SKILL.md の全フローで DoD が共通成果物として導出される
2. Documentation / Research フローの Completion Criteria が DoD に置き換えられている
3. コード変更タスク（dev / bug / refactoring）は DoD → User Story → AC の順で導出する構造になっている
4. 成果物テンプレート（Issue コメント形式）に DoD セクションが含まれている

## Acceptance Criteria

### AC1: 共通フローで DoD が導出される
- **Given:** discover が任意のタスクタイプで実行されたとき
- **When:** アプローチ探索の後にステップが進むと
- **Then:** DoD 導出ステップが実行され、タスク固有の完了条件がリスト化される

### AC2: コード変更タスクで三層構造が導出される
- **Given:** discover が development / bug / refactoring タスクで実行されたとき
- **When:** 成果物が提示されると
- **Then:** DoD、User Story、AC（Given/When/Then）の三層すべてが含まれている

### AC3: 非コードタスクで DoD のみ導出される
- **Given:** discover が research / documentation タスクで実行されたとき
- **When:** 成果物が提示されると
- **Then:** DoD のみが含まれ、User Story と AC は含まれない

### AC4: Completion Criteria の廃止
- **Given:** discover SKILL.md の Documentation / Research フローにおいて
- **When:** 成果物定義を確認すると
- **Then:** "Completion Criteria" の用語が存在せず、すべて "DoD" に統一されている

### AC5: 成果物テンプレートに DoD セクションが存在する
- **Given:** discover の成果物テンプレート（Issue コメント形式）において
- **When:** 全タスクタイプのテンプレートを確認すると
- **Then:** DoD セクションが先頭に配置され、コード変更タスクでは User Story + AC が続く構造になっている

## UX Check Results
- U1: 該当 — 既存ステップ進行表示パターンで対応可能。追加 AC 不要
- U2: 非該当 — スキル定義変更のため undo 対象外
- U3: 該当 — AC4 でカバー済み（用語統一）
- U4: 非該当 — スキル定義ファイルの変更
- U5: 非該当 — 順次進行で効率に影響なし

## Interruption Scenario Check Results
- I1-I4: 全て非該当 — SKILL.md の変更であり UI 状態保持対象外
