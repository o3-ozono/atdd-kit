# setup-* eager-copy 仕分け一覧

Issue #370。5 つの `setup-*` コマンドが現在プロジェクトへコピー・生成する成果物を実ファイル参照付きで洗い出し、
Gate①承認基準（「plugin インストール済み環境で Claude が参照経路を持つか」）に基づき二分類する。

- **参照で足りる（plugin-global 参照）**: plugin 本体（`${CLAUDE_PLUGIN_ROOT}` 経由）を直接参照すれば動作し、プロジェクトへコピーする必要がない。
- **プロジェクトローカルに要る（ユーザー管理）**: 書き込み対象・秘匿値・プロジェクト固有カスタマイズが必要なため、プロジェクトへ実体を置きユーザーが管理する必要がある。

## 仕分け表

| コマンド | 成果物 | ソースパス | 配置先 | 分類 | 判定根拠 |
|---------|--------|-----------|--------|------|---------|
| setup-github | Issue テンプレート（en/ja 各5種） | `templates/issue/en/*.yml`, `templates/issue/ja/*.yml` | `.github/ISSUE_TEMPLATE/*.yml` | プロジェクトローカルに要る | GitHub の Issue フォームは `.github/ISSUE_TEMPLATE/` 配下の実ファイルを GitHub 側が直接読む必要があり、plugin 参照では解決できない（GitHub 標準機能の制約）。 |
| setup-github | PR テンプレート | `templates/pr/en/pull_request_template.md` | `.github/pull_request_template.md` | プロジェクトローカルに要る | 上記と同じ理由（GitHub が `.github/` 配下の実ファイルを要求する）。 |
| setup-github | ワークフローラベル 16 種 | `commands/setup-github.md`（正準ソース） | GitHub リポジトリのラベル定義（`gh label create`） | プロジェクトローカルに要る | ラベルはリポジトリへの**書き込み対象**であり、ファイル参照では代替できない。本 Issue のオンデマンド移管対象外（W-3a の pre-flight check の対象ではあるが、eager-copy 自体は変更しない）。 |
| setup-ci | CI ワークフロー本体（base + addon 合成） | `templates/ci/base.yml`, `addons/<platform>/ci/*.yml` | `.github/workflows/pr.yml` | プロジェクトローカルに要る | GitHub Actions はリポジトリ内の `.github/workflows/*.yml` を直接実行する必要があり、plugin 参照では動作しない（GitHub Actions の実行モデル制約）。 |
| setup-discord | 通知スクリプト | `addons/discord/scripts/fa-notify-discord.sh` | `.claude/addons/fa-notify-discord.sh` | プロジェクトローカルに要る | `FA_NOTIFY_CMD` フックから呼ばれるプロジェクト固有の実行エントリであり、opt-in アドオンのため各プロジェクトが個別に有効化・カスタマイズする前提。 |
| setup-discord | webhook URL / mention 設定 | ユーザー入力（Step 2） | `.claude/settings.local.json`（`env`） | プロジェクトローカルに要る | **秘匿値**（Discord webhook はシークレット）。gitignore 対象のプロジェクトローカル設定に閉じ込める必要があり、plugin 参照や通常のコピーの対象外。本 Issue のオンデマンド移管対象外。 |
| setup-ios | MCP サーバー登録（XcodeBuildMCP 等 4 種） | `addons/ios/addon.yml` | `.mcp.json` | プロジェクトローカルに要る | `.mcp.json` はプロジェクトごとの MCP サーバー設定であり、Claude Code の仕様上プロジェクトファイルとして存在する必要がある。 |
| setup-ios | `sim-pool-guard.sh` | `addons/ios/scripts/sim-pool-guard.sh` | `.claude/hooks/sim-pool-guard.sh` | 参照で足りる（plugin-global 参照） | hook 本体はプロジェクト固有のロジックを持たず、`${CLAUDE_PLUGIN_ROOT}` 経由で plugin 本体を直接参照させれば動作する。W-3b の不変条件（hook は plugin-global 常時有効）と同じ扱いにできる。 |
| setup-ios | `lint-xcstrings.sh` | `addons/ios/scripts/lint-xcstrings.sh` | `scripts/lint-xcstrings.sh` | 参照で足りる（plugin-global 参照） | プロジェクト固有のカスタマイズを要さないユーティリティスクリプトであり、plugin 参照で解決可能。 |
| setup-ios | `impact_map.sh` | `scripts/impact_map.sh` | `scripts/impact_map.sh` | 参照で足りる（plugin-global 参照） | 汎用スクリプト本体はプロジェクト固有のロジックを持たない。plugin 参照で解決可能（`config/impact_rules.yml` のみプロジェクト固有）。 |
| setup-ios | `impact_rules.yml`（iOS 版） | `addons/ios/config/impact_rules.yml` | `config/impact_rules.yml` | プロジェクトローカルに要る | プロジェクトのディレクトリ構成に合わせてユーザーがカスタマイズする前提の設定ファイル（Step 3 相当のカスタマイズ余地）であり、書き込み・編集対象。 |
| setup-ios | PreToolUse hook 設定（`sim-pool-guard.sh` 呼び出し） | `commands/setup-ios.md` Step 4 | `.claude/settings.json`（`hooks.PreToolUse`） | プロジェクトローカルに要る | Claude Code の hooks 設定はプロジェクトの `.claude/settings.json` に存在する必要がある仕様上の制約（hooks.json の plugin-global 経路とは別レイヤー）。 |
| setup-web | `impact_map.sh` | `scripts/impact_map.sh` | `scripts/impact_map.sh` | 参照で足りる（plugin-global 参照） | setup-ios と同じ理由。汎用スクリプト本体はプロジェクト固有ロジックを持たない。 |
| setup-web | `impact_rules.yml`（Web 版） | `addons/web/config/impact_rules.yml` | `config/impact_rules.yml` | プロジェクトローカルに要る | プロジェクトのディレクトリ構成（`src/`, `components/` 等）に合わせてユーザーが手動カスタマイズする前提（Step 3）であり、書き込み対象。 |

## 高リスク項目の固定（Non-Goals）

以下は「プロジェクトローカルに要る」に固定し、本 Issue のオンデマンド移管対象外とする（PRD の Non-Goals：高リスク破壊移管の除外と一致）。

- **discord webhook（秘匿値）**: シークレットのため plugin 参照や自動生成の対象にできない。ユーザーが `setup-discord` を明示実行して個別に設定する運用を維持する。
- **GitHub ラベル（書き込み対象）**: リポジトリへの書き込みが必要なため、ファイル参照モデルでは代替できない。W-3a の pre-flight check（不足検出・confirm 後作成）は追加するが、eager-copy の「コピーする/しない」の分類自体は変更しない＝オンデマンド移管対象外。

## 未分類チェック

全 14 行に「参照で足りる」または「プロジェクトローカルに要る」のいずれかと、1 行以上の判定根拠が記載されている。未分類（空欄）の行は 0 件。
