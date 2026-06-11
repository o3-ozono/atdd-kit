# Plan: autopilot 時の壁打ち・確認対話を「判断が必要な点のみ」に省力化する

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

前提（承認済みアンカー）: PRD の Open Questions で置き場所は `skills/autopilot/SKILL.md` に確定済み。flow skill 本体（`skills/defining-requirements/SKILL.md` 等）には一切手を入れない（C1 原則）。競合する代替案は残っていないため design doc は作成しない。

## Implementation

- [ ] `skills/autopilot/SKILL.md` の「## Human gates」セクションの直後に新セクション `## Dialog economy — all human-facing dialog under autopilot` を追加する（見出し + 導入 1 文。適用範囲 = Gate ① の壁打ち・design ゲート提示を含む autopilot 中の人間向け対話全般、と明記）
- [ ] verify: `grep -n '## Dialog economy' skills/autopilot/SKILL.md` がヒットし、同セクション内に `all human-facing dialog under autopilot` と requirements 壁打ち / design gate 双方への言及がある

- [ ] 同セクションに「聞くべき」基準を箇条書きで追加する: 人間にしか決められない点のみ — (a) 設計判断が分かれるトレードオフ・割り切り、(b) スコープの増減、(c) Outcome の合否基準
- [ ] verify: `grep -i 'ask ONLY' skills/autopilot/SKILL.md` がヒットし、`trade-off` / `scope` / `Outcome` の 3 語が同セクション内に存在する

- [ ] 同セクションに「聞かない」基準を箇条書きで追加する: Issue 本文・文脈から自明に導けるドラフト内容の逐次確認は禁止（`never ask section-by-section`）— ドラフトは全セクション一括提示（`batch-present` in one message）し、承認・差し戻しは固定ゲート（PRD 承認 / 設計承認 / merge）で各 1 回にまとめる
- [ ] verify: `grep -i 'batch-present' skills/autopilot/SKILL.md` と `grep -i 'never ask section-by-section' skills/autopilot/SKILL.md` がヒットする

- [ ] 同セクション末尾に C1 注記を 2 文で追加する: `defining-requirements` の "Each section step is one question at a time" は通常フロー（非 autopilot）の設計として維持され、under autopilot でのみ本指針がオーバーライドする。ゲートは AL-1 の 3 点固定のままで、削減対象はゲート間・ゲート内のマイクロ確認のみ
- [ ] verify: `grep -F 'one question at a time' skills/autopilot/SKILL.md` と `grep -i 'overrid' skills/autopilot/SKILL.md` がヒットし、既存の `exactly three` 文言が無変更で残っている

- [ ] 「## Human gates」の Gate ①（requirements approval）と Gate ②（design approval）の記述に Dialog economy セクションへの 1 行参照を追加する
- [ ] verify: `grep -c 'Dialog economy' skills/autopilot/SKILL.md` が 3 以上（セクション見出し + 各ゲートからの参照）

## Testing

- [ ] `tests/test_autopilot_skill.bats` に #254 ピンテストを追加する — その 1: `@test "dialog economy (#254): asks only human-only decisions (US-1)"` — `ask ONLY` / `trade-off` / `scope` / `Outcome` を grep で pin
- [ ] verify: `bats tests/test_autopilot_skill.bats -f 'US-1'` が green

- [ ] ピンテストその 2: `@test "dialog economy (#254): drafts are batch-presented, approved once per fixed gate (US-2)"` — `batch-present` / `never ask section-by-section` を grep で pin
- [ ] verify: `bats tests/test_autopilot_skill.bats -f 'US-2'` が green

- [ ] ピンテストその 3: `@test "dialog economy (#254): directive lives in the orchestrator and covers all gate dialogs (US-3/CS-2)"` — `## Dialog economy` 見出し、`all human-facing dialog under autopilot`、`one question at a time` + オーバーライド文言（C1）を grep で pin
- [ ] verify: `bats tests/test_autopilot_skill.bats -f 'US-3'` が green

- [ ] ピンテストその 4（不変条件）: `@test "dialog economy (#254): gates stay exactly three (CS-1)"` — `exactly three` が残存し、Dialog economy セクションがゲートの増減を導入していない（AL-1 不変宣言の存在）ことを pin
- [ ] verify: `bats tests/test_autopilot_skill.bats -f 'CS-1'` が green

- [ ] 行数バジェットテストを更新する: SKILL.md は現在 239 行で上限 240 のため新セクションで超過する。`line budget` テストの上限を 240 → 260 に引き上げ、テスト名とコメントに `#254: Dialog economy section` の根拠を記す
- [ ] verify: `bats tests/test_autopilot_skill.bats -f 'line budget'` が green、かつ `wc -l < skills/autopilot/SKILL.md` が 260 以下

- [ ] C1 不変の確認: flow skill 本体が無変更であることを差分で確認する
- [ ] verify: `git diff main -- skills/defining-requirements/ skills/extracting-user-stories/ skills/writing-plan-and-tests/ skills/running-atdd-cycle/ skills/reviewing-deliverables/ skills/merging-and-deploying/` の出力が空

- [ ] BATS 全スイートを実行する（既存 `test_autopilot_skill.bats` の全ピン + 他スキルのテストの回帰確認）
- [ ] verify: `bats tests/` がすべて green

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を 3.7.2 → 3.8.0 に上げる（既存スキル内への指針追加 = minor）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.8.0` を返す

- [ ] `CHANGELOG.md` に `### Added` エントリ（autopilot の Dialog economy 指針 — 質問を人間にしか決められない点に限定、ドラフト一括提示、#254）を追記する
- [ ] verify: `grep 254 CHANGELOG.md` がヒットし Keep a Changelog 形式に従っている

- [ ] ドキュメント整合性チェック — `docs/methodology/autopilot-iron-law.md`（AL-1 = 3 ゲート固定）と新セクションが矛盾しないこと、`skills/README.md` / `tests/README.md` の記述が変更後の現状と整合することを確認する
- [ ] verify: 関連ドキュメントが変更内容と整合している（AL-1 の 3 ゲート記述と Dialog economy の不変宣言が一致、README に齟齬なし）
