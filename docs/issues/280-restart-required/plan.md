# Plan: session-start のプラグインバージョン検知 — RESTART_REQUIRED / STALE_SESSION の追加

<!-- 2-5 分粒度のタスク行と verify 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verify で完了条件を即確認できる粒度にする。 -->

## 設計判断（Open Questions の確定 — prd.md:42-43）

実ファイルを確認して PRD の 2 つの Open Question を確定した。本節は確定結果の記録であり、以降のタスクはこれを前提とする。

- **OQ1（installed_plugins.json スキーマ / US-1 依存）:** `~/.claude/plugins/installed_plugins.json` は `{"version":<int>, "plugins":{<key>:[<entry>...]}}` 構造。atdd-kit のキーは `"atdd-kit@atdd-kit"`、各エントリは `scope` / `projectPath` / `installPath` / `version` / `installedAt` を持つ。**当該プロジェクトの特定キーは `projectPath` がカレントプロジェクトルートに一致するエントリ**。その `version` を installed 版（`INSTALLED`）とする。実測例: `projectPath=/Users/o3/github.com/o3-ozono/atdd-kit`, `version=3.12.0`。なお `installPath` は末尾がロード版ディレクトリ（`.../atdd-kit/3.12.0`）であり、ロード版は従来どおり `PLUGIN_ROOT/.claude-plugin/plugin.json` から読む（`CURRENT`）。
- **OQ2（RESTART_REQUIRED と STALE_SESSION の同時成立 / US-1・US-2 co-trigger）:** `CURRENT < CACHED`（STALE）かつ `INSTALLED > CURRENT`（RESTART）が同時に成立しうる。**優先順位は STALE_SESSION > RESTART_REQUIRED > UPDATED/NO_UPDATE/FIRST_RUN** とする。理由: STALE_SESSION のみがマーカー書き戻し抑止と E2 Auto-Sync スキップ（ダウングレード上書き防止）を担うため、同時成立時は STALE_SESSION を出力して最も安全側に倒す。両者とも最終的に「再起動を促す」点は共通。

## 検知ロジックの分岐順序（実装の単一ソース）

`check-plugin-version.sh` の判定を次の順序で評価する（上から先に一致したもので確定）:

1. **FIRST_RUN** — マーカー不在（従来どおり、マーカー作成）
2. **STALE_SESSION** — `CURRENT < CACHED`（`sort -V`）。マーカー非更新。出力 `STALE_SESSION\n<loaded>\n<cached>`
3. **RESTART_REQUIRED** — `INSTALLED > CURRENT`（`sort -V`、installed_plugins.json から取得）。マーカー非更新。出力 `RESTART_REQUIRED\n<loaded>\n<installed>`
4. **NO_UPDATE** — `CACHED == CURRENT` かつ上記いずれにも該当せず（従来どおり）
5. **UPDATED** — `CACHED != CURRENT` かつ `CURRENT > CACHED`（従来どおり、ただし CHANGELOG 集計ガード適用、マーカー更新）

## Implementation

- [ ] `check-plugin-version.sh` の出力プロトコルヘッダコメント（3-7 行目）に `RESTART_REQUIRED` / `STALE_SESSION` の 2 経路と引数追加を追記する
- [ ] verify: ヘッダに両トークンと新引数の記載があり、`bash -n scripts/check-plugin-version.sh` が構文 OK

- [ ] `check-plugin-version.sh` に第3引数 `installed_plugins_json`（省略可、デフォルト `${HOME}/.claude/plugins/installed_plugins.json`）と第4引数 `project_path`（省略可、デフォルト `$PWD`）を受け取る変数を追加する
- [ ] verify: 引数未指定でも従来の 2 引数呼び出しが壊れず動く（`./scripts/check-plugin-version.sh "$ROOT" "$CACHE"` が従来出力）

- [ ] installed 版を読むヘルパ `read_installed_version` を追加: `installed_plugins.json` が存在し parse 可能なら `jq -r --arg p "$PROJECT_PATH" '.plugins["atdd-kit@atdd-kit"][]? | select(.projectPath==$p) | .version'` で取得、ファイル不在/parse 不能/該当エントリなしなら空文字を返す（フォールバック）
- [ ] verify: ファイル不在・空 JSON・該当エントリなしの 3 ケースでヘルパが空文字を返し非ゼロ終了しない（`set -e` 下でも継続）

- [ ] semver 比較ヘルパ `ver_gt A B`（`A > B` を `sort -V` で判定）と `ver_lt A B` を追加する
- [ ] verify: `ver_gt 3.12.0 3.11.1` が真、`ver_gt 3.11.1 3.12.0` が偽、同値で偽

- [ ] FIRST_RUN 判定の直後・NO_UPDATE 判定の前に **STALE_SESSION 分岐**（`ver_lt "$CURRENT" "$CACHED"` 真なら `STALE_SESSION` / loaded / cached を出力し、マーカー非更新で `exit 0`）を追加する
- [ ] verify: `CACHED=3.12.0`, `CURRENT=3.11.1` で `STALE_SESSION\n3.11.1\n3.12.0` が出力され、マーカーが `3.12.0` のまま不変

- [ ] STALE_SESSION 分岐の直後に **RESTART_REQUIRED 分岐**（`INSTALLED` 非空 かつ `ver_gt "$INSTALLED" "$CURRENT"` 真なら `RESTART_REQUIRED` / loaded / installed を出力し、マーカー非更新で `exit 0`）を追加する
- [ ] verify: `CURRENT=3.11.1`, installed_plugins.json の当該 projectPath version=3.12.0 で `RESTART_REQUIRED\n3.11.1\n3.12.0` が出力され、マーカー不変。`CACHED==CURRENT`（従来 NO_UPDATE 相当）でも RESTART が優先して出る

- [ ] UPDATED 経路の CHANGELOG 集計ループに **集計ガード**を追加: ループ中に `CACHED` の `## [x.y.z]` 見出しに一度も到達せずループ終端に達したら `VERSIONS` を数値ではなく `UNKNOWN` として出力する（`break` 到達フラグで判定）
- [ ] verify: CHANGELOG に CACHED 見出しが無いケースで 4 行目が `VERSIONS: UNKNOWN` になり、`VERSIONS: 63` のような全件誤集計が出ない。CACHED 見出しがあるケースは従来どおり数値

- [ ] `skills/session-start/SKILL.md` の Phase 1-E 出力パースに `RESTART_REQUIRED`（3 行: トークン/loaded/installed → 「新版 v<installed> がインストール済み — セッション再起動で反映されます」をレポートに表示）と `STALE_SESSION`（3 行: トークン/loaded/cached → 「ロード版 v<loaded> がマーカー版 v<cached> より古い — セッション再起動が必要」をレポートに表示、**かつ E2 Auto-Sync をスキップ**）の行を追加する
- [ ] verify: SKILL.md の Phase 1-E に両トークンのパース行があり、STALE_SESSION 時に E2 をスキップする旨が明記されている

- [ ] `skills/session-start/SKILL.md` の E2 Auto-Sync 節冒頭の発火条件を「only if UPDATED」から「only if UPDATED（STALE_SESSION / RESTART_REQUIRED 時は実行しない）」に明示更新し、Phase 3 レポートテンプレートに RESTART_REQUIRED / STALE_SESSION の再起動メッセージ行を追加する
- [ ] verify: E2 節の発火条件に除外が明記され、Phase 3 テンプレートに両ケースの再起動文言がある

## Testing

- [ ] `tests/test_check_plugin_version.bats` の setup に installed_plugins.json フィクスチャ生成ヘルパ（任意 projectPath/version でファイルを書く関数）を追加する
- [ ] verify: ヘルパで生成した JSON を新引数で渡せ、既存テストが全て green のまま

- [ ] STALE_SESSION 分岐の BATS テストを追加（`CACHED>CURRENT` で `STALE_SESSION`/loaded/cached 出力・マーカー不変）
- [ ] verify: `bats tests/test_check_plugin_version.bats` で当該テストが green

- [ ] RESTART_REQUIRED 分岐の BATS テストを追加（installed>loaded で出力・マーカー不変、かつ `CACHED==CURRENT` でも RESTART が出る co-existence ケース）
- [ ] verify: 当該テストが green

- [ ] STALE+RESTART 同時成立で **STALE_SESSION が優先**される BATS テストを追加（OQ2 の確定動作）
- [ ] verify: 同時成立フィクスチャで 1 行目が `STALE_SESSION`

- [ ] フォールバック BATS テストを追加（installed_plugins.json 不在 / parse 不能 / 該当 projectPath エントリなしの 3 ケースで従来 FIRST_RUN / NO_UPDATE / UPDATED が壊れない）
- [ ] verify: 3 ケースとも RESTART_REQUIRED を出さず従来トークンを出力

- [ ] CHANGELOG 集計ガードの BATS テストを追加（CACHED 見出し不在で `VERSIONS: UNKNOWN`、見出しありで従来の数値）
- [ ] verify: 両ケースが期待どおり

- [ ] 再起動後の正常系復帰 BATS テストを追加（RESTART/STALE を起こしたフィクスチャから loaded を installed と一致させた次回呼び出しで、従来どおり数値件数付き UPDATED または NO_UPDATE に戻る）
- [ ] verify: 復帰ケースで RESTART/STALE が消え正常トークンに戻る

- [ ] 既存 BATS スイート全体を実行して回帰がないことを確認する
- [ ] verify: `bats tests/test_check_plugin_version.bats tests/test_session_start_version.bats` が全 green

## Finishing

- [ ] `plugin.json` のバージョンを bump し、`CHANGELOG.md` に Keep a Changelog 形式で本機能のエントリ（Added: RESTART_REQUIRED / STALE_SESSION 検知, CHANGELOG 集計ガード）を追加する
- [ ] verify: `## [Unreleased]` 直下に新バージョン見出しと Added エントリがあり、`plugin.json` の version が一致して bump 済み

- [ ] ドキュメント整合性チェック（`scripts/check-plugin-version.sh` ヘッダ・`skills/session-start/SKILL.md`・`tests/README.md` のテスト一覧が変更内容と整合）
- [ ] verify: 関連ドキュメントが変更内容と整合し、出力プロトコルの記述が実装・テスト・SKILL の三者で一致
