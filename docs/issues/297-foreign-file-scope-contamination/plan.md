# Plan: autopilot impl phase が並行セッションの未追跡ファイル混入で偽 MAX_ITERATIONS / スコープ汚染を起こす問題の解消

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## 設計判断（実装方針）

| 対象 | 採用箇所 | 理由 |
|------|----------|------|
| US-1/US-2 behavioral guard | `skills/autopilot/SKILL.md` の `GEN_GUARD` 定数（現 L120 単一行文字列） | gen 指示は全 step で `GEN_GUARD` を連結する（L202-203）。ここに 1 文を追記すれば impl gen にも自動で伝播し、#288 の orchestrator 所有物保護と同じ場所で整合管理できる。 |
| US-3 混入検知 critic | `reviewScope(step)`（現 L171 付近、`PHASE === 'impl'` 分岐）への scope 文言追記 | review は phase×step scope を gen とは別コンテキストで評価する。impl scope 文に「スコープ外パスへの変更（`pyproject.toml`/CI 設定/他 Issue ソース）を検出したら P0 finding」を加えれば、既存の satisfaction oracle（`blocking.length === 0`）が green 誤認を自動で阻止する。新規ループ部品を増やさない。**この critic はスコープ汚染が `git diff main...HEAD` に COMMIT 済みになって初めて検出する**（PRD の `pyproject.toml` exclude コミットがこれに該当）。foreign **未追跡**ファイル自体は diff に現れない ── 「コミットこそが汚染本体・未追跡ファイルは単なるトリガ」であり、これは正しい挙動である（US-3 は未追跡ファイル検出ではなくコミット済みスコープ外変更の検出を担う）。 |
| US-4 回帰 AT | `tests/acceptance/AT-297.bats`（新規・既存 AT-296.bats 形式に倣う） | 文字列ピン回帰（grep ベース）。SKILL.md の guard/critic 文言の存在を不変条件として検証する。**behavioral scenario reproduction（runtime での foreign 混入再現）は意図的にスコープ外** ── autopilot ループは subagent spawn 無しに BATS 内で決定的に実走できず、既存 AT-296.bats も同じ grep string-pin 規約（検証済み 11 アサーション）を採用するため。PRD Outcome bullet 4 / US-4 の「シナリオを再現し」は本 AT では guard/critic 文言の string-pin に narrowing される（runtime 挙動検証は代替・descope）。 |
| CS-1 非矛盾 | `tests/test_autopilot_skill.bats` の既存アサーション（GEN_GUARD/COMPLETED_WITH_DEBT/reviewScope/line budget）を before/after で green 維持 | DEVELOPMENT.md「Skill Changes Require Test Evidence」。 |

### 行数バジェット制約（必読）

`tests/test_autopilot_skill.bats` の line budget pin は `wc -l skills/autopilot/SKILL.md <= 280`、現状 **279 行**（余裕 1 行）。#254 で 240→260→280 と **既に 2 回 raise 済み**のため、DEVELOPMENT.md「SKILL.md Line-Budget Raises（cumulative 2 回まで・3 回目は禁止／loader stub 分割）」により **3 回目の raise は不可**。

→ 本 Issue の guard/critic 追記は **新規行を増やさず、既存の `GEN_GUARD` 文字列 1 行（現 L120・250 文字の単一行）および `reviewScope` の impl 分岐文字列内に追記**して実装する。

**ヘッドルームを commit 前に定量化する（必須・余裕 1 行のため）:** マージン 1 行は guard/critic を追記する 2 箇所（`GEN_GUARD` 1 行・`reviewScope` impl 分岐 1 行）がいずれも改行を増やさず**同一行内に収まる**ことに完全依存する。impl は追記前に各対象行の現在の文字数を測り（`awk 'NR==N{print length}'`）、追記後も両行が単一行のまま（行数が増えていない）であることを `wc -l` で**追記直後に**確認する。エディタ／プリティ整形が長い行を折り返して 1 行でも増えれば 280→280 超過＝禁止された 3 回目 raise に直結するため、`wc -l skills/autopilot/SKILL.md == 279`（追記前）と `<= 280`（追記後）の両方を測定し、差分が 0 行であることを示してから commit する。やむを得ず超過する場合は guard を追記せず、本 Issue を loader stub 分割（別 Issue）の前段として COMPLETED_WITH_DEBT エスカレーションする（バジェット違反コミットは禁止）。

## Implementation

- [ ] US-1/US-2: `skills/autopilot/SKILL.md` の `GEN_GUARD` 定数文字列に、foreign 未追跡/未コミットファイルガード文（「自分が作成しておらず当該 Issue のスコープ外の未追跡/未コミットファイルは変更・コミット・ゲート回避設定（exclude 等）の対象にしない。ゲートがそれら由来で失敗する場合は修正せず COMPLETED_WITH_DEBT として人間にエスカレーションする」旨）を **既存行内に**追記する
- [ ] verify: `grep -n` で `GEN_GUARD` 定数に foreign/未追跡 と COMPLETED_WITH_DEBT エスカレーション文言が含まれることを確認し、`GEN_GUARD` が依然 L202-203 の両 gen 指示に連結されている（差分が定数定義のみ）ことを確認

- [ ] US-3: `reviewScope(step)` の `PHASE === 'impl'` 分岐文字列に、「当該 Issue のスコープ外パスへの変更（特に `pyproject.toml` / CI 設定 / 他 Issue のソース）を検出したら P0 finding として返す」旨を **既存行内に**追記する（検出対象は `git diff main...HEAD` に現れる COMMIT 済みのスコープ外変更であり、foreign 未追跡ファイル自体ではない ── コミットこそが汚染本体）
- [ ] verify: `grep` で reviewScope の impl scope 文にスコープ外パス検出＋P0 文言が存在し、design 分岐（US/plan scope）には混入していないことを確認。`overall_correctness === 'correct'` と `blocking.length === 0` の oracle 式が無改変であることを `grep` で確認

- [ ] 行数バジェット確認（commit 前にヘッドルームを定量化）: 追記前に `wc -l skills/autopilot/SKILL.md`（== 279 を記録）と対象 2 行の現在文字数を `awk 'NR==N{print length}'` で測定し、追記後に再測定して **行数差分が 0**・両対象行が単一行のまま・`wc -l <= 280` であることを確認する
- [ ] verify: 追記後の `wc -l < skills/autopilot/SKILL.md` が `<= 280` かつ追記前 279 からの増分が 0 行。1 行でも増えていれば（折り返し含む）追記方法を行内圧縮に見直す（pin の raise は禁止・3 回目に該当）

## Testing

- [ ] US-4: `tests/acceptance/AT-297.bats` を新規作成し、AT-296.bats 形式（`@covers:` ヘッダ・repo_root 解決・grep ベース不変条件）で US-1〜US-4・CS-1 をカバーする AT を実テストとして記述する
- [ ] verify: `bats tests/acceptance/AT-297.bats` が全ケース green。各ケースが acceptance-tests.md の AC と 1:1 対応（AC→AT トレーサビリティ）
- [ ] 既存 autopilot skill テストの非退行確認: `bats tests/test_autopilot_skill.bats` を変更前後で実行する
- [ ] verify: GEN_GUARD / COMPLETED_WITH_DEBT / reviewScope / line budget の各アサーションが before/after とも green（CS-1）
- [ ] 収束レール非退行確認: `bats tests/acceptance/test_autopilot_convergence.bats`
- [ ] verify: AL-1〜AL-6 / #288 ガードのアサーションが green（CS-1）

## Finishing

- [ ] バージョン bump（minor: 既存 skill への新規ガード追加）＋ `CHANGELOG.md` エントリ追加（同一 PR 内）
- [ ] verify: `.claude-plugin/plugin.json` version が SemVer で minor bump され、`CHANGELOG.md` 最新リリース見出しと完全一致する（`changelog_latest_release` ヘルパーで照合・特定値はピンしない）
- [ ] ドキュメント整合性チェック（skill 追加はないため `skills/README.md` 更新は不要／GEN_GUARD・reviewScope の挙動変更が SKILL.md 本文の周辺説明と整合しているか確認）
- [ ] verify: SKILL.md 内の GEN_GUARD/reviewScope を説明する周辺記述（#288 ガード説明等）と追記内容が矛盾しない。`tests/` ディレクトリ README が新規ファイル AT-297.bats を反映（必要なら更新）
