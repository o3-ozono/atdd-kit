# Plan: check_sameness / check_stuck の step スコープ化と gate 状態 fingerprint — 偽 sameness halt の解消

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

対象: Issue #272 / 承認スコープは案 a+b（PRD Open Questions Resolved, Gate ① 2026-06-11）。
変更ファイル: `lib/autopilot_convergence.sh`, `skills/autopilot/SKILL.md`, `tests/test_autopilot_convergence.bats`, `tests/test_autopilot_skill.bats`, `CHANGELOG.md`, `.claude-plugin/plugin.json`。

## Implementation

### a. `lib/autopilot_convergence.sh` — step スコープ化（US-1, US-2, US-5）

- [ ] `_fingerprints` に第 2 引数 `step` を追加する: `_fingerprints <jsonl> [step]`。`step` 非空のとき `grep -F "\"step\":\"<step>\""` で該当 step の行に絞り込んでから fingerprint 列を抽出する（`record_iteration` は step を `_json_escape` 済みで書くため、マッチ側も同じエスケープ表現で固定文字列マッチさせる。step 省略時は現行どおりログ全体）
- [ ] verify: 2 step 混在のフィクスチャ JSONL に対し `_fingerprints log impl` が impl 行の fingerprint のみを返し、`_fingerprints log` が全行を返す（手元のシェルで確認）

- [ ] `check_sameness` のシグネチャを `check_sameness <jsonl> [step]` に拡張し、`$2` をそのまま `_fingerprints "$jsonl" "$step"` へ透過する（判定ロジック自体は不変）
- [ ] verify: `bash -c 'source lib/autopilot_convergence.sh; check_sameness <fixture> impl'` が、design 最終行と impl 1 行目が同一 fingerprint（空 findings `4f53cda1…`）でも 0（continue）を返す

- [ ] `check_stuck` のシグネチャを `check_stuck <jsonl> <window> [step]` に拡張し、`$3` を `_fingerprints` へ透過する（window バリデーションは現行のまま維持）
- [ ] verify: 同フィクスチャで `check_stuck <fixture> 3 impl` が impl 系列のみを母集団にし、別 step 行起因では非ゼロにならない

- [ ] ファイル先頭のコメントブロック（Functions: 一覧）の `check_sameness` / `check_stuck` のシグネチャ説明を `[step]` 付きに更新する
- [ ] verify: `grep -n 'check_sameness <jsonl> \[step\]' lib/autopilot_convergence.sh` がヒットする

### b. `skills/autopilot/SKILL.md` — step 引き渡しと oracle 状態込み fingerprint（US-3, US-4）

- [ ] canonical Workflow script の coverage gate ブロックで `uncovered` をループスコープの変数に持ち上げる（`let uncovered = []` を `let coverageOk` の隣に置き、`cov.uncovered || []` を代入）— audit ステップから参照可能にするための前処理
- [ ] verify: script 内で `uncovered` が audit テンプレート文字列より前に宣言・代入されている（目視 + `grep -n 'uncovered' skills/autopilot/SKILL.md`）

- [ ] audit ステップ（`label: audit:${step}`）の fingerprint payload を `${JSON.stringify(blocking)}` から `${JSON.stringify({ atGreen, coverageOk, uncovered, blocking })}` へ拡張し、直前コメント（#252 注記の周辺）に「payload は oracle 状態込み — findings 0 件でも gate 状態の変化が別 fingerprint になる（#272）」の説明を追記する
- [ ] verify: `grep -n 'JSON.stringify({ atGreen, coverageOk, uncovered, blocking })' skills/autopilot/SKILL.md` がヒットし、`JSON.stringify(blocking)` 単独の payload 行が残っていない

- [ ] rails ステップ（`label: rails:${step}`）の指示文を `check_sameness "<log>" "${step}"` / `check_stuck "<log>" 3 "${step}"` に変更し、現在の step を毎イテレーション渡す
- [ ] verify: `grep -n 'check_sameness' skills/autopilot/SKILL.md` の rails 行に step 引数が含まれ、step なし呼び出しが script 内に残っていない

- [ ] 監査 JSONL のスキーマ（`iteration/step/verdict/fingerprint` の 4 フィールド）に変更がないことを確認する（payload 拡張は fingerprint の素材側のみ — PRD Non-Goals）
- [ ] verify: `record_iteration` の printf フォーマット行が無変更（`git diff lib/autopilot_convergence.sh` に該当行が現れない）

## Testing

### c. `tests/test_autopilot_convergence.bats` — #269 再現の回帰テスト（US-7）

- [ ] ヘルパー: 2 step 混在ログ（design 最終行 + impl 行、同一 fingerprint）を `record_iteration` で組み立てるフィクスチャ手順を追加する
- [ ] verify: フィクスチャを使う最初の @test が green（`bats tests/test_autopilot_convergence.bats` 部分実行で確認）

- [ ] AT-001 実装: クロス step 同一 fingerprint で `check_sameness <log> impl` が 0（continue）を返すテストを追加する（#269 再現ケース）
- [ ] verify: 該当 @test が green

- [ ] AT-002 実装: 同一 step 内の連続同一 fingerprint で `check_sameness <log> impl` が非ゼロ（halt）を返すテストを追加する（検出力の後退なし、US-6）
- [ ] verify: 該当 @test が green

- [ ] AT-003 実装: step 引数省略時に現行挙動（ログ全体を単一系列、クロス step でも一致すれば halt）が維持されるテストを追加する（後方互換、US-5）
- [ ] verify: 該当 @test が green、かつ既存の `check_sameness` / `check_stuck` 系テストが無修正のまま green

- [ ] AT-004 実装: `check_stuck <log> 3 impl` が別 step 行を window の母集団から除外するテストと、同一 step 内の真の停滞（A,A,A および A,B,A）では従来どおり halt するテストを追加する
- [ ] verify: 該当 @test 群が green

### d. `tests/test_autopilot_skill.bats` — 構造 pin 更新（US-7）

- [ ] rails 呼び出しの構造 pin を更新する: script が `check_sameness` / `check_stuck` に step 引数を渡していることを grep で pin する
- [ ] verify: 該当 @test が green

- [ ] audit payload の構造 pin を更新する: `JSON.stringify({ atGreen, coverageOk, uncovered, blocking })` の存在と、旧 `JSON.stringify(blocking)` 単独 payload の不在を pin する（既存 pin `JSON\.stringify\(blocking\)` の正規表現を新形式へ修正）
- [ ] verify: 該当 @test が green

- [ ] 両スイートをフル実行する: `bats tests/test_autopilot_convergence.bats tests/test_autopilot_skill.bats`
- [ ] verify: 全テスト green（exit code 0）— DEVELOPMENT.md「Skill Changes Require Test Evidence」準拠の証跡

## Finishing

- [ ] `CHANGELOG.md` に Fixed エントリを追加する（#272: step スコープ化 + oracle 状態込み fingerprint で偽 sameness halt を解消）
- [ ] verify: CHANGELOG が Keep a Changelog 形式で本変更を記載している

- [ ] `.claude-plugin/plugin.json` を patch bump する（3.11.2 → 3.11.3、bug fix のため）
- [ ] verify: `grep '"version"' .claude-plugin/plugin.json` が 3.11.3 を示し、CHANGELOG のバージョン表記と整合する

- [ ] ドキュメント整合性チェック: `docs/*.md` / `rules/*.md` に rails の旧シグネチャ・旧 payload 記述が残っていないことを確認する（事前調査では issues 配下以外にヒットなし）
- [ ] verify: `grep -rn -e 'check_sameness' -e 'check_stuck' docs/*.md rules/*.md` に矛盾する記述がない
