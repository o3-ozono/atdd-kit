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

#### スキル rename = semver-breaking

出荷済みスキル（`skills/<name>/SKILL.md` の `name` セグメント、または呼び出し ID `atdd-kit:<name>`）の**リネーム／削除は breaking change** であり、**major** バージョン bump が必要。理由: `tests/fixtures/headless/*.scenario.json` および skill chain を参照する下流自動化が skill ID にピン留めされているため、rename は replay fixture とユーザー自動化を silently 壊す。rename が必要な場合:

1. major バージョンを上げる
2. `tests/fixtures/headless/` 配下の影響 fixture を全て再録画する（`docs/guides/headless-skill-testing.md` 参照）
3. CHANGELOG の "### Changed" / "### Removed" セクションに `BREAKING CHANGE:` プレフィックス付きで明示的に記載する

新規スキル追加や既存スキル内の optional gate 追加は **minor** bump。

### 言語

- **LLM 向けファイル**（skills, rules, docs, commands, agents）: 英語のみ。`*.ja.md` 翻訳は不要。
- **ユーザー向けファイル**（README, DEVELOPMENT）: `.md` と `.ja.md` の両方を同期して維持。
- **Issue/PR テンプレート**: `templates/` 内の `en/` と `ja/` の両バリアントを維持。

#### 引き締めガイドライン

LLM 向けファイルを編集する際は、以下のルールを適用してトークン数を最小化する（指示内容は損なわない）:

1. 自明なコマンド説明を削除する（例: `` `git status` でステータスを確認 `` → `` `git status` ``）。
2. 冗長な見出し括弧を短縮する（例: "リポジトリ更新（最優先、単独実行）" → "リポジトリ更新（単独実行）"）。
3. 周囲の構造で既に表現されている繰り返し文を削除する。
4. 冠詞（"the"、"a"）は残す — 可読性を損なう極端な削除はしない。
5. 散文をリストやテーブルに変換する。
6. 丁寧な指示（"You MUST/should/need to"）を命令形に変換する（"Verify X"、"Run Y"）。
7. エラー処理を 1 文に圧縮する。

保護要素: YAML フロントマターフィールド、コードブロックの内容、XML ガードタグブロック（`<HARD-GATE>`、`<SUBAGENT-STOP>`）— 構造は保持し内部テキストは BATS 検証済み文字列を変更しない範囲で引き締め可、ステップ番号、`If X:` 条件構造。

### ゼロ依存

atdd-kit は**外部依存ゼロ**を設計方針としている。npm パッケージなし、外部サービスなし。純粋な markdown + bash スクリプトのみ。プラグインは自己完結型で、ソース管理で共有可能、依存関係のインストールなしで動作する。

### 常時ロードルールのトークン予算

`rules/atdd-kit.md` は**毎ターン**ロードされる。**60行以下**に抑えること。それ以外は `docs/` に移動する。

> 予算は v1.0 移行（#179）中に 6-step Workflow テーブル収容のため 40 行から 60 行に引き上げた。レガシーヒントを刈り取りながら、再度 40 行を目標に圧縮すること。

### ディレクトリ README

各トップレベルディレクトリ（`skills/`、`commands/`、`hooks/`、`rules/`、`scripts/`、`templates/`、`tests/`）には `README.md` がある。これらのディレクトリでファイルを追加・削除・変更した場合、**同じ PR 内で対応する README.md も更新すること**。

## アーキテクチャ判断

### Skills と Commands の使い分け

- **Skill**: `description` による自動検知、または 6-step ワークフローチェーン（defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying）の一部
- **Command**: ユーザーが明示的に呼び出す（`/atdd-kit:*`）

### スキルチェーン

```
bug (auto) → defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

- `bug` はバグ報告で自動トリガーされ、`defining-requirements` にルートする
- 各ステップは完了時に次のステップへチェーンする
- `skill-gate` は直接作業の前に該当ステップのスキルが呼び出されることを保証する
- すべてのコアスキルには Session Start Check があり、未実行なら `session-start` を先に実行する

### アドオンシステム

プラットフォーム固有の機能は `addons/<platform>/` に配置。各アドオンは `addon.yml` マニフェストで MCP サーバー、フック、デプロイファイル、CI フラグメントを宣言する。詳細は `addons/README.md` を参照。

### エージェント

`agents/` は将来のカスタム agent 置き場（現在 agent 定義ファイルなし）。レビューは `reviewing-deliverables` スキル（Step 5）の動的レンズパネル × 並列 Workflow（#234）が担い、固定 agent ファイルは使用しない。impl / review サブエージェントのモデルポリシーは `agents/README.md` を参照。

### スキル description フィールドのルール

スキル YAML の `description` フィールドには**トリガー条件のみ**を書く。ワークフローの要約を書いてはいけない。description にワークフローを要約すると、エージェントがスキル本文を読まずに description だけで行動する。

**NG**（ワークフロー要約）:
```
description: "ATDD 実装 -- E2E テスト作成、次にユニットテスト、最後に実装コード"
```

**OK**（トリガー条件のみ）:
```
description: "Use when implementing a ready-to-go Issue."
```

### スキル変更にはテストエビデンスが必須

スキルは**振る舞いを形作るコード**であり、散文ではない。SKILL.md の変更には:

1. 変更前後でスキルの BATS テスト（`tests/test_<skill>_skill.bats`）を実行する
2. スイートを green に保つ — スキル編集はピン留めされた構造アサーションを壊してはいけない
3. Rationalization テーブル、`<HARD-GATE>` ブロック、注意深く調整された強制コンテンツを、それを正当化する対応テスト更新なしに削除してはいけない

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
├── skills/           # スキル定義（SKILL.md）
│   ├── bug/
│   ├── debugging/
│   ├── defining-requirements/
│   ├── extracting-user-stories/
│   ├── launching-preview/
│   ├── merging-and-deploying/
│   ├── reviewing-deliverables/
│   ├── running-atdd-cycle/
│   ├── session-start/
│   ├── sim-pool/             # iOS アドオンスキル（フレームワーク検出のため skills/ に配置）
│   ├── skill-fix/
│   ├── skill-gate/
│   ├── ui-test-debugging/    # iOS アドオンスキル
│   ├── writing-design-doc/
│   └── writing-plan-and-tests/
├── agents/           # カスタム agent 定義（現在 README のみ。レビューは動的パネルが担う — #234）
├── addons/           # プラットフォーム固有アドオンパッケージ（ios/, web/）
│   └── ios/          # iOS アドオン（addon.yml, scripts/, ci/, tests/）
├── commands/         # ユーザー明示呼び出しコマンド（/atdd-kit:*）
├── rules/            # 常時ロードルール（60行予算、毎ターンロード）
├── docs/             # オンデマンド参照ドキュメント（スキルが必要時にロード）
│   ├── guides/       # ハウツーガイドとリファレンス（commit-guide, review-guide 等）
│   ├── methodology/  # 方法論詳細（atdd-guide, bug-fix-process）
│   ├── product/      # プロダクト戦略（product-goal, impact-map, story-map, roadmap）
│   ├── specs/        # User Story + AC スペックファイル（Living Documentation、Issue クローズ後も永続）
│   └── workflow/     # ワークフローリファレンス（workflow-detail, issue-ready-flow）
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
name: defining-requirements
description: "Explore requirements through dialogue and derive ACs (Given/When/Then)."
---

## Session Start Check (required)
...
# defining-requirements Skill -- Requirements Exploration
...
```

`description` フィールドは自動トリガーの挙動を制御する。**トリガー条件のみ**を書く — ワークフローの要約は書かない（上記「アーキテクチャ判断」参照）。

### 自動トリガーと手動スキル

| 種別 | トリガー | 例 |
|------|---------|-----|
| **自動トリガー** | `description` からユーザーの意図を Claude が検知 | bug、debugging、skill-gate、skill-fix |
| **ワークフローチェーン** | 前のスキルが完了時にチェーン | defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying |
| **手動** | ユーザーが明示的に呼び出し | session-start、sim-pool |

### スキルチェーン

```
bug (auto) → defining-requirements → extracting-user-stories → writing-plan-and-tests → running-atdd-cycle → reviewing-deliverables → merging-and-deploying
```

- `bug` はバグ報告で自動トリガーされ、`defining-requirements` にルートする
- 各スキルは完了時に次のスキルにチェーンする
- すべてのコアスキルには Session Start Check があり、未実行なら `session-start` を先に実行する
- 状態ゲート付きスキル（running-atdd-cycle、merging-and-deploying）は処理開始前に Issue ラベルをチェックする

## 新しいスキルを追加する

1. **ディレクトリを作成**: `skills/<name>/`
2. **`SKILL.md` を作成** — YAML フロントマター（`name`、`description`）とステップバイステップの手順を記述
3. **BATS テストを追加**（推奨）: `tests/test_<name>_skill.bats` を作成し、スキルの構造アサーションをピン留めする
4. **`skills/README.md` を更新** — 新しいスキルをディレクトリ一覧に追加
5. **`CHANGELOG.md` を更新** — 新しいスキルのエントリを追加
6. **バージョンを更新** — `.claude-plugin/plugin.json`

### チェックリスト

- [ ] `description` にはトリガー条件のみ記載（ワークフロー要約は書かない）
- [ ] コアワークフローの一部なら Session Start Check を含める
- [ ] `skills/README.md` を更新済み
- [ ] `CHANGELOG.md` にエントリ追加済み
- [ ] `.claude-plugin/plugin.json` のバージョンを更新済み
