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

### US-2: defining-requirements の Flow 順序変更（モード非依存 — 結果として通常フロー・autopilot の双方に適用）

> **C1 pin との整合（既存 pin を緩和しない）**: `tests/test_autopilot_skill.bats` の既存 pin
> 「dialog economy (#254): defining-requirements stays autopilot-free (AT-005/C1)」は
> `! grep -qi 'autopilot' skills/defining-requirements/SKILL.md` を固定している。
> 本 Issue で `skills/defining-requirements/SKILL.md` に追記する文言は **'autopilot' の語を一切含めず**、
> 「モード非依存（どの呼び出し元から実行されても同一）」というモード中立な表現で書く。
> Flow スキル自身が単一の正であるため、autopilot はオーケストレーター側（US-3）の規定経由で
> 同じ順序に従う — これで PRD の「両方に適用」要件と C1 pin が両立する。

- [ ] `bats tests/test_defining_requirements_skill.bats` を実行し、変更前のベースラインが green であることを記録する
- [ ] verify: 全テスト pass（変更前エビデンス）

- [ ] `skills/defining-requirements/SKILL.md` Flow の Step 8（Approval gate）/ Step 9（Write artifact）を次の順序に書き換える: Step 8 = **Write draft**（`cp templates/docs/issues/prd.md docs/issues/<NNN>/prd.md` → 6 セクションを記入）、Step 9 = **Commit / push / Draft PR**（作業ブランチへ Conventional Commits でコミット → push → Draft PR が無ければ `gh pr create --draft`）、Step 10 = **Approval gate（PR 上）**（ターミナルには PR リンク + 判断が必要な点のみを提示し、`Approve PRD? Reply 'ok' to approve, or name a section to revise.` を問う。修正はセクションへループバックし、再修正も commit/push して PR 差分を更新する。明示的な `ok` なしに先へ進まない）
- [ ] verify: SKILL.md の Flow 上で draft 書き込み行 → commit/push/Draft PR 行 → 承認ゲート行がこの順に出現する（`grep -n` で行番号比較）

- [ ] 同 SKILL.md の Output 節に「PRD ドラフトは承認**前**に commit/push され Draft PR の差分として提示される（モード非依存 — どの呼び出し元から実行されても同一の順序）」の旨を 1 行追記し、`No Issue comment` 規定はそのまま維持する（**'autopilot' の語は使わない** — 上記 C1 pin 整合のため）
- [ ] verify: `grep -q 'No Issue comment' skills/defining-requirements/SKILL.md` が引き続き成立し、`wc -l` が 200 行以下（#216 line budget pin）

- [ ] C1 pin の事前確認: `! grep -qi 'autopilot' skills/defining-requirements/SKILL.md` が変更後も成立することを直接実行して確認する（既存 pin の緩和・削除はしない）
- [ ] verify: grep の終了コードが 1（'autopilot' 不在）

### US-3: autopilot Dialog economy への提示チャネル規定追記

- [ ] `bats tests/test_autopilot_skill.bats` を実行し、変更前のベースラインが green であることを記録する
- [ ] verify: 全テスト pass（変更前エビデンス）

- [ ] `skills/autopilot/SKILL.md` の `## Dialog economy` 節末尾に提示チャネル規定の bullet を 1 つ追記する: Gate ①（要件承認）/ Gate ②（設計承認）とも成果物本体は作業ブランチへ commit/push 済みの **Draft PR 差分**として提示する。ターミナル・Issue/PR コメントに載せるのは **PR リンク + 判断が必要な点のみ**（成果物の全文展開をしない）。承認依頼・状態通知の全チャネル同期（ターミナル + GitHub に同一内容）は維持する
- [ ] verify: `grep -q 'Draft PR' skills/autopilot/SKILL.md`（Dialog economy 節内）が成立し、`wc -l skills/autopilot/SKILL.md` が 260 行以下（#254 line budget pin。超える場合は追記を圧縮し、budget 緩和はしない）

## Testing

<!-- CS-2: 変更した規定文言を BATS pin で構造検証する -->

- [ ] `tests/test_docs_restructure.bats` に AT-001 の pin を追加する: レガシー文言（`never written to ad-hoc repository paths`）の不在 + 新規定（Draft PR diff / state-change notifications only）の存在を `@test` 2 件で固定する
- [ ] verify: `bats tests/test_docs_restructure.bats` が green

- [ ] `tests/test_defining_requirements_skill.bats` に AT-002 / AT-004 の pin を追加する: (a) Flow 内で draft 書き込み → commit/push → Draft PR 作成 → 承認ゲートの順序（行番号比較で固定）、(b) 承認ゲートが PR リンク + 判断が必要な点のみを提示する規定の存在、(c) 新規定がモード非依存文言であること（追加 pin は 'autopilot' の語に依存しない検証式で書く — 既存 C1 pin と矛盾させない）
- [ ] verify: `bats tests/test_defining_requirements_skill.bats` が green（line budget pin 含む）、かつ `bats tests/test_autopilot_skill.bats` の既存 C1 pin（defining-requirements stays autopilot-free）も無変更のまま green

- [ ] `tests/test_autopilot_skill.bats` に AT-003 / AT-004 の pin を追加する: Dialog economy 節に Gate ①/② の Draft PR 差分ベース提示 + ターミナルは PR リンクと要点のみ、の規定が存在することを固定する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が green（260 行 budget pin 含む）

- [ ] `bats tests/` で全 BATS スイートを実行し、リグレッションがないことを確認する
- [ ] verify: 全スイート green

## Finishing

- [ ] CS-3 確認: `git diff main -- rules/atdd-kit.md` が空（新規定の追加なし）であることを確認する
- [ ] verify: diff 出力が 0 行

- [ ] `.claude-plugin/plugin.json` の version を 3.8.1 → 3.8.2 に bump する（fix PR = SemVer patch。DEVELOPMENT.md「Every feature PR merged to main must update the version and changelog」— 同一 PR 内で実施）
- [ ] verify: `grep -q '"version": "3.8.2"' .claude-plugin/plugin.json` が成立

- [ ] `CHANGELOG.md` の Unreleased（リリース時に 3.8.2 見出し）に本変更（Fixed: 成果物提示の Draft PR ベース統一、#267）を追記する
- [ ] verify: `grep -q '#267' CHANGELOG.md` が成立

- [ ] `tests/README.md` を同期する: 本 Issue で `@test` を追加した 3 ファイル（test_docs_restructure / test_defining_requirements_skill / test_autopilot_skill）の行に #267 pin の内容（Draft PR ベース提示の構造検証）を反映する（DEVELOPMENT.md「Directory READMEs」— 同一 PR 内。先例: #254 も tests/README.md を同期）
- [ ] verify: `grep -q '#267' tests/README.md` が成立

- [ ] `skills/README.md` を同期する: 変更した 2 スキル（defining-requirements / autopilot）の説明行を読み、Flow 順序変更・Dialog economy 追記と矛盾する記述があれば更新する（矛盾がなければ「確認済み・変更不要」と判断してよいが、確認自体は必須）
- [ ] verify: `skills/README.md` の defining-requirements / autopilot 行が変更後の SKILL.md と矛盾しない

- [ ] ドキュメント整合性チェック: `grep -rn 'gh issue comment.*deliverable\|Deliverables.*gh issue comment' docs/ skills/ commands/` で他に旧規定の残存がないことを確認する
- [ ] verify: 関連ドキュメントが変更内容と整合している（残存ヒット 0 件、または各ヒットが状態通知用途であることを確認済み）

## スコープ外メモ（非ブロッキング・提示のみ）

`docs/workflow/workflow-detail.md` Execution Mode 節の隣接行「**Review step** … spawns specialist reviewer subagents … **serially**」も #234（動的・並列 Workflow パネル）以降のレガシー記述だが、本 PRD のスコープ外のため本 Issue では触らない。マージ後にフォローアップ Issue の起票を推奨する。

## Design doc 判断

不要。トレードオフ（通常フローにも適用するか）は Gate ① 承認時に解決済み（PRD Open Questions 参照）であり、競合する代替案は残っていない。
