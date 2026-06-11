# Plan: 成果物提示を Draft PR ベースに統一 — workflow-detail.md のレガシー記述矛盾と defining-requirements の承認後書き込み順序の修正

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

前提: 対象は 3 ファイルの規定文言の修正 + BATS pin。コードロジックの変更はない。
変更前後で各スキルの BATS を実行する（DEVELOPMENT.md「Skill Changes Require Test Evidence」）。

## Implementation

### US-1: workflow-detail.md のレガシー記述の置換

- [ ] `bats tests/test_docs_restructure.bats` を実行し、変更前のベースラインが green であることを記録する
- [ ] verify: 全テスト pass（変更前エビデンス）

- [ ] `docs/workflow/workflow-detail.md` Execution Mode 節（L47）のレガシー行「**Deliverables** flow through Issue / PR comments via `gh issue comment` / `gh pr comment` — never written to ad-hoc repository paths.」を、Workflow 表と整合する規定に置換する: 「**Deliverables** are committed to the Issue's work branch and presented as the Draft PR diff (the commit moment is the Draft PR moment). Issue / PR comments carry **state-change notifications and approval requests only** — never the deliverable body. Knowledge worth long-term reference is graduated into `docs/` or `DEVELOPMENT.md` by explicit human decision.」（後段の knowledge graduation 文は保持）
- [ ] verify: `grep -c 'never written to ad-hoc repository paths' docs/workflow/workflow-detail.md` が 0、`grep -q 'Draft PR diff' docs/workflow/workflow-detail.md` が成立

### US-2: defining-requirements の Flow 順序変更（通常フロー・autopilot 共通）

- [ ] `bats tests/test_defining_requirements_skill.bats` を実行し、変更前のベースラインが green であることを記録する
- [ ] verify: 全テスト pass（変更前エビデンス）

- [ ] `skills/defining-requirements/SKILL.md` Flow の Step 8（Approval gate）/ Step 9（Write artifact）を次の順序に書き換える: Step 8 = **Write draft**（`cp templates/docs/issues/prd.md docs/issues/<NNN>/prd.md` → 6 セクションを記入）、Step 9 = **Commit / push / Draft PR**（作業ブランチへ Conventional Commits でコミット → push → Draft PR が無ければ `gh pr create --draft`）、Step 10 = **Approval gate（PR 上）**（ターミナルには PR リンク + 判断が必要な点のみを提示し、`Approve PRD? Reply 'ok' to approve, or name a section to revise.` を問う。修正はセクションへループバックし、再修正も commit/push して PR 差分を更新する。明示的な `ok` なしに先へ進まない）
- [ ] verify: SKILL.md の Flow 上で draft 書き込み行 → commit/push/Draft PR 行 → 承認ゲート行がこの順に出現する（`grep -n` で行番号比較）

- [ ] 同 SKILL.md の Output 節に「PRD ドラフトは承認**前**に commit/push され Draft PR の差分として提示される（通常フロー・autopilot 共通）」の旨を 1 行追記し、`No Issue comment` 規定はそのまま維持する
- [ ] verify: `grep -q 'No Issue comment' skills/defining-requirements/SKILL.md` が引き続き成立し、`wc -l` が 200 行以下（#216 line budget pin）

### US-3: autopilot Dialog economy への提示チャネル規定追記

- [ ] `bats tests/test_autopilot_skill.bats` を実行し、変更前のベースラインが green であることを記録する
- [ ] verify: 全テスト pass（変更前エビデンス）

- [ ] `skills/autopilot/SKILL.md` の `## Dialog economy` 節末尾に提示チャネル規定の bullet を 1 つ追記する: Gate ①（要件承認）/ Gate ②（設計承認）とも成果物本体は作業ブランチへ commit/push 済みの **Draft PR 差分**として提示する。ターミナル・Issue/PR コメントに載せるのは **PR リンク + 判断が必要な点のみ**（成果物の全文展開をしない）。承認依頼・状態通知の全チャネル同期（ターミナル + GitHub に同一内容）は維持する
- [ ] verify: `grep -q 'Draft PR' skills/autopilot/SKILL.md`（Dialog economy 節内）が成立し、`wc -l skills/autopilot/SKILL.md` が 260 行以下（#254 line budget pin。超える場合は追記を圧縮し、budget 緩和はしない）

## Testing

<!-- CS-2: 変更した規定文言を BATS pin で構造検証する -->

- [ ] `tests/test_docs_restructure.bats` に AT-001 の pin を追加する: レガシー文言（`never written to ad-hoc repository paths`）の不在 + 新規定（Draft PR diff / state-change notifications only）の存在を `@test` 2 件で固定する
- [ ] verify: `bats tests/test_docs_restructure.bats` が green

- [ ] `tests/test_defining_requirements_skill.bats` に AT-002 / AT-004 の pin を追加する: (a) Flow 内で draft 書き込み → commit/push → Draft PR 作成 → 承認ゲートの順序（行番号比較で固定）、(b) 承認ゲートが PR リンク + 判断が必要な点のみを提示する規定の存在
- [ ] verify: `bats tests/test_defining_requirements_skill.bats` が green（line budget pin 含む）

- [ ] `tests/test_autopilot_skill.bats` に AT-003 / AT-004 の pin を追加する: Dialog economy 節に Gate ①/② の Draft PR 差分ベース提示 + ターミナルは PR リンクと要点のみ、の規定が存在することを固定する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が green（260 行 budget pin 含む）

- [ ] `bats tests/` で全 BATS スイートを実行し、回 regress がないことを確認する
- [ ] verify: 全スイート green

## Finishing

- [ ] CS-3 確認: `git diff main -- rules/atdd-kit.md` が空（新規定の追加なし）であることを確認する
- [ ] verify: diff 出力が 0 行

- [ ] `CHANGELOG.md` の Unreleased に本変更（Fixed: 成果物提示の Draft PR ベース統一、#267）を追記する
- [ ] verify: `grep -q '#267' CHANGELOG.md` が成立

- [ ] ドキュメント整合性チェック: `grep -rn 'gh issue comment.*deliverable\|Deliverables.*gh issue comment' docs/ skills/ commands/` で他に旧規定の残存がないことを確認する
- [ ] verify: 関連ドキュメントが変更内容と整合している（残存ヒット 0 件、または各ヒットが状態通知用途であることを確認済み）

## Design doc 判断

不要。トレードオフ（通常フローにも適用するか）は Gate ① 承認時に解決済み（PRD Open Questions 参照）であり、競合する代替案は残っていない。
