# atdd-kit

[English](README.md)

*このrepositoryの日本語はLLMが英語から直接翻訳しています。ご了承くださいまし

ATDD (Acceptance Test Driven Development) で開発プロセスを回す Claude Code プラグイン。Issue 作成からマージまで、構造化されたテストファーストの道筋で一気通貫。

Issue を作り、要件を整理し、受け入れ基準(AC)を導き出し、テストを先に書き、実装し、レビューし、PR をマージする。この一連のワークフローをプラグインとして提供します。

## なぜ atdd-kit？

AI コーディングアシスタントはコードを書けますが、構造化された開発プロセスを持っていません。ガードレールがなければ、要件の探索をスキップし、テストの前にコードを書き、検証なしにマージしてしまいます。

atdd-kit はこの問題を **Issue 駆動・テストファーストのワークフロー** で解決します:

- **すべての変更は Issue から始まる** — 追跡された要件なしにコードは書かない
- **受け入れ基準は対話から導出される** — 推測ではない
- **テストは実装の前に書く** — ATDD ダブルループ（E2E が先、次にユニットテスト）
- **エビデンスベースの検証** — マージ前にすべての AC をテスト結果で検証

設計原則: ゼロ依存、プラグインアーキテクチャ、純粋な markdown + bash。

**6 ステップのフロー**が各 Issue を要件からデプロイまで運びます: 要件定義 → ユーザーストーリー抽出 → 計画 + 受け入れテスト作成 → ATDD サイクル → レビュー → マージ & デプロイ。各ステップは直接呼び出すスキルで、レビューステップでは専門の reviewer subagent 群がマージ前にすべての成果物を検査します。

### ATDD ダブルループ

atdd-kit は Freeman & Pryce の *[Growing Object-Oriented Software, Guided by Tests](https://www.amazon.co.jp/dp/0321503627)*（2009）のダブルループ TDD モデルを実装しています:

```
┌─ 外側ループ: 受け入れテスト ──────────────────────┐
│                                                      │
│  RED       失敗する E2E テストを書く                  │
│                                                      │
│    ┌─ 内側ループ: ユニットテスト ────────────────┐    │
│    │  RED       失敗するユニットテストを書く      │    │
│    │  GREEN     最小限の実装                      │    │
│    │  REFACTOR                     ↻ 繰り返し     │    │
│    └─────────────────────────────────────────────┘    │
│                                                      │
│  GREEN     受け入れテストが通る                       │
│  REFACTOR                                            │
└──────────────────────────────────────────────────────┘
```

影響を受けたもの:

- [ATDD by Example](https://www.amazon.co.jp/dp/0321784154)（Markus Gärtner, 2012）— ATDD の実践ガイド、"ATDD" という用語を広めた書籍
- [obra/superpowers](https://github.com/obra/superpowers) — プロセス強制パターン（Red Flags、`<HARD-GATE>`、Iron Laws）
- [BDD](https://cucumber.io/docs/bdd/)（Dan North）— Given/When/Then 受け入れ基準フォーマット


## クイックスタート

```bash
# 1. マーケットプレイス登録（初回のみ）
claude plugins marketplace add https://github.com/o3-ozono/atdd-kit.git

# 2. インストール（project scope 推奨）
claude plugins install atdd-kit --scope project
```

セットアップは初回セッション時に自動で行われます。`session-start` スキルがプラットフォーム（iOS, Web, Other）を自動検出し、インストールされる内容を表示して確認を求めます。手動でセットアップコマンド（`/atdd-kit:setup-github`、`/atdd-kit:setup-ios` 等）を実行することもできます。各 addon のインストール内容は [Getting Started — What Each Addon Installs](docs/guides/getting-started.md#what-each-addon-installs) を参照してください。

あとは作りたいものを伝えるだけ — atdd-kit が残りを処理します。

エンドツーエンドの walkthrough は [はじめに](docs/guides/getting-started.md) を参照してください。

## ワークフロー

```mermaid
flowchart LR
  bug["bug (auto)"] --> dr
  dr["defining-requirements"] --> us["extracting-user-stories"]
  us --> plan["writing-plan-and-tests"]
  plan --> atdd["running-atdd-cycle"]
  atdd --> review["reviewing-deliverables"]
  review --> ship["merging-and-deploying"]
```

### スキル

#### コアワークフロー（6 ステップ）

| ステップ | スキル | 概要 |
|---------|--------|------|
| 1 | **defining-requirements** | 対話で要件を探索し、受け入れ基準（Given/When/Then）を導出、PRD を作成 |
| 2 | **extracting-user-stories** | PRD からユーザーストーリーを導出 |
| 3 | **writing-plan-and-tests** | テストファーストの実装計画と受け入れテストを作成 |
| 4 | **running-atdd-cycle** | ATDD ダブルループを実行（外側: 受け入れテスト、内側: Unit テスト） |
| 5 | **reviewing-deliverables** | 全成果物（PRD/US/Plan/Code/AT）を専門 reviewer subagent で直列レビューし、単一の PASS/FAIL を出力 |
| 6 | **merging-and-deploying** | マージ → デプロイ → デプロイ後に regression 受け入れテストを re-run |

#### オンデマンド

| スキル | 概要 |
|--------|------|
| **writing-design-doc** | 設計探索 — トレードオフと代替案、判断を文書化する必要があるとき |
| **launching-preview** | プレビューをビルド・起動して手動確認 |
| **autopilot** | autopilot — flow skill をループして Issue の成果物を near-green まで自律収束。人間ゲートは要求承認（最初）・設計承認（ATDD 前）・merge（最後）の3点 |

#### 自動トリガー

| スキル | 概要 |
|--------|------|
| **bug** | バグ報告を自動検知し、トリアージパイプラインを開始 |
| **debugging** | エラー報告を自動検知し、根本原因調査を開始 |
| **skill-gate** | 関連スキルが直接作業の前に呼び出されることを保証 |
| **skill-fix** | セッション中に atdd-kit skill の不具合を報告。background subagent が現在の作業を中断せず修正 Issue を自動起票 |

#### ユーティリティ

| スキル | 概要 |
|--------|------|
| **session-start** | git 状態、未対応 PR/Issue を報告し、次のタスクを推奨 |
| **sim-pool** | iOS シミュレータプール管理（アドオン） |
| **ui-test-debugging** | flaky / 失敗する UI テストを診断（アドオン） |

### コマンド

| コマンド | 概要 |
|---------|------|
| `/atdd-kit:setup-github` | GitHub Issue/PR テンプレートとラベルのセットアップ |
| `/atdd-kit:setup-ci` | ベース + アドオンフラグメントから CI ワークフローを生成 |
| `/atdd-kit:setup-ios` | iOS アドオンの手動セットアップ（MCP サーバー、hooks、スクリプト） |
| `/atdd-kit:setup-web` | Web アドオンの手動セットアップ（プレースホルダー） |
| `/atdd-kit:maintenance` | 定期的なリポジトリ健全性チェック（行数・staleness 検出・Issue 起票） |
| `/atdd-kit:skill-fix` | atdd-kit skill 不具合報告フローを手動起動 |

## アーキテクチャ

### Reviewer Subagent

レビューステップ（`reviewing-deliverables`、Step 5）は 6 つの専門 reviewer subagent を直列に spawn します。各エージェントは隔離されたコンテキストを受け取り、1 つの成果物を固定の structural criteria で検査します。最後に aggregator が verdict を集約し、単一の PASS/FAIL を出力します。

| エージェント | レビュー対象 | criteria 数 |
|------------|------------|------------|
| **prd-reviewer** | PRD（`defining-requirements` の出力） | 10 |
| **us-reviewer** | ユーザーストーリー（`extracting-user-stories` の出力） | 7 |
| **plan-reviewer** | 実装計画 | 10 |
| **code-reviewer** | プロダクションコードの変更 | 10 |
| **at-reviewer** | 受け入れテスト | 10 |
| **final-reviewer** | 5 specialist の verdict を集約（計 47 criteria）→ PASS/FAIL | — |

### ラベルフロー

```
[Issue]  (ラベルなし) → in-progress → ready-to-go → in-progress
[PR]     ready-for-PR-review → needs-pr-revision（ループ） → マージ
```

詳細は [ワークフロー詳細](docs/workflow/workflow-detail.md) を参照。

## 設定

### iOS アドオン

iOS が検出された場合（または `/atdd-kit:setup-ios` で手動セットアップした場合）、アドオンが:
- `.mcp.json` に XcodeBuildMCP、ios-simulator、apple-docs、xcode を追加
- `sim-pool-guard.sh`、`lint-xcstrings.sh` をデプロイ
- PreToolUse hook でシミュレータの排他制御を設定

### 常時ロードルール

毎ターン読み込まれるのは約30行だけ（コンテキスト節約のため最小限）:
- Issue 駆動ワークフローの原則
- コミット規約（Conventional Commits）
- PR ルール（スカッシュマージ）

詳細なガイドは `docs/` にあり、スキルが必要なときに読み込みます。

## コントリビューション

完全な開発ガイドは [DEVELOPMENT.ja.md](DEVELOPMENT.ja.md) を参照してください。主要ルール:

- **バージョニング**: feature PR は必ず `.claude-plugin/plugin.json` のバージョンを上げ、`CHANGELOG.md` を更新する
- **ゼロ依存**: npm パッケージなし、外部サービスなし — 純粋な markdown + bash
- **言語**: LLM 向けファイルは英語のみ。ユーザー向け README/DEVELOPMENT は en/ja ペアで同期

## おすすめの併用ツール

| ツール | 用途 |
|--------|------|
| [swiftui-expert-skill](https://github.com/AvdLee/swiftui-expert-skill) | SwiftUI ベストプラクティス（iOS プロジェクト向け） |

## ライセンス

MIT
