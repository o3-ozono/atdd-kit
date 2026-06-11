# Plan: autopilot 埋め込み Workflow script の args fail-closed 化（#252 先行対処後の残差分）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

対象 Issue: #256 / ブランチ: `fix/256-autopilot-args-fail-closed`
変更対象は `skills/autopilot/SKILL.md` と `tests/test_autopilot_skill.bats` のみ（CS-2: `lib/autopilot_convergence.sh` と Workflow ツール側は変更しない）。

## Implementation

- [ ] `skills/autopilot/SKILL.md` 埋め込み Workflow script の `const PHASE = A.phase === 'impl' ? 'impl' : 'design'` を fail-closed ガードに置換する: `if (A.phase !== 'design' && A.phase !== 'impl') throw new Error(...)` の直後に `const PHASE = A.phase` を置く（throw メッセージは「args.phase missing or invalid — refusing to default to design」の趣旨で、impl→design 化けを防ぐ理由が読み取れる文言にする）
- [ ] verify: `grep -E "A\.phase !== 'design' && A\.phase !== 'impl'" skills/autopilot/SKILL.md` がヒットし、`grep -E "\? 'impl' : 'design'" skills/autopilot/SKILL.md` がヒットしない

- [ ] 同ガード直上のコメント（`// Two-phase split (#249): ...`）に、フォールバック廃止の理由（#256: 文字列 args で phase が欠落すると impl が design に化け、設計承認ゲートが壊れる）を 1-2 行で追記する
- [ ] verify: `grep -n '#256' skills/autopilot/SKILL.md` でガード付近のコメント行がヒットする

- [ ] SKILL.md の Flow 節 step 2（design phase）と step 4（impl phase）の invoke 指示に「args は JSON オブジェクトとして渡す（文字列化した JSON を渡さない）」という注記を追加する
- [ ] verify: `grep -c '文字列化した JSON を渡さない' skills/autopilot/SKILL.md` が 2 を返す（design / impl 両方の invoke 指示に注記がある）

- [ ] ガードが FREEZE（`pin_anchor`）およびイテレーションループより前（args parse 直後の定数定義部）に位置することを目視確認する（CS-1: 不正 args では 1 イテレーションも走らない）
- [ ] verify: SKILL.md 内で phase ガードの行番号が `freeze:anchor` の行番号より小さい

## Testing

- [ ] `tests/test_autopilot_skill.bats` の `#252 prompt-defect regression guards` セクション直後に phase ガードの pin テストを 1 本追加する: (a) `A.phase !== 'design' && A.phase !== 'impl'` の throw が存在する、(b) フォールバックパターン `? 'impl' : 'design'` が存在しない、(c) Flow 節の「文字列化した JSON を渡さない」注記が存在する — を grep で pin する（既存の `args (#252, refs #256)` テストと同形式）
- [ ] verify: 追加したテストが `bats tests/test_autopilot_skill.bats -f "phase"` で green になる

- [ ] BATS スイート全体を実行し、既存 pin（#252 parse / issue ガード、AL-2 pin 系）に回帰がないことを確認する
- [ ] verify: `bats tests/test_autopilot_skill.bats` が全件 pass する

- [ ] 変更ファイルが `skills/autopilot/SKILL.md` / `tests/test_autopilot_skill.bats`（+ version/CHANGELOG）に限定されていることを確認する（CS-2）
- [ ] verify: `git diff --name-only main` に `lib/autopilot_convergence.sh` が含まれない

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を 3.7.2 → 3.7.3 に bump する（バグ修正 = patch）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が `3.7.3` を返す

- [ ] `CHANGELOG.md` に Fixed エントリ（phase フォールバック廃止・fail-closed 化、refs #256）を追加する
- [ ] verify: `grep -n '#256' CHANGELOG.md` がヒットし、Keep a Changelog 形式に沿っている

- [ ] ドキュメント整合性チェック: SKILL.md の Flow 節・Mechanism 節の記述が新しいガード挙動（phase 必須）と矛盾していないか通読する
- [ ] verify: 関連ドキュメントが変更内容と整合している（`design` 既定値を前提とする記述が残っていない）
