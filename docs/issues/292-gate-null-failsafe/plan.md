# Plan: autopilot Workflow の `agent()` null フェイルセーフ化（#292）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

設計方針: `skills/autopilot/SKILL.md` の Workflow スクリプトで戻り値を参照する 5 箇所すべてを null フェイルセーフ化する。fail-open は決して作らない（不変条件）。行バジェット 280 行・現状 277 行のため、新規ヘルパー宣言を増やさず in-line ガードで吸収する。各変更は対応する BATS 構造アサーション（AT-001…AT-006）とペアにし、変更前後で `bats tests/test_autopilot_skill.bats` を green に保つ（DEVELOPMENT.md「Skill Changes Require Test Evidence」）。

### 行バジェット dry-run（現状 277 / 上限 280 = 残り 3 行・第 3 回引き上げ不可）

実装前に下表のガードごと行デルタを積算し、合計が +3 を超えないことを確認してから着手する（着手後に超過を発見して禁止された 3 回目の引き上げに追い込まれる事態を防ぐ）。各 in-line 書き換えは「既存行の置換 = 0 行増」、新規 return 文の追加のみ「+1 行」。

| ガード | 変更種別 | 行デルタ |
|--------|----------|----------|
| at-gate（atGreen, SKILL.md 210 行目） | 既存行の in-place 書き換え | 0 |
| coverage（uncovered/coverageOk, 217-218 行目） | 既存 2 行の in-place 書き換え（`uncovered` は 214 行目で宣言済み・再宣言不要） | 0 |
| review（verdict/blocking/converged, 220・223 行目） | 既存行の in-place 書き換え（`verdict?.` / 明示 null チェック） | 0 |
| freeze（frozen, 181 行目の直前） | **新規** 独立 null ガード return を 1 行追加（既存 181 行目は不変） | **+1** |
| audit（rec, 235 行目） | 既存 `rec.recordOk !== true` return に `rec == null \|\|` を合流（in-place） | 0 |
| rails（r, 244 行目の前） | **新規** null ガード return を 1 行追加 | **+1** |
| fail-open 不変条件コメント | 既存コメント行へ追記できれば 0、独立行なら +1 | **0〜+1** |
| **合計** | | **+2〜+3（≤ 残り 3 行に収まる）** |

合計が +3 を超える見込みになった場合は、fail-open コメントを既存コメント行（例: SKILL.md 221-222 行の oracle 説明、または 240 行の rails 説明）へ追記して吸収し、独立行を作らない（+1 を 0 に落とす）。

## Implementation

- [ ] ベースラインとして `bats tests/test_autopilot_skill.bats` を実行し、現状 green を記録する
- [ ] verify: 既存スイートが全 pass する（変更前の基準）

- [ ] `at-gate` の `atGreen` 算出（SKILL.md 約 210 行目）を `atGreen = at != null && at.exitCode === 0 && at.green === true` に書き換える（null=gate 未通過、ループ継続）
- [ ] verify: SKILL.md に `at != null && at.exitCode === 0 && at.green === true` が存在し、null ガード無しの `at.exitCode === 0 && at.green === true` 単独行が残っていない

- [ ] `coverage` ゲート（約 217-218 行目）を `uncovered = cov?.uncovered || []` と `coverageOk = cov != null && cov.allCovered === true && uncovered.length === 0` に書き換える（null=gate 未通過、`uncovered=[]`、ループ継続）
- [ ] verify: SKILL.md に `cov?.uncovered || []` と `cov != null && cov.allCovered === true` が存在し、`cov.allCovered === true`（オプショナルチェーン無しの素参照）が残っていない

- [ ] `review`（`verdict`、約 220・223 行目）を null フェイルセーフ化する。`verdict` が null のとき「未収束」（`overall_correctness` 不一致）かつ findings 無しとなるよう、`blocking` / `converged` / `prevFindings` の参照を `verdict?.` か明示 null チェックに統一する（null=未収束扱いでループ継続、PASS にしない）
- [ ] verify: SKILL.md で `verdict.overall_correctness === 'correct'` が fail-safe 形（`verdict != null && verdict.overall_correctness === 'correct'` または等価のオプショナルチェーン）になり、null の `verdict` が `converged === true` に到達しない

- [ ] `freeze`（`frozen`）の null ガードを追加する。既存の `if (frozen.pinned !== true) return { ... reason: 'anchor-pin-failed' }`（SKILL.md 181 行目）は **書き換えず**、その直前に独立した null ガードを 1 行差し込む: `if (frozen == null) return { status: 'COMPLETED_WITH_DEBT', step: 'freeze', reason: 'freeze-error' }`（null=フェイルクローズ、reason: `freeze-error`）。これにより既存の「`frozen` は valid object だが pin コマンド exit != 0」経路は `anchor-pin-failed` のまま保たれ、null 経路（AC4/AT-004）のみ `freeze-error` を返す（既存挙動の回帰を作らない）。`recorded = frozen.logLines`（SKILL.md 185 行目）参照は両ガードより後段にあり、null は到達しない
- [ ] verify: SKILL.md に `frozen == null` を含む独立ガード（reason: `freeze-error`）と、書き換えていない `frozen.pinned !== true`（reason: `anchor-pin-failed`）の両方が存在し、`frozen == null` ガードが `frozen.pinned` ガードより前にあり、`frozen.logLines` 参照が両ガードより後にある

- [ ] `audit`（`rec`、約 235 行目）の既存 `rec.recordOk !== true` 経路に null を合流させる。`if (rec == null || rec.recordOk !== true) return { status: 'COMPLETED_WITH_DEBT', step, reason: 'record-error', verdict }`（null=フェイルクローズ、reason: `record-error`）
- [ ] verify: SKILL.md の audit 返却ガードが `rec == null || rec.recordOk !== true` を含む

- [ ] `rails`（`r`、約 244 行目）の null ガードを追加する。`halt` 算出の前に `if (r == null) return { status: 'COMPLETED_WITH_DEBT', step, reason: 'rails-error', verdict }`（null=フェイルクローズ、halt 相当、reason: `rails-error`）。null のとき `r.acDriftExit` 等を参照させない
- [ ] verify: SKILL.md に `r == null` を含むガードがあり、`reason: 'rails-error'` が存在し、`r.acDriftExit !== 0` 参照が null ガードより後にある

- [ ] fail-open 不変条件のコメントを SKILL.md に一行で明記する（例: `// null フェイルセーフ: null は決して収束/PASS とみなさない（fail-open 禁止）。継続経路は check_max_iterations が上限担保`）。行数増を最小化するため既存コメント行への追記で吸収できれば優先する
- [ ] verify: SKILL.md に fail-open を禁止する旨（「never fail-open」または同義の表現）のコメントがあり、`wc -l skills/autopilot/SKILL.md` が 280 以下。実測の行デルタを「行バジェット dry-run」表の +2〜+3 見積りと突き合わせ、超過していたら fail-open コメントを既存行へ吸収して 280 以下に収める

## Testing

- [ ] `tests/test_autopilot_skill.bats` に `# --- #292: agent() null フェイルセーフ ----` セクションを追加し、AT-001（at-gate）の grep 構造アサーションを書く
- [ ] verify: 新規 test が pass し、`at != null && at.exitCode === 0 && at.green === true` を pin している

- [ ] AT-002（coverage）・AT-003（review）・AT-004（freeze）・AT-005（audit）・AT-006（rails / fail-open 不変条件）の grep 構造アサーションを追加する（acceptance-tests.md の Given/When/Then に対応）
- [ ] verify: AT-002…AT-006 が全 pass し、それぞれの null ガード文字列・reason 文字列・fail-open 禁止コメントを pin している

- [ ] 変更後に `bats tests/test_autopilot_skill.bats` を実行する
- [ ] verify: 既存 + 新規（AT-001…AT-006）が全 green（DEVELOPMENT.md「Skill Changes Require Test Evidence」: skill 編集で既存構造ピンを壊さない）

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を patch bump し、`CHANGELOG.md` に `### Fixed` エントリ（autopilot gate/Workflow の null フェイルセーフ化, #292）を追加する
- [ ] verify: `bats tests/` 全 green（version=最新 CHANGELOG 見出し一致の regression AT 含む, #289）。`scripts/check-plugin-version.sh` が通る

- [ ] ドキュメント整合性チェック（`skills/README.md` は skill 追加/削除/リネーム無しのため変更不要。SKILL.md 本文の挙動説明と Workflow スクリプトの整合のみ確認）
- [ ] verify: SKILL.md 内の説明（AL-5 フェイルセーフ・rails 記述）と実装した null 経路が矛盾しない。行バジェット 280 行以内
