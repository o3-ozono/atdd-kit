# Test Strategy — QA (Issue #41)

## Outer Loop (Story Test)

- **Layer:** Static inspection（grep/文字列マッチ）+ Eval（plan スキル出力の構造確認）
- **Rationale:** 変更対象は `skills/plan/SKILL.md`（プロンプトテキスト）と `commands/autopilot.md`（ワークフロー定義）の Markdown ファイル。構造変更（セクション追加・手順削除）は grep で客観的に確認できる。「承認要求が発生しない」という動的振る舞いは eval（plan スキルを実行して出力に Agent Composition セクションが含まれるかを確認）で補完する。Story 全体のアウトカムは「plan コメントに Agent Composition が存在し、autopilot.md の 4 ステップ承認手順が消えている」という構造変化で代理検証する。

## Inner Loop (AC Tests)

| AC | Test Layer | Rationale |
|----|-----------|-----------|
| AC1: plan 成果物に `### Agent Composition` セクションが含まれる | Static/grep + Eval | `skills/plan/SKILL.md` Step 6 テンプレートブロックに `### Agent Composition` ヘッダと Role/Count/Focus 3 列テンプレートが存在することを grep で確認。eval id=0 に assertion A3/A4 を追加して LLM 出力も確認 |
| AC2: SKILL.md の Step 4 と Step 6 に Agent Composition が組み込まれている | Static/grep | Step 4 セクション内に "Agent Composition" 導出記述が存在し、Step 6 テンプレートに `### Agent Composition` ヘッダが存在することを section-scoped grep（awk）で確認。ファイル全体に存在するだけでなく正しいセクション内にある点を検証 |
| AC3: Readiness Check に Agent Composition チェックが追加されている | Static/grep | Step 5 Readiness Check テーブルに「Variable-Count Agents の人数・観点」に関する行と Bad 例（`Reviewer x N`）・Good 例（`Reviewer x 2: (1)...`）が存在することを grep で確認 |
| AC4: autopilot.md の Variable-Count Agents セクションが plan-based に改訂されている | Static/grep (negative + positive) | 旧 4 ステップ承認手順の削除を negative grep で確認（`presents the proposed composition to the user for approval` 等が存在しない）。plan 承認済み構成からの spawn 記述の追加を positive grep で確認 |
| AC5: autopilot.md の Plan Review Round に Agent Composition レビュー観点が追加されている | Static/grep | Plan Review Round セクション内（awk で範囲限定）に "Agent Composition" が存在することを確認。AC5 は「Developer only」限定条件のため、QA の指示ブロックに含まれないことも確認 |
| AC6: 既存ドキュメント（`docs/`）との整合が取れている | Static/grep (negative, repo-scoped) | `docs/workflow-detail.md` 等に旧フロー（spawn 時ユーザー承認）への言及が残存しないことを negative grep で確認。スコープは `docs/` 配下全体 |
| AC7: mid-phase resume で plan 未完了時に安全停止する | Static/grep | `commands/autopilot.md` の Phase 0.9 mid-phase resume セクションに「plan コメント不在時の STOP」手順の記述が存在することを section-scoped grep で確認 |

## Coverage Strategy

- **静的検証（grep）が主軸:** 変更対象がすべて Markdown テキストであり、特定の文字列・ヘッダー・テンプレート行の存在は grep で客観的に確認可能。section-scoped awk を使うことで「正しいセクション内に存在する」までを担保する。
- **eval で動的振る舞いを補完:** AC1 については plan スキル eval（`skills/plan/evals/evals.json` id=0）に assertion A3/A4 を追加し、LLM が実際に Agent Composition セクションを含む plan を出力するかを確認する。
- **新規 BATS ファイル:** `tests/test_plan_agent_composition.bats` を新規作成し、AC1–AC7 を 14 テストでカバーする。
- **eval 更新:** `skills/plan/evals/evals.json` eval id=0 に A3/A4 を追加。`expected_output` も「agent composition を含む plan 出力」に更新する。
- **AC4 は静的検証 AC として確定:** 「追加承認要求が発生しない」という動的振る舞いは LLM のランタイム動作に依存するため、autopilot.md の記述変更（旧手順削除 + 新記述追加）を grep で確認する静的 AC として再定義している。

## Regression Risks

- **既存 plan eval assertion (A1/A2) が FAIL するリスク:** `expected_output` の更新後に既存 assertion A1（State Gate チェック実行）・A2（plan 本体フローに進む）が誤 FAIL しないか。対策: auto-eval 実行で pass_rate を確認する。
- **`test_autopilot_agent_teams_setup.bats` が autopilot.md 構造変更で誤検知するリスク:** Variable-Count Agents セクションの記述変更が既存 BATS の grep パターンにヒットする可能性。対策: 実装後に `bats tests/test_autopilot_agent_teams_setup.bats` を個別実行して確認する。
- **`test_interaction_reduction.bats` が承認フロー削除に反応するリスク:** 承認ステップ削減に関するテストが存在する場合、旧手順削除で想定外の PASS/FAIL が出る可能性。対策: 実装前に当該テストの grep パターンを確認する。
- **既存 in-progress Issue への影響:** Variable-Count Agents の承認ステップを削除すると、現在 Phase 3/4 で承認待ち状態の Issue がある場合に手順が宙に浮く。対策: 本変更は autopilot.md の「手順定義」変更であり、既に spawn 済みのセッションには影響しない（新規セッションからの動作変更）。既存セッションへの影響はないことをドキュメントコメントで明示する。
- **`docs/workflow-detail.md` の整合確認漏れ:** `docs/workflow-detail.md` L62 に "Variable-Count Agents with user approval" という記述が存在することを確認済み。AC6 の negative grep テストで確実に検出できる。
