# Plan: autopilot 設計ゲート差し戻しの未規定挙動 — コメントを再実行へ運ぶ配管の不在と部分承認の扱い

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

対象 Issue: #261 / ブランチ: `fix/261-autopilot-gate-rejection`
変更対象は `skills/autopilot/SKILL.md` と `tests/test_autopilot_skill.bats` のみ（+ version/CHANGELOG）。`lib/autopilot_convergence.sh`・`reviewing-deliverables`・Workflow ツール（harness）側は変更しない（PRD Non-Goals）。

## 決定事項（PRD Open Question の解決）

- **`rejectionFindings` の priority 既定値 = 0（blocker 扱い）。** 人間の差し戻しコメント由来の finding は、人間が深刻度を明示しない限り blocker として扱う（fail-safe 原則、AL-4/AL-5 と同系）。実装は既存の `priorityOf` 正規化（absent / non-numeric → 0）をシード時に適用して実現し、新たな正規化ロジックは導入しない。
- **シード先 = design phase 再実行の全ステップの iteration 1。** 非 'ok' 応答は成果物セット全体の差し戻し（US-2）なので、`rejectionFindings` は `extracting-user-stories` / `writing-plan-and-tests` 両ステップの iteration 1 の generate プロンプトに verbatim で届ける。既存の `prevFindings` 埋め込み分岐（`JSON.stringify`）をそのまま流用する。
- **design doc は作成しない。** priority 既定値は既存 fail-safe 原則の適用、シード機構は既存 `prevFindings` 配管の流用であり、競合する代替案間の非自明なトレードオフが存在しないため。

## Implementation

- [ ] `skills/autopilot/SKILL.md` 埋め込み Workflow script の args parse 部（phase ガード直後）に `rejectionFindings` の fail-closed バリデーションを追加する: `A.rejectionFindings` が存在する場合、(a) 配列でなければ throw、(b) 各要素が非空文字列の `evidence_ref` を持たなければ throw（AL-4: evidence 無しの finding を作らせない）、(c) `PHASE !== 'design'` なら throw（差し戻し配管は design phase 再実行専用 — impl に渡るのは契約違反）。検証済みの値を `const REJECTION_FINDINGS`（無ければ `null`）に束縛する
- [ ] verify: `grep -n 'rejectionFindings' skills/autopilot/SKILL.md` で args parse 部のバリデーション（配列チェック・evidence_ref 必須・design 限定の 3 ガード）がヒットする

- [ ] バリデーション直上に理由コメントを 1-2 行追記する（#261: 再実行は新規 Workflow 呼び出しで `prevFindings` が `null` 初期化されるため、人間の差し戻しコメントを args で運ばないと generate に届かず握り潰される）
- [ ] verify: `grep -n '#261' skills/autopilot/SKILL.md` でバリデーション付近のコメント行がヒットする

- [ ] step ループ内の `let prevFindings = null` を、`REJECTION_FINDINGS` ありなら `priorityOf` 正規化（absent / non-numeric priority → 0 = blocker）を適用した値でシードする形に変更する（例: `let prevFindings = REJECTION_FINDINGS ? REJECTION_FINDINGS.map((f) => ({ ...f, priority: priorityOf(f) })) : null` — design phase 限定はバリデーション (c) が既に保証）。これで各ステップの iteration 1 の generate プロンプトの既存 `JSON.stringify(prevFindings)` 分岐に人間コメントが verbatim で埋め込まれる
- [ ] verify: SKILL.md 内で `prevFindings` の初期化行が `REJECTION_FINDINGS` を参照し `priorityOf` 正規化を適用している（`grep -nE 'prevFindings = REJECTION_FINDINGS' skills/autopilot/SKILL.md` がヒット）

- [ ] Flow 節 step 3（design-approval gate）に差し戻し時の手順を明文化する: (1) 非 'ok' 応答（「A は ok / B は要修正」等の部分承認を含む）は**成果物セット全体の差し戻し**として扱う — **部分承認は承認ではない**、impl phase へ進まない; (2) コメントを**セクション単位で分割**して N 件の finding にする（1 セクションの指摘 = 1 finding、複数指摘を 1 finding に潰さない）; (3) 各 finding は `priority`（人間が深刻度を明示しない限り 0）+ `evidence_ref` = 該当部分の人間コメント verbatim; (4) `args = { issue: NNN, phase: 'design', rejectionFindings: [...] }` で Workflow を再呼び出しする（JSON オブジェクトとして渡す、#256）
- [ ] verify: `grep -E '部分承認は承認ではない|全体の差し戻し' skills/autopilot/SKILL.md` と `grep -E 'セクション単位' skills/autopilot/SKILL.md` がヒットし、step 3 に `rejectionFindings` を含む再呼び出し args が明記されている

- [ ] Human gates 節の gate ②（Middle — design approval）の散文を新配管と整合させる: 差し戻しコメントは `rejectionFindings` として design phase 再実行に渡る旨を追記し、既存の「Rejection comments re-enter the design loop as findings (`evidence_ref` = the human comment)」「MAX_ITERATIONS restarts … sameness history is kept」の記述（BATS pin 対象の文言）は壊さない
- [ ] verify: `bats tests/test_autopilot_skill.bats -f "rejection"` が pass し（既存 pin 無傷）、gate ② に `rejectionFindings` への言及がある

- [ ] バリデーション・シードの位置を目視確認する: バリデーションは args parse 直後（= FREEZE `freeze:anchor` より前）にあり、不正 args では 1 イテレーションも走らない。シードは step ループ内の iteration 開始前にある
- [ ] verify: SKILL.md 内で `rejectionFindings` バリデーションの行番号が `freeze:anchor` の行番号より小さい

## Testing

- [ ] `tests/test_autopilot_skill.bats` に `#261 design-gate rejection plumbing pins` セクションを追加し、配管の pin を 1 本目として追加する: (a) args parse 部に `rejectionFindings` バリデーション（配列・evidence_ref 必須・design 限定）が存在する、(b) `prevFindings` 初期化が `REJECTION_FINDINGS` を参照する — を grep で pin する（#252/#256 の pin と同形式）
- [ ] verify: `bats tests/test_autopilot_skill.bats -f "261"` で追加テストが green になる

- [ ] 規律明文化の pin を 2 本目として追加する: SKILL.md に (a) 「部分承認は承認ではない」（全体差し戻し）、(b) セクション単位の finding 分割、(c) `evidence_ref` = 人間コメント、(d) step 3 の再呼び出し args に `rejectionFindings` — が存在することを grep で pin する
- [ ] verify: `bats tests/test_autopilot_skill.bats -f "261"` で 2 本とも green になる

- [ ] BATS スイート全体を実行し、既存 pin（#252 parse / issue ガード、#256 phase ガード、AL-2 pin 系、design-gate rejection 文言）に回帰がないことを確認する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が全件 pass する

- [ ] 変更ファイルが `skills/autopilot/SKILL.md` / `tests/test_autopilot_skill.bats` / `.claude-plugin/plugin.json` / `CHANGELOG.md` / `docs/issues/261-*` に限定されていることを確認する（Non-Goals: `lib/autopilot_convergence.sh`・reviewing-deliverables・harness 側は不変更）
- [ ] verify: `git diff --name-only main` に上記以外のファイル、特に `lib/autopilot_convergence.sh` と `skills/reviewing-deliverables/` 配下が含まれない

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を 3.8.1 → 3.9.0 に bump する（Workflow args への新フィールド `rejectionFindings` 追加 = 既存スキル内の新規能力 = minor）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.9.0` を返す

- [ ] `CHANGELOG.md` に Added エントリ（design ゲート差し戻しコメントの `rejectionFindings` 配管 + 全体差し戻し・finding 分割規律の明文化、refs #261）を追加する
- [ ] verify: `grep -n '#261' CHANGELOG.md` がヒットし、Keep a Changelog 形式に沿っている

- [ ] ドキュメント整合性チェック: SKILL.md の Human gates 節・Flow 節・Mechanism 節、および `docs/methodology/autopilot-iron-law.md` の記述が新配管（差し戻しコメント → `rejectionFindings` → iteration 1 generate）と矛盾していないか通読する
- [ ] verify: 関連ドキュメントが変更内容と整合している（「コメントが findings として再投入される」と約束しながら配管が無い、という乖離記述が残っていない）
