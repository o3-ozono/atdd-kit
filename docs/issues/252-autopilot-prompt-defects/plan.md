# Plan: autopilot 収束ループのプロンプト欠陥3点修正（#252）

<!-- skill-fix inline plan mode（PRD/US 省略、Issue #252 本文の欠陥詳細・修正案・受け入れ条件を直接アンカーとする）。
     2-5 分粒度のタスク行と verify: 行を交互に配置する（superpowers writing-plans 形式）。
     修正対象は skills/autopilot/SKILL.md の埋め込み Workflow script（プロンプト）のみ。
     lib/autopilot_convergence.sh は非ゴール（#248 のスコープ）であり一切変更しない。 -->

## Implementation

### skills/autopilot/SKILL.md — 欠陥1: 監査プロンプトの placeholder fingerprint（P0）

- [ ] `audit:${step}` プロンプト（現 L185 付近）から逐語実行を誘発する `Run EXACTLY: \`fp="$(printf '%s' "<the blocking findings text, verbatim>" | fingerprint)"\`` を削除する
- [ ] verify: SKILL.md に文字列 `<the blocking findings text, verbatim>` が存在しない（`grep -c` = 0）

- [ ] 同プロンプトに、JS 側で構築した blocking findings の JSON（`JSON.stringify(blocking)`）を `BEGIN-PAYLOAD` / `END-PAYLOAD` マーカー付きで直接埋め込む（テンプレートリテラル変数展開）
- [ ] verify: `audit:` プロンプト内に `BEGIN-PAYLOAD` と `END-PAYLOAD` と `JSON.stringify(blocking)`（または同等の埋め込み変数）が存在する

- [ ] ハッシュ手順を「quoted heredoc（`<<'EOF'`）でペイロードを一時ファイルへ書き出し → `fingerprint < <一時ファイル>` → `record_iteration`」へ書き換える（シェル展開・改行差異による fingerprint 揺れを防ぐ）
- [ ] verify: `audit:` プロンプトが quoted heredoc による一時ファイル経由のハッシュ手順を指示しており、プレースホルダを直接 `printf` する指示が残っていない

### skills/autopilot/SKILL.md — 欠陥2: review プロンプトの phase+step スコープ（P0）

- [ ] phase × step に応じたスコープ節を返すヘルパー（例: `const reviewScope = (phase, step) => ...`）を Workflow script に追加する。内容: design phase 共通 =「計画成果物のみをレビューし、プロダクションコード不在・実行可能 AT 不在を findings にしない」、`extracting-user-stories` ステップ =「prd.md ↔ user-stories.md の整合のみ」、`writing-plan-and-tests` ステップ =「user-stories.md / plan.md / acceptance-tests.md の計画成果物一式」
- [ ] verify: SKILL.md に design phase 用スコープ文言（プロダクションコード/実行可能 AT の不在を findings 化しない旨）と step 別スコープ文言が存在する

- [ ] `review:${step}` プロンプト（現 L163 付近）にスコープ節を連結し、`reviewing-deliverables` へ phase と step を明示して渡す
- [ ] verify: `review:` プロンプトのテンプレートリテラルがスコープ節（ヘルパー呼び出しまたは展開変数）を含む

### skills/autopilot/SKILL.md — 欠陥3: gen プロンプトへの findings 伝達（P1）

- [ ] ループ内に前イテレーションの verdict を保持する変数（例: `let prevFindings = null`）を導入し、各イテレーション末尾で `verdict.findings` を保存する
- [ ] verify: Workflow script に前イテレーション findings を保持・更新するコードが存在する

- [ ] `gen:${step}` プロンプト（現 L161 付近）を分岐させる: iteration 1（`prevFindings` なし）は従来文言を維持（resume キャッシュ互換）、iteration 2 以降は findings 本文の JSON を埋め込み「これらを逐語的に修正せよ」と指示する
- [ ] verify: `gen:` プロンプトが iteration 1 で従来文言、2 以降で findings JSON 埋め込みとなる条件分岐を持ち、「If a prior review left findings, fix them verbatim.」単独の（本文なし）指示が 2 以降の経路に残っていない

### skills/autopilot/SKILL.md — ハードニング: args の防御パース（補足）

- [ ] Workflow script 冒頭に `args` の防御パース（`typeof args === 'string' ? JSON.parse(args) : args`）と `Number.isInteger(NNN)` の fail-closed 検証（不正なら即 return / throw）を追加する
- [ ] verify: SKILL.md に防御パースと `Number.isInteger` 検証が存在し、不正時に処理を継続しない

- [ ] 変更全体で行数 budget を確認し、超過時はコメントの簡潔化で調整する（プロンプト品質は削らない）
- [ ] verify: `wc -l skills/autopilot/SKILL.md` ≤ 240

## Testing

- [ ] tests/test_autopilot_skill.bats に追加: (a) プレースホルダ文字列 `<the blocking findings text, verbatim>` が SKILL.md に存在しない（AC1 / AC5）、(b) `BEGIN-PAYLOAD` / `END-PAYLOAD` と findings 埋め込みが audit プロンプトに存在する（AC1）
- [ ] verify: `bats tests/test_autopilot_skill.bats` で新規アサーション 2 件が green

- [ ] tests/test_autopilot_skill.bats に追加: (c) review プロンプトの design phase スコープ文言（プロダクションコード/実行可能 AT 不在を findings 化しない）と step 別スコープが存在する（AC2 / AC3）、(d) gen プロンプトに前回 findings の埋め込み分岐が存在する（AC4）
- [ ] verify: `bats tests/test_autopilot_skill.bats` で新規アサーション 2 件が green

- [ ] tests/test_autopilot_convergence.bats（または新規 BATS）に追加: プレースホルダの sha256 定数 `2aed7ea6d4c79d81da29da31fe975d762c64b1e15c211769880c3c6a92ccce2a` をテスト内で `printf '%s' "<the blocking findings text, verbatim>" | fingerprint` から再計算して一致を確認した上で、その入力文字列（placeholder）が SKILL.md に現れないことを assert する — placeholder fingerprint がログに記録され得る指示経路の不在を pin する（AC5）
- [ ] verify: `bats tests/test_autopilot_convergence.bats`（新規ファイルがあればそれも）green

- [ ] 既存 suite の回帰確認
- [ ] verify: `bats tests/test_autopilot_skill.bats tests/test_autopilot_convergence.bats tests/test_rules_workflow.bats` がすべて green

## Finishing

- [ ] CHANGELOG.md の [Unreleased] に Fixed として欠陥3点（placeholder fingerprint / review スコープ / findings 伝達）+ args 防御パースを追記する
- [ ] verify: CHANGELOG.md [Unreleased] に #252 への言及がある

- [ ] ドキュメント整合性チェック（docs/methodology/autopilot-iron-law.md・README の autopilot 記述が変更と矛盾しないか確認。プロンプト内部の修正のため通常は変更不要）
- [ ] verify: 関連ドキュメントが変更内容と整合している（grep で旧プロンプト文言への参照が docs/ に残っていない）

## 品質ゲート記録（skill-fix variant）

- MUST-1/2/3: AT は 6 件（3 件以上）、各 AT は Given/When/Then で独立検証可能、全 AT が Issue #252 の受け入れ条件チェックリストに対応（トレーサビリティは acceptance-tests.md の AC 対応表を参照）
- UX U1-U5: 本 Issue の成果物は SKILL.md プロンプト（エージェント向けテキスト）であり GUI を持たない。U1（可視性）のみ該当 — halt 理由と監査ログが人間に届くことは既存 AL-4/AL-5 で担保され本修正で強化される。U2-U5 は対象外（N/A）
- Interruption I1-I4: 対話 UI を持たないため N/A。中断相当の関心事（途中 halt 後の再実行）は既存の pin 再検証 + JSONL 追記設計でカバー済み
