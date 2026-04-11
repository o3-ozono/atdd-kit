[English](DEVELOPMENT.md)

# 開発ガイド

## 絶対に守るルール

すべてのコントリビューションで必須。例外なし。

### バージョニング

feature PR を main にマージする際は、**必ず**バージョンとチェンジログを更新する:

1. `.claude-plugin/plugin.json` のバージョンを上げる（[SemVer](https://semver.org/)）
2. `CHANGELOG.md` にエントリを追加する（[Keep a Changelog](https://keepachangelog.com/)）
3. 両方の更新を feature と同じ PR に含める — 後から別コミットにしない

これを怠るとプラグイン更新通知システム（`scripts/check-plugin-version.sh`）が壊れる。

### 言語

- **LLM 向けファイル**（skills, rules, docs, commands, agents）: 英語のみ。`*.ja.md` 翻訳は不要。
- **ユーザー向けファイル**（README, DEVELOPMENT）: `.md` と `.ja.md` の両方を同期して維持。
- **Issue/PR テンプレート**: `templates/` 内の `en/` と `ja/` の両バリアントを維持。

### ゼロ依存

atdd-kit は**外部依存ゼロ**を設計方針としている。npm パッケージなし、外部サービスなし。純粋な markdown + bash スクリプトのみ。プラグインは自己完結型で、ソース管理で共有可能、依存関係のインストールなしで動作する。

### 常時ロードルールのトークン予算

`rules/atdd-kit.md` は**毎ターン**ロードされる。**40行以下**に抑えること。それ以外は `docs/` に移動する。

### ディレクトリ README

各トップレベルディレクトリ（`skills/`、`commands/`、`hooks/`、`rules/`、`scripts/`、`templates/`、`tests/`）には `README.md` がある。これらのディレクトリでファイルを追加・削除・変更した場合、**同じ PR 内で対応する README.md も更新すること**。

## アーキテクチャ判断

### Skills と Commands の使い分け

- **Skill**: `description` による自動検知、またはワークフローチェーン（discover → plan → atdd → verify → ship）の一部
- **Command**: ユーザーが明示的に呼び出す（`/atdd-kit:*`）

### スキルチェーン

```
bug/issue (auto) → ideate (optional) → discover → plan → [承認ゲート] → atdd → verify → ship
```

- `issue` は `ideate` にチェーンし、`ideate` は `discover` にチェーンする（ideate はスキップ可能）
- スキルは前方にチェーンする（discover → plan、atdd → verify → ship）
- コマンドはチェーンのエントリポイントのみを呼ぶ（autopilot (Dev) → atdd）
- 7つのコアスキルすべてに session-start ガード

### アドオンシステム

プラットフォーム固有の機能は `addons/<platform>/` に配置。各アドオンは `addon.yml` マニフェストで MCP サーバー、フック、デプロイファイル、CI フラグメントを宣言する。詳細は `addons/README.md` を参照。

### エージェント

autopilot のロール定義は `agents/` に配置。各エージェントは YAML フロントマター（`name`、`description`、`model`、`tools`、`skills`）とシステムプロンプト本文を持つ。詳細は `agents/README.md` を参照。

### スキル description フィールドのルール

スキル YAML の `description` フィールドには**トリガー条件のみ**を書く。ワークフローの要約を書いてはいけない。description にワークフローを要約すると、エージェントがスキル本文を読まずに description だけで行動する。

**NG**（ワークフロー要約）:
```
description: "ATDD 実装 -- E2E テスト作成、次にユニットテスト、最後に実装コード"
```

**OK**（トリガー条件のみ）:
```
description: "Use when implementing a ready-to-implement Issue."
```

### スキル変更には eval エビデンスが必須

スキルは**振る舞いを形作るコード**であり、散文ではない。SKILL.md の変更には:

1. 変更前後で eval を実行する
2. before/after の pass_rate を比較して提示する
3. pass_rate が 10% 以上低下した場合、その変更はブロックされる
4. Red Flags テーブルや注意深く調整された強制コンテンツを eval エビデンスなしに変更してはいけない

## スキル Eval

スキルには [skill-creator](https://github.com/anthropics/claude-code/tree/main/plugins/skill-creator) の eval フレームワークを使ったリグレッションテストを設定できる。

### スキルに eval を追加する

1. `skills/<skill-name>/evals/evals.json` にテストケースとアサーションを作成（skill-creator 互換フォーマット）
2. `/atdd-kit:auto-eval --all` を実行して初回ベースラインを確立
3. ベースラインは `skills/<skill-name>/evals/baseline.json` に保存される

### eval の実行タイミング

- **PR レビュー時**: `autopilot (QA)` が `skills/*/SKILL.md` の変更を検知し、`auto-eval` を自動トリガー
- **定期実行**: `/atdd-kit:autopilot eval`（30分間隔）
- **手動**: `/atdd-kit:auto-eval` または `/atdd-kit:auto-eval --all`

### リグレッション検出

pass_rate がベースラインから 10% 以上低下した場合、リグレッションを報告し PR マージをブロックする。

## リリースプロセス

1. `.claude-plugin/plugin.json` のバージョンを更新する
2. `CHANGELOG.md` を更新する
3. README.md と README.ja.md が同期していることを確認する
4. タグ付け: `git tag vX.Y.Z`
5. プッシュ: `git push origin main --tags`

## リポジトリ構成

```
atdd-kit/
├── .claude-plugin/   # プラグインメタデータ（plugin.json — バージョンの唯一のソース）
├── skills/           # スキル定義（SKILL.md + オプションの evals/）
│   ├── atdd/
│   ├── bug/
│   ├── debugging/
│   ├── discover/
│   ├── ideate/
│   ├── issue/
│   ├── plan/
│   ├── session-start/
│   ├── ship/
│   ├── sim-pool/        # iOS アドオンスキル（フレームワーク検出のため skills/ に配置）
│   ├── skill-gate/
│   ├── ui-test-debugging/ # iOS アドオンスキル
│   └── verify/
├── agents/           # エージェントロール定義（PO, Developer, QA, Researcher）
├── addons/           # プラットフォーム固有アドオンパッケージ（ios/, web/）
│   └── ios/          # iOS アドオン（addon.yml, scripts/, ci/, tests/）
├── commands/         # ユーザー明示呼び出しコマンド（/atdd-kit:*）
├── rules/            # 常時ロードルール（40行予算、毎ターンロード）
├── docs/             # オンデマンド参照ドキュメント（スキルが必要時にロード）
├── hooks/            # Claude Code hooks（session-start ブートストラップ）
├── scripts/          # Bash/Node ユーティリティ（バージョンチェック）
├── templates/        # 静的テンプレート（issue/, pr/, ci/）— テンプレート展開なし
└── tests/            # BATS テストスイート（コアテスト。アドオンテストは addons/*/tests/）
```

各トップレベルディレクトリには内容を説明する `README.md` がある。

## スキルの仕組み

### SKILL.md の構造

各スキルは `skills/<name>/SKILL.md` に配置され、2つのパートで構成される:

1. **YAML フロントマター** — `name` と `description` フィールド
2. **Markdown 本文** — ステップ、チェックリスト、ゲート、強制ルール

```yaml
---
name: discover
description: "Explore requirements through dialogue and derive ACs (Given/When/Then)."
---

## Session Start Check (required)
...
# discover Skill -- Requirements Exploration
...
```

`description` フィールドは自動トリガーの挙動を制御する。**トリガー条件のみ**を書く — ワークフローの要約は書かない（上記「アーキテクチャ判断」参照）。

### 自動トリガーと手動スキル

| 種別 | トリガー | 例 |
|------|---------|-----|
| **自動トリガー** | `description` からユーザーの意図を Claude が検知 | issue、bug、ideate、debugging、skill-gate |
| **ワークフローチェーン** | 前のスキルが完了時にチェーン | discover → plan → atdd → verify → ship |
| **手動** | ユーザーが明示的に呼び出し | session-start、sim-pool |

### スキルチェーン

```
bug/issue (auto) → ideate (optional) → discover → plan → [承認ゲート] → atdd → verify → ship
```

- `issue` は `ideate` にチェーンし、`ideate` は `discover` にチェーンする（ideate はスキップ可能）
- 各スキルは完了時に次のスキルにチェーンする（discover → plan、atdd → verify → ship）
- plan と atdd の間の承認ゲートは人間の承認（または autopilot の AC Review Round）が必要
- すべてのコアスキルには Session Start Check があり、未実行なら `session-start` を先に実行する
- 状態ゲート付きスキル（atdd、verify、ship）は処理開始前に Issue ラベルをチェックする

### Eval

スキルには `skills/<name>/evals/` にリグレッションテストを設定できる。詳細は上記「スキル Eval」セクションを参照。

## 新しいスキルを追加する

1. **ディレクトリを作成**: `skills/<name>/`
2. **`SKILL.md` を作成** — YAML フロントマター（`name`、`description`）とステップバイステップの手順を記述
3. **eval を追加**（推奨）: `skills/<name>/evals/evals.json` を作成し、`/atdd-kit:auto-eval --all` でベースラインを確立
4. **`skills/README.md` を更新** — 新しいスキルをディレクトリ一覧に追加
5. **`CHANGELOG.md` を更新** — 新しいスキルのエントリを追加
6. **バージョンを更新** — `.claude-plugin/plugin.json`

### チェックリスト

- [ ] `description` にはトリガー条件のみ記載（ワークフロー要約は書かない）
- [ ] コアワークフローの一部なら Session Start Check を含める
- [ ] `skills/README.md` を更新済み
- [ ] `CHANGELOG.md` にエントリ追加済み
- [ ] `.claude-plugin/plugin.json` のバージョンを更新済み
