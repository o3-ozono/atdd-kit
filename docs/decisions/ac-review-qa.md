# AC Review — QA Perspective (Issue #36)

## Testability

各 AC の検証方法を示す。

| AC | 検証方法 | Evidence type |
|----|---------|---------------|
| AC1: 共通フローで DoD が導出される | SKILL.md の各フローセクション（Development / Bug / Docs/Research）に DoD 導出ステップが存在するかを grep / bats で確認 | bats / grep |
| AC2: コード変更タスクで三層構造が導出される | evals "dev-feature" / "bug-fix" プロンプトに DoD・User Story・Given/When/Then の三要素すべてが含まれることを eval assertion で確認 | eval |
| AC3: 非コードタスクで DoD のみ導出される | evals "documentation" 出力に "DoD" があり "User Story" / Given/When/Then が含まれないことを eval assertion（否定）で確認 | eval |
| AC4: Completion Criteria の廃止 | SKILL.md 全体を grep して "Completion Criteria" が存在しないことを bats negative テストで確認 | bats / grep |
| AC5: 成果物テンプレートに DoD セクションが存在する | SKILL.md 各フローのテンプレートブロックで "DoD" が先頭セクションとして現れることを bats で行番号順序チェック | bats / grep |

### 総評

AC1・AC4 は grep / bats で客観的に検証できる。AC2・AC3 は eval を拡張すれば検証可能。AC5 のみ「先頭に配置」という順序条件が含まれるため、grep だけでは不十分で行番号順序比較が必要になる点に注意。

---

## Boundary Coverage

以下の境界条件が現在の AC セットに明示されていない。

1. **Refactoring タスクが三層構造に含まれる根拠の明示**
   - AC2 の Given に "refactoring" が含まれるが、Refactoring フローは UX/Interruption チェックを "not applicable" とする特殊フローであり、三層構造（DoD → User Story → AC）が成立するか否かの説明が不足している。AC2 の Given に注記を追加するか分離した AC が必要。

2. **タスクタイプが不明瞭なとき**
   - ユーザーがタスクタイプを選択できなかった場合、DoD のみを生成するのか三層構造を生成するのかが AC に記載されていない。フォールバック動作の仕様が必要。

3. **DoD が空になるケース**
   - アプローチ探索後に DoD 項目がゼロ件になった場合の扱いが AC にない（後述「エラーケース」参照）。

---

## Error Cases

以下のエラーシナリオが AC セットに含まれていない。

1. **DoD 導出結果がゼロ件の場合**
   - Given: アプローチ探索後、DoD 項目が抽出できない
   - Expected: ユーザーへのフィードバックを返し、最低 1 件の DoD が確定するまで次ステップへ進まない
   - 現行 AC に完全に欠落している。

2. **Docs フローで誤って User Story が出力されるケース**
   - AC3 は否定条件で記述されているが、実際のモデル出力で User Story が漏れ込んだ場合の検出方法が evals.json に実装されているかは今後の実装次第。
   - 現行 evals.json の C2 アサーション（"Given/When/Then 形式ではなくチェックリスト形式"）が "DoD チェックリスト" 形式に変更されたあとも有効かを確認する必要がある。

3. **User Story が存在するが AC が空のケース**
   - Bug フローなどで root cause は特定できたが AC が導出されなかった場合の扱いが未定義。

---

## Coverage Gaps

既存動作のうち今回の変更で regression するリスクがあるが AC でカバーされていないもの。

1. **evals.json の Docs eval (C1/C2) が DoD 用語変更に未対応**
   - 現行 C2 アサーション: "Given/When/Then ではなくチェックリスト形式" — 今回の変更後も "DoD" セクションが存在することを検証する assertion がない。AC4 でカバーしているが evals への反映が明示されていない。

2. **Bug フローの DoD 導出ステップ**
   - AC1 の Given が "任意のタスクタイプ" とある一方、現行 SKILL.md の Bug フローには DoD 導出ステップが存在しない。Bug フローにも DoD ステップを追加する必要があるかが実装前に不明確。

3. **Mandatory Checklist の更新漏れ**
   - SKILL.md 末尾の Mandatory Checklist に "DoD 導出ステップが実行されたか" に相当する項目が現在存在しない。変更後も checklist が旧来のままだとレビュー・テスト時にチェック漏れが生じる。

4. **既存 BATS テストへの影響確認**
   - `test_discover_approach_parity.bats` / `test_discover_autopilot_approval.bats` はいずれも SKILL.md の構造を grep しているため、Step 番号や見出し文言が変わると false negative が発生するリスクがある。

---

## Regression Risk

以下の既存動作が壊れていないことを確認しなければならない。

| リスク項目 | 確認方法 |
|-----------|---------|
| AUTOPILOT-GUARD が正しく機能する（直接呼び出しをブロック） | evals "autopilot-guard-direct-invocation-block" (D1/D2) を継続実行 |
| autopilot モードで Step 7 承認ゲートがスキップされる | `test_discover_autopilot_approval.bats` を継続実行 |
| アプローチ比較の equal-detail ルールが保持される | `test_discover_approach_parity.bats` を継続実行 |
| Development フローの UX / Interruption チェック（U1-U5 / I1-I4）が維持される | evals "dev-feature" (A5, A6) を継続実行 |
| Docs フローが Given/When/Then を使わない（チェックリスト形式）ことが維持される | evals "documentation" (C2) を継続実行（DoD 用語変更に合わせて assertion 更新も必要） |
| Bug フローで Regression test AC が含まれる | evals "bug-fix" (B2) を継続実行 |

---

## Missing ACs

以下の追加 AC を推奨する。

### 推奨 AC6: DoD が空の場合の処理
- **Given:** discover の DoD 導出ステップが完了したとき
- **When:** 導出された DoD 項目が 0 件のとき
- **Then:** ユーザーにフィードバックを返し、最低 1 件の DoD が確定するまで次ステップへ進まない

### 推奨 AC7: Refactoring フロー固有の DoD 必須項目
- **Given:** discover が refactoring タスクで実行されたとき
- **When:** 成果物が提示されると
- **Then:** DoD に "外部から観測可能な動作が変わらない" ことを示す項目が必ず含まれる

### 推奨 AC8: evals.json の Docs eval 更新（テスト設計 AC）
- **Given:** SKILL.md 変更後
- **When:** evals.json の documentation eval (C1/C2) を実行すると
- **Then:** "DoD" セクションが存在すること、かつ "Completion Criteria" という表記が使われないことが assertion で確認できる

*注: AC8 は実装ではなくテスト設計の AC だが、今回の変更で evals.json が陳腐化するリスクが高いため明示する。*

---

## Verdict

APPROVE WITH CHANGES

AC1〜AC5 は目的と検証方法が明確で基本的な品質は十分。ただし DoD ゼロ件エラーケース（推奨 AC6）・Refactoring フロー固有条件（推奨 AC7）・evals 更新の担保（推奨 AC8）が欠落しており、これらを補完または計画スコープに明示した上で実装に進むことを推奨する。
