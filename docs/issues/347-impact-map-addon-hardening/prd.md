# PRD: impact_map / addon deploy の堅牢化（#323 レビュー由来の非ブロッキング所見対応）

## Problem

#323（影響範囲ベーステスト選択の consumer 提供）の `reviewing-deliverables` 2巡目レビューで surface した非ブロッキング所見が、マージ後も未解消のままになっている。コア correctness バグは #323 PR（#332）で修正済みだが、以下の5領域に残存する弱点がある。

1. **`parse_impact_rules` の堅牢性不足**: consumer が誤インデント（4-space/tab 等）でルールを書くと全 rule がサイレントスキップされ、`ERROR: no rules entries found`（exit 2）が真に空の rules ブロックとの区別不能なエラーとして出力される。また末尾空白付き glob や `rules:` キーの末尾空白も黙って誤動作する。
2. **`--base` 入力の未検証**: `-Spattern`（pickaxe）を渡すと git が短オプション解釈して空 diff・exit 0 を返し、CI バイパス相当の挙動が起きうる。`--output=/path` は任意ファイルを truncate しうる。
3. **consumer カスタマイズ config の上書き消失**: `setup-web` / `setup-ios` および session-start E2 Auto-Sync が `config/impact_rules.yml` を冪等性ガードなしに無条件上書きする。iOS では consumer カスタマイズが必須であり、セットアップ再実行でカスタマイズが消失しうる。addon.yml スキーマに保護オプションが存在しない。
4. **ドキュメント・ガイダンスの欠落**: FALLBACK 検出手順が `setup-web.md` に記載されていない。`addons/README.md` のスキーマ表に Required/Optional 区分がなく、`addons/web/README.md` が存在しない（他 addon は所持）。`scripts/README.md` に既存4スクリプトの説明がない。DEVELOPMENT.md に addon.yml `mcp_servers` の Zero Dependencies 規則適用外である旨の carve-out がない。
5. **コード・テスト品質の未整理**: `select_web` / `select_ios` がバイト同一で重複している。AT の grep 条件が緩く誤検知を許しうる。AT が非空チェックのみで内容を assert していない。変更した SKILL.md の BATS 証跡が記録されていない。

## Why now

#323 の実用運用（消費者プロジェクトでの iOS / web セットアップ）が始まる前に、consumer の誤操作がサイレント誤動作につながる経路と、セットアップ再実行によるカスタマイズ消失を塞ぐ必要がある。所見は既に整理済みで実装コストも小さく、放置による累積リスク（誤誘導・データ消失・CI バイパス）が閾値を超えると判断し今期対応とする。

## Outcome

- consumer が誤インデント・末尾空白を含む `impact_rules.yml` を渡したとき、サイレントスキップではなく診断可能なエラーメッセージが返る
- `--base` に `-` 始まりの文字列を渡したとき fail-closed でスクリプトが終了し、git への不正オプション注入が防がれる
- `setup-web` / `setup-ios` セットアップを再実行したとき、既存の `config/impact_rules.yml` が検出され、上書き警告または保護動作が行われる
- addon.yml スキーマに `if_not_exists` / `merge_strategy` が予約定義として存在し、将来の冪等保護実装の基盤が整っている
- `setup-web.md` に FALLBACK 検出手順（stderr 保持・`grep FALLBACK`・常時フォールバック時の CI fail ステップ）が記載されている
- `addons/README.md` スキーマ表に Required / Optional 列があり、`addons/web/README.md` が新規作成されている
- `scripts/README.md` に既存4スクリプトの説明と `--layer` の platform 制約が記載されている
- DEVELOPMENT.md に addon.yml `mcp_servers` の Zero Dependencies 規則 carve-out が一文追加されている
- `select_web` / `select_ios` の重複実装が `select_path_rules_only()` に統合されている
- AT の grep 条件が `--impact` 必須化・content assert 化されており、SKILL.md 変更の BATS 証跡が記録されている

## What

### カテゴリ 1: `parse_impact_rules` の堅牢性

- 誤インデント（4-space / tab）を検出したとき、エラーメッセージにインデント規約の言及を追加する
- 取り込んだ glob 文字列を trim して末尾空白を除去する
- `rules:` キーの exact equality 検出を trim 後比較に変更する
- 誤インデント・末尾空白 fixture を追加し、上記3ケースをカバーするテストを追加する

### カテゴリ 2: `--base` 入力検証

- `--base` 引数が `-` 始まりの場合、fail-closed でエラーを返し処理を停止する
- 検証ロジックのテストを追加する

### カテゴリ 3: consumer カスタマイズ config の上書き保護

- `setup-web` / `setup-ios` のセットアップコマンドに既存 `config/impact_rules.yml` の検出ロジックを追加し、既存ファイルが存在するときは上書き警告を出力する（または既存ファイルを保持する）
- addon.yml スキーマに `if_not_exists` / `merge_strategy` を予約フィールドとして定義（実装は将来 Issue に委譲可）

### カテゴリ 4: ドキュメント / ガイダンス

- `setup-web.md` に FALLBACK 検出手順（stderr 保持方法・`grep FALLBACK` コマンド・常時フォールバック時の CI fail ステップ推奨）を追加する
- `addons/README.md` のスキーマ表に Required / Optional 列を追加する
- `addons/web/README.md` を新規作成する（既存 addon README のスタイルに準拠）
- `scripts/README.md` に `bats_runner` / `check_bats_covers` / `run-skill-e2e` / `test-skills-headless` の説明と `--layer` の platform 制約を記載する
- DEVELOPMENT.md に「addon.yml の `mcp_servers` セクションは user-project 宣言であり Zero Dependencies 規則の対象外」の carve-out を追記する

### カテゴリ 5: コード / テスト品質

- バイト同一の `select_web` / `select_ios` を `select_path_rules_only()` 関数に統合し、両者をその関数の呼び出しに置き換える
- `AT-323-004b` の grep 条件を `--impact` 必須（`--base` 単独では pass しない）に厳格化する
- `AT-323-001b` / `AT-323-001c` の検証を非空チェックから返却識別子の content assert に強化する
- 本 PR で変更した SKILL.md ファイルごとに、変更前後の BATS 証跡を DEVELOPMENT.md の「Skill Changes Require Test Evidence」節に記録する（テストは green であること）

## Non-Goals

- `#334`（`running-atdd-cycle/SKILL.md` の red.jsonl 正規パス欠落と autopilot red-gate グロブ不一致）の対応 — 別サブシステムに関わる未検証所見であり、別途 Issue でトリアージする
- `#309`（`retrospective.sh` の `aggregate_turns` munged path によるDialogue Volume ゼロ化）の対応 — 同上、別 Issue で扱う
- `if_not_exists` / `merge_strategy` の完全実装 — 本 Issue はスキーマ予約とドキュメント化に留め、実際の冪等保護ロジックは別 Issue に委譲する
- `addons/web/README.md` 以外の addon README の新規作成 — 既存 addon README が存在する addon は対象外

## Open Questions

1. **addon.yml スキーマへの `if_not_exists` / `merge_strategy` 予約はドキュメントのみか、スキーマファイルへの明示追加か**
   → **Resolved（Gate① 承認）**: ドキュメント上の予約定義とし、スキーマファイルへのフィールド追記も行う。実装（動作）は別 Issue 委譲。

2. **`setup-web` / `setup-ios` の既存ファイル保護は「警告のみ」か「上書きスキップ」か**
   → **Resolved（Gate① 承認）**: 上書き警告（メッセージ出力）を必須とし、既存ファイル保持（スキップ）を推奨動作とする。完全な冪等保護は `if_not_exists` / `merge_strategy` 実装 Issue に委譲。
