# Plan: impact_map / addon deploy の堅牢化（#323 レビュー由来の非ブロッキング所見対応）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## Implementation

### US-1: `parse_impact_rules` の診断可能なエラー化（カテゴリ 1）

- [ ] `scripts/impact_map.sh` の `parse_impact_rules` で、取り込んだ `path:` glob（`raw_path`）を quote 除去後に前後空白を trim する
- [ ] verify: 末尾空白付き `- path: src/**  ` を含む fixture で `--all` を実行し、格納 glob が `src/**`（末尾空白なし）として fnmatch 一致する

- [ ] `bats:` タグ（`raw_bats`）も同様に trim し、`skill-e2e:` ターゲット値の末尾空白も除去する
- [ ] verify: 末尾空白付き `skill-e2e:` / `bats:` を含む fixture で `--all` 実行時に余分な空白を含まない識別子が出力される

- [ ] `rules:` セクション検出を exact equality（`"$line" == "rules:"`）から trim 後比較（前後空白除去した値が `rules:`）に変更する
- [ ] verify: 末尾空白付き `rules: ` 行を含む fixture で `has_rules_section=1` となり `missing 'rules:' section` エラーが出ない

- [ ] `rules:` 配下で誤インデント（4-space / tab）の `- path:` 行を検出したとき、インデント規約（2-space）に言及する診断メッセージを stderr に出し、真に空の rules ブロックと区別可能な非ゼロ終了にする
- [ ] verify: 4-space インデント fixture で実行すると stderr にインデント規約への言及を含むメッセージが出て、`no rules entries found`（区別不能なエラー）にはならない

### CS-1: `--base` 入力の fail-closed 検証（カテゴリ 2）

- [ ] 引数パース後（`--all` 未指定時の `--base` 必須チェック付近）に、`$OPT_BASE` が `-` 始まりなら fail-closed でエラー終了する検証を追加する
- [ ] verify: `--base -Spattern` を渡すと非ゼロ終了し、stderr に不正 base を示すメッセージが出て、`git diff` に短オプションが渡らない

- [ ] `--base` 値が `--output=/path` 相当（`-` 始まりで `=` を含む任意ファイル truncate 経路）でも同一検証で弾かれることを確認する
- [ ] verify: `--base --output=/tmp/x` 等の敵対的入力で非ゼロ終了し、対象ファイルが truncate されない

### US-2: `setup-web` / `setup-ios` 再実行時のカスタマイズ config 保護（カテゴリ 3）

- [ ] `commands/setup-web.md` のセットアップ手順に、`config/impact_rules.yml` が既存なら上書き警告を出し既存ファイルを保持（スキップ）する検出ステップを追記する
- [ ] verify: `commands/setup-web.md` に既存 `config/impact_rules.yml` 検出・上書き警告・保持（推奨動作）の記述が含まれる

- [ ] `commands/setup-ios.md` に同等の既存 config 検出・上書き警告・保持ステップを追記する
- [ ] verify: `commands/setup-ios.md` に同等記述が含まれ、iOS 必須カスタマイズの消失防止が明記される

### US-3: addon.yml スキーマへの冪等保護フィールド予約（カテゴリ 3）

- [ ] `addons/web/addon.yml` の `deploy` エントリに `if_not_exists` / `merge_strategy` を予約フィールドとして（コメント付きで、動作は将来 Issue 委譲の旨明示）追加する
- [ ] verify: `addons/web/addon.yml` に `if_not_exists` と `merge_strategy` が予約フィールドとして出現する

- [ ] `addons/ios/addon.yml` の該当 `deploy` エントリにも同フィールドを予約追加する
- [ ] verify: `addons/ios/addon.yml` に両フィールドが予約として出現する

- [ ] `addons/README.md` の addon.yml Schema 表に `if_not_exists` / `merge_strategy` の行を追加し、予約（将来実装）である旨を Description に記す
- [ ] verify: `addons/README.md` スキーマ表に両フィールド行が存在し、予約定義であることが読み取れる

### US-5: 重複実装の統合（カテゴリ 5・実装分）

- [ ] バイト同一の `select_web` / `select_ios` を単一関数 `select_path_rules_only()` に統合する
- [ ] verify: `scripts/impact_map.sh` に `select_path_rules_only` が定義され、`select_web` / `select_ios` の関数本体定義が消える

- [ ] main ロジックの `web` / `ios` ケースを `select_path_rules_only` 呼び出しに置き換える
- [ ] verify: `--platform web` / `--platform ios` の分類が `select_path_rules_only` を経由し、既存 AT-323-001b/001c が引き続き pass する

### US-4: ドキュメント整備（カテゴリ 4）

- [ ] `commands/setup-web.md` に FALLBACK 検出手順（stderr 保持方法・`grep FALLBACK` コマンド・常時フォールバック時の CI fail ステップ推奨）を追記する
- [ ] verify: `commands/setup-web.md` に `FALLBACK` 保持・`grep FALLBACK`・CI fail ステップの3要素が含まれる

- [ ] `addons/README.md` のスキーマ表（またはトップ addon 一覧）に Required / Optional 列を追加する
- [ ] verify: `addons/README.md` に Required / Optional 区分の列が存在する

- [ ] `addons/web/README.md` を既存 addon README（例: `addons/discord/README.md` / `addons/ios/README.md`）のスタイルに準拠して新規作成する
- [ ] verify: `addons/web/README.md` が存在し、web addon の deploy 内容・使い方を記述している

- [ ] `scripts/README.md` に `bats_runner.sh` / `check_bats_covers.sh` / `run-skill-e2e.sh` / `test-skills-headless.sh` の説明と `--layer` の platform 制約を追記する
- [ ] verify: `scripts/README.md` に4スクリプトの説明行と `--layer` platform 制約の記述が含まれる

- [ ] `DEVELOPMENT.md` の Zero Dependencies 節に、addon.yml `mcp_servers` は user-project 宣言であり Zero Dependencies 規則の対象外である carve-out を一文追記する
- [ ] verify: `DEVELOPMENT.md` に `mcp_servers` の Zero Dependencies carve-out 一文が含まれる

## Testing

### US-1 / CS-1 / US-5: `impact_map.sh` の BATS

- [ ] 誤インデント（4-space / tab）・末尾空白 fixture を追加し、US-1 の3ケース（診断エラー・glob trim・`rules:` trim 比較）をカバーする BATS を追加する
- [ ] verify: 追加 BATS が green で、旧挙動（サイレントスキップ／区別不能エラー）を回帰的に禁止する

- [ ] `--base -Spattern` / `--base --output=/path` 等の敵対的入力で fail-closed を検証する BATS を追加する（CS-1）
- [ ] verify: 追加 BATS が green で、非ゼロ終了・truncate 無し・git への短オプション不注入を assert する

- [ ] `select_path_rules_only` 統合後も `--platform web` / `--platform ios` が同一結果を返す回帰 BATS を確認・追加する（US-5）
- [ ] verify: 統合前後で web/ios 分類の出力が不変であることが BATS で green

### US-5: 既存 AT の厳格化

- [ ] `AT-323-004b` の grep 条件を `--impact|--base` の緩い alternation から `--impact` 必須（`--base` 単独では pass しない）に厳格化する
- [ ] verify: `merging-and-deploying/SKILL.md` から `--impact` 記述を除くと AT-323-004b が fail する（`--base` だけでは pass しない）

- [ ] `AT-323-001b` / `AT-323-001c` を非空チェック（`[ -n "$output" ]`）から、返却された web/iOS 識別子の content assert（期待識別子文字列を含む）に強化する
- [ ] verify: 誤った識別子や空でない無関係出力では AT-323-001b/001c が fail し、正しい識別子を含むときのみ pass する

## Finishing

- [ ] 本 PR で変更した SKILL.md ファイルごとに、変更前後の BATS 証跡を `DEVELOPMENT.md` の「Skill Changes Require Test Evidence」節に記録する（証跡テストは green）
- [ ] verify: `DEVELOPMENT.md` に本 PR で変更した各 SKILL.md の BATS 証跡が記録され、参照される BATS が green

- [ ] `CHANGELOG.md` に本 Issue の変更（robustness / doc hardening）を Keep a Changelog 形式で追記し、`plugin.json` の version と整合させる
- [ ] verify: `CHANGELOG.md` 最上段のリリース見出しと `plugin.json` の version が一致し、本 Issue の変更が記載されている

- [ ] ドキュメント整合性チェック（setup-web.md / addons/README.md / addons/web/README.md / scripts/README.md / DEVELOPMENT.md）
- [ ] verify: 関連ドキュメントが実装・スキーマ変更と整合し、記述と実ファイル/実挙動に齟齬がない
