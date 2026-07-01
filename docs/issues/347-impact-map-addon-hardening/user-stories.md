# User Stories: impact_map / addon deploy の堅牢化（#323 レビュー由来の非ブロッキング所見対応）

## Functional Story

<!-- 機能要求を persona 抜き Connextra 形式で記述する。1 ストーリー = 1 ユーザーゴール。 -->

### US-1: `parse_impact_rules` の診断可能なエラー化（カテゴリ 1）

**I want to** 誤インデント（4-space / tab）や末尾空白を含む `impact_rules.yml` を渡したとき、サイレントスキップではなくインデント規約に言及した診断可能なエラーメッセージを受け取り、取り込んだ glob と `rules:` キーが trim 後に正しく解釈される,
**so that** consumer が YAML の書き方を誤っても、真に空の rules ブロックと区別できる形で原因が示され、黙って全 rule がスキップされる誤動作を避けられる.

### US-2: `setup-web` / `setup-ios` 再実行時のカスタマイズ config 保護（カテゴリ 3）

**I want to** `setup-web` / `setup-ios` を再実行したとき、既存の `config/impact_rules.yml` が検出され、上書き警告が出力される（推奨動作として既存ファイルが保持される）,
**so that** iOS で必須の consumer カスタマイズがセットアップ再実行で消失せず、上書きされる前に気づける.

### US-3: addon.yml スキーマへの冪等保護フィールド予約（カテゴリ 3）

**I want to** addon.yml スキーマに `if_not_exists` / `merge_strategy` が予約フィールドとして定義されている（ドキュメント上の予約かつスキーマファイルへの明示追加）,
**so that** 将来の冪等保護実装（別 Issue 委譲）の基盤が整い、実装前でもスキーマ契約として認識できる.

### US-4: FALLBACK 検出手順・addon ドキュメントの整備（カテゴリ 4）

**I want to** `setup-web.md` に FALLBACK 検出手順（stderr 保持・`grep FALLBACK`・常時フォールバック時の CI fail ステップ）が記載され、`addons/README.md` スキーマ表に Required / Optional 列が追加され、`addons/web/README.md` が新規作成され、`scripts/README.md` に既存4スクリプトの説明と `--layer` の platform 制約が記載され、DEVELOPMENT.md に `mcp_servers` の Zero Dependencies carve-out が追記されている,
**so that** consumer と maintainer が FALLBACK 常時発生の検知手順・addon スキーマの必須/任意区分・スクリプトの用途を、他 addon と同等のドキュメント水準で参照できる.

### US-5: 重複実装の統合と AT の厳格化（カテゴリ 5）

**I want to** バイト同一の `select_web` / `select_ios` が `select_path_rules_only()` に統合され、`AT-323-004b` の grep 条件が `--impact` 必須化され、`AT-323-001b` / `AT-323-001c` が content assert に強化され、変更した SKILL.md ごとの BATS 証跡が DEVELOPMENT.md に記録されている,
**so that** 重複コードの二重メンテナンスが解消され、AT が緩い grep による誤検知や非空チェックのみの見逃しを許さず、SKILL.md 変更にテスト証跡が伴う.

## Constraint Story (Non-Functional)

<!-- 非機能要求（NFR）を Story 形式で表現する（Pichler 2013）。 -->

### CS-1: `--base` 入力の fail-closed 検証（カテゴリ 2）

**I want to** `--base` に `-` 始まりの文字列（`-Spattern` 等の git 短オプション相当）を渡したとき、スクリプトが fail-closed で終了し git への不正オプション注入が防がれている,
**so that** pickaxe 等の短オプション解釈による空 diff・exit 0 の CI バイパス相当挙動や、`--output=/path` による任意ファイル truncate が起きない.
