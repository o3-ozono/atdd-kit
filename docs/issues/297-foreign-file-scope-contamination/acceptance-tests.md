# Acceptance Tests: autopilot impl phase が並行セッションの未追跡ファイル混入で偽 MAX_ITERATIONS / スコープ汚染を起こす問題の解消

<!-- AT lifecycle: planned → draft → green → regression
     各エントリには状態マーカー [planned] / [draft] / [green] / [regression] を付与する。
     状態は実装の進行に合わせて更新する。 -->

実装先（ターゲット）: `tests/acceptance/AT-297.bats`（新規・AT-296.bats 形式に倣う・grep ベース不変条件）。
各 AT は acceptance-tests.md の AC と 1:1 対応し、AC→AT トレーサビリティを満たす。

> **スコープ宣言（重要）:** AT-297-* は SKILL.md の guard/critic 文言を grep で string-pin する**不変条件検証**であり、foreign 未追跡ファイル混入の **runtime/behavioral シナリオ再現（実際にスコープ外コミットが生成されないこと等の挙動）は意図的にスコープ外**である。理由: autopilot ループは subagent を spawn しなければ BATS 内で決定的に実走できず、既存 AT-296.bats も同一の grep string-pin 規約（検証済み 11 アサーション）を採用するため。PRD Outcome bullet 4 / US-4 の「シナリオを再現し」の意図は、本 AT では guard/critic 文言（スコープ外コミット禁止・回避設定禁止・エスカレーション・P0 混入検知）の存在保証で代替（narrowing）する。

## AT-297-1: foreign 未追跡ファイル不可触ガードが GEN_GUARD に明記される（US-1）

- [ ] [planned] AT-001: GEN_GUARD に foreign 未追跡/未コミットファイル不可触ガード文が存在する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/autopilot/SKILL.md` の `GEN_GUARD` 定数定義を検査する
  - Then: GEN_GUARD 文字列に「自分が作成していない／当該 Issue スコープ外の未追跡・未コミットファイルを変更・コミット・ゲート回避設定（exclude 等）の対象にしない」旨が grep ヒットする
  - verify: `grep -nE 'GEN_GUARD' skills/autopilot/SKILL.md` で定数行を特定し、その文字列内に foreign/未追跡 と「変更・コミットしない（exclude 等の回避設定を含む）」相当語が含まれる

## AT-297-2: foreign 由来ゲート失敗のエスカレーション指示が GEN_GUARD に明記される（US-2）

- [ ] [planned] AT-002: GEN_GUARD に foreign 由来ゲート失敗時の COMPLETED_WITH_DEBT エスカレーション指示が存在する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/autopilot/SKILL.md` の `GEN_GUARD` 定数定義を検査する
  - Then: GEN_GUARD 文字列に「foreign ファイル由来でゲートが失敗する場合は修正を試みず COMPLETED_WITH_DEBT として人間にエスカレーションする」旨が grep ヒットする
  - verify: GEN_GUARD 定数文字列内に `COMPLETED_WITH_DEBT` とエスカレーション相当語が、foreign ゲート失敗の文脈で共起する

## AT-297-3: 混入検知が impl review scope に組み込まれ P0 finding 化される（US-3）

- [ ] [planned] AT-003: reviewScope の impl 分岐にスコープ外パス変更の P0 finding 検出指示が存在する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/autopilot/SKILL.md` の `reviewScope(step)` の `PHASE === 'impl'` 分岐文字列を検査する
  - Then: impl scope 文に「当該 Issue スコープ外パスへの変更（特に `pyproject.toml` / CI 設定 / 他 Issue のソース）を検出したら P0 finding として返す」旨が grep ヒットする
  - verify: reviewScope impl 分岐文字列に「スコープ外（foreign）パス」「pyproject.toml / CI / 他 Issue ソース」「P0 finding」相当語が共起し、design 分岐（US/plan scope 文）には当該文言が混入していない

## AT-297-4: oracle が混入 finding を green 誤認しない（US-3／非退行不変条件）

- [ ] [planned] AT-004: satisfaction oracle の P0/P1 ブロッキング判定式が無改変で維持される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `skills/autopilot/SKILL.md` の satisfaction oracle 収束判定式を検査する
  - Then: `overall_correctness === 'correct'` かつ `blocking.length === 0`（priority <= 1 を blocking とする）の判定式が存在し、混入 P0 finding が green 判定を阻止する経路が維持されている
  - verify: `grep` で `overall_correctness === 'correct'` と `blocking.length === 0`、および `priorityOf(f) <= 1` のフィルタ式が存在する

## AT-297-5: SKILL.md 行数バジェットが維持される（US-4／CS-1 不変条件）

- [ ] [planned] AT-005: 追記後も SKILL.md が line budget pin（<= 280 行）を満たす
  - Given: 本 Issue の guard/critic 追記を適用した作業ツリー
  - When: `wc -l skills/autopilot/SKILL.md` を実行する
  - Then: 行数が 280 以下（既存 line budget pin と整合・3 回目の raise を発生させない）
  - verify: `[[ $(wc -l < skills/autopilot/SKILL.md) -le 280 ]]`

## AT-297-6: 既存 autopilot skill テスト群が非退行で green（CS-1）

- [ ] [planned] AT-006: GEN_GUARD / COMPLETED_WITH_DEBT / reviewScope の既存アサーションが維持される
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `tests/test_autopilot_skill.bats` の関連アサーション対象（GEN_GUARD 連結・COMPLETED_WITH_DEBT・reviewScope phase×step）を検査する
  - Then: 既存アサーションが指す構造（GEN_GUARD が両 gen 指示に連結・impl/design scope 分岐・COMPLETED_WITH_DEBT エスカレーション）が SKILL.md に存在し続ける
  - verify: `bats tests/test_autopilot_skill.bats` が全ケース green（実 ATDD 実行時）／本 AT は grep で GEN_GUARD 連結（`${GEN_GUARD}` がテンプレートリテラルに含まれる）と reviewScope の design/impl 両分岐の存在を確認する

## AT-297-7: バージョン bump ＋ CHANGELOG がリリース規約に従う（AC-COM）

- [ ] [planned] AT-007: plugin.json version が CHANGELOG 最新リリース見出しと一致する
  - Given: 本 Issue の変更を適用した作業ツリー
  - When: `.claude-plugin/plugin.json` の version と `changelog_latest_release CHANGELOG.md` を突き合わせる
  - Then: version が SemVer で minor bump され、CHANGELOG 最新リリース見出しと完全一致する（特定 version 値はピンしない不変条件）
  - verify: `tests/acceptance/helpers/changelog.bash` を source し `changelog_latest_release` 出力が plugin.json version と一致する

## ライフサイクル例

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装 |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
