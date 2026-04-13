# Plan Review — Developer (Issue #41)

## 総合評価

PASS

## 指摘事項

### 1. Target Files: `docs/workflow-detail.md` の「条件付き Modify」が曖昧

Target Files テーブルの `docs/workflow-detail.md` は「Modify (conditional)」となっているが、QA test-strategy では `docs/workflow-detail.md` L62 に "Variable-Count Agents with user approval" 相当の記述が確認済みと記録されている。「条件付き」ではなく AC6 の必達対象として扱うべきで、Modify として確定させる方が実装者の手戻りリスクが低い。

**深刻度:** 低（実装時に grep で検出・対応可能だが、事前に確定させた方が明確）

### 2. Commit 4（tests BATS）と Commit 2（autopilot.md 変更）の順序

BATS テスト（`test_plan_agent_composition.bats`）はターゲットファイル変更後に追加するのが一般的だが、Commit 4 が Commit 2/3 より後なのは正しい。ただし BATS ファイル新規作成コミット（Commit 4）と BATS 実行（verify フェーズ）が明示的に分離されていないため、BATS が実装前に存在してもテスト実行は atdd の最後で行うという了解が必要。実装順序上の問題はない。

**深刻度:** なし（確認事項）

### 3. `skills/plan/evals/evals.json` の存在確認が未実施

Target Files に `skills/plan/evals/evals.json` が含まれているが、plan スキルに eval ファイルが実際に存在するかどうかの事前確認が plan draft に含まれていない。discover スキルには eval が存在するが、plan スキルの eval 有無は atdd フェーズで確認が必要。存在しない場合は新規作成になりファイル数が変わる。

**深刻度:** 低（atdd フェーズで対処可能）

## 修正提案

### 提案 1: `docs/workflow-detail.md` を「Modify (確定)」に変更

```markdown
| `docs/workflow-detail.md` | Variable-Count Agents 旧承認フロー記述の削除 | Modify |
```

理由: QA test-strategy が "Variable-Count Agents with user approval" の存在を確認済みであるため、AC6 の達成に必要な変更は確定している。"conditional" の留保を外すことで実装者が迷わない。

### 提案 2: Commit 4 の BATS コミットメッセージに実行タイミングを明示

Commit 4 のコミットメッセージを以下のように変更:

```
test: AC1-AC7 -- test_plan_agent_composition.bats 追加（実行は verify フェーズ）(#41)
```

理由: BATS ファイル追加コミットと BATS 実行（verify）を明示的に分離することで、CI 上で未実行のテストファイルが存在する期間が発生しないことを確認しやすくする。

## Agent Composition 評価

**Phase 3: Developer x 1**
- 具体性: 十分。変更対象 7 ファイルに対して Developer 1 名が ATDD 実装を担当。変更はすべて Markdown ファイルの追記・修正で単一コンポーネント。
- Bad/Good 判定: **Good** — 「Developer x 1」は人数確定かつ対象が明確。「N」や「複数」などの曖昧表現なし。

**Phase 4: Reviewer x 2**
- Reviewer 1（機能整合性）: 具体性あり。「AC1〜AC7 達成確認、旧承認手順の完全削除」は grep ベースの検証観点として明確。
- Reviewer 2（ドキュメント品質）: 具体性あり。「テンプレート明確性、Bad/Good 例、CHANGELOG 品質」は主観が入るが品質観点として妥当。
- **Bad/Good 判定: Good** — "Reviewer x N" ではなく "Reviewer x 2" として人数確定。各 Reviewer の観点も分離されており、両 Reviewer が同じことをレビューする重複がない。

**総合:** Agent Composition の記述は Readiness Check の「Good 例」基準を満たしている。plan 成果物の Agent Composition セクションのサンプルとして参照可能なレベル。

## 補足

- **QA test-strategy との整合:** QA が提案した BATS テスト（14 テスト、AC1–AC7 対応）と Developer の Commit 4（`test_plan_agent_composition.bats` 新規作成）は完全に整合している。テスト設計と実装戦略が同一ファイルを想定しており、分離が明確。
- **R5（既存 BATS 誤検知）の対応:** QA test-strategy で `test_autopilot_agent_teams_setup.bats` と `test_interaction_reduction.bats` が autopilot.md 変更の影響を受ける可能性が指摘されている。impl-strategy の Verification Plan に「全 BATS 実行」が含まれているため対応可能だが、atdd フェーズで当該ファイルの grep パターンを事前確認することを推奨する。
- **R6（既存 in-progress Issue への影響）:** QA test-strategy が指摘するとおり、autopilot.md の「手順定義」変更は既存セッションには影響しない（新規セッションからの動作変更）。この旨を CHANGELOG.md に注記として含めることを推奨する。
- **plan eval の存在確認:** `skills/plan/evals/` ディレクトリが存在しない場合、Commit 5（chore: バンプ）の前に eval 新規作成コミットが必要になる。atdd フェーズの最初に `ls skills/plan/evals/` で確認する。
