# Plan: autopilot / express 経路判定ルーティングステップ（#302）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

<!-- スコープ確認: 本 Issue は session-start 推奨レイヤ（Q1a）のみ。
     autopilot SKILL.md（279/280 行・第 3 回引き上げ不可）には触れない（Q1b は #304 へ descope）。
     ファイル touchpoint:
       - skills/session-start/SKILL.md（Recommended Tasks 表 + Task Recommendation Rules）
       - tests/test_session_start_task_recommendation.bats（構造アサーション追加）
       - .claude-plugin/plugin.json（version bump）
       - CHANGELOG.md（[Unreleased] エントリ）
       - skills/README.md は不要（新規 skill 追加・削除なし。session-start の本文変更のみ） -->

## Implementation

- [ ] `skills/session-start/SKILL.md` の `### Recommended Tasks` 出力テンプレート（L200-203 付近）の表に「推奨経路」列を追加し、`| Priority | Issue | Reason | 推奨経路 |` の 4 列構成にする
- [ ] verify: `### Recommended Tasks` 直下のコードフェンス内に `推奨経路` 列を含む 4 列のヘッダ行が存在する（grep で `推奨経路` がヒットし、表ヘッダのパイプ数が 4 列ぶん）

- [ ] `### Task Recommendation Rules` に **Step 3: Route recommendation（経路判定）** を追加し、各推奨 Issue へ `autopilot` / `express` のいずれかを付与する手順を定義する
- [ ] verify: `Task Recommendation Rules` セクション内に `Step 3` と `autopilot`・`express` の両トークンが出現する（grep）

- [ ] Step 3 に **express 適格信号** を定義する: 変更が docs/README/typo/コメント/gitignore/version-bump のみで挙動変更なし（express SKILL.md OK 基準と一致）
- [ ] verify: Step 3 内に express 適格信号の列挙（docs/README・typo・gitignore・version-bump のいずれかの語）が存在する（grep）

- [ ] Step 3 に **autopilot 信号** を定義する: コード/挙動変更・新機能・CI/hooks・依存追加・セキュリティ（express SKILL.md NG 基準と一致）
- [ ] verify: Step 3 内に autopilot 信号の列挙（新機能 / 挙動変更 / CI / 依存 / セキュリティ のいずれかの語）が存在する（grep）

- [ ] Step 3 に **判定主体＝ハイブリッド** を明記する: 決定的ガードレール（labels・キーワード）＋ Issue title/body への LLM 判断の併用
- [ ] verify: Step 3 内に「labels」「キーワード（keyword）」「LLM」の語が出現し、ハイブリッド方針が読み取れる（grep）

- [ ] Step 3 に **曖昧時フォールバック** を明記する: 判定が曖昧な Issue は安全側 `autopilot`（フルフロー）に倒す（express "when in doubt, full flow" と一致）
- [ ] verify: Step 3 内にフォールバック方針（曖昧 / when in doubt → autopilot）が文言として存在する（grep）

- [ ] Step 3 に **不変条件: 推奨のみ・auto-route しない** を明記する: ユーザーが最終的に経路を選択し、自動実行はしない
- [ ] verify: Step 3 内に「推奨のみ」「auto-route しない / 自動実行しない」の趣旨の文言が存在する（grep）

## Testing

- [ ] `tests/test_session_start_task_recommendation.bats` に AC1（推奨経路列）の構造アサーションを追加する
- [ ] verify: 新規 test が `### Recommended Tasks` テンプレート表に `推奨経路` 列があることを検証し、`bats tests/test_session_start_task_recommendation.bats` が green

- [ ] 同 bats に AC2（ハイブリッド判定 + express/autopilot 信号定義）の構造アサーションを追加する
- [ ] verify: 新規 test が Step 3 に express 適格信号・autopilot 信号・labels/keyword/LLM の併用が記述されていることを検証し green

- [ ] 同 bats に AC3（曖昧時フォールバック）と AC4（推奨のみ・auto-route しない不変条件）の構造アサーションを追加する
- [ ] verify: 新規 test が Step 3 のフォールバック文言と「auto-route しない」不変条件を検証し green

- [ ] 同 bats に AC5（express 既存トリガ温存）のリグレッションアサーションを追加する: `skills/express/SKILL.md` の APPROVAL-GATE / scope-overflow / OK・NG 基準が存続している
- [ ] verify: 新規 test が express SKILL.md に `APPROVAL-GATE` と scope-overflow 相当の語が残存することを検証し green

- [ ] 既存スイート全体の非退行を確認する
- [ ] verify: `bats tests/test_session_start_task_recommendation.bats tests/test_session_start_version.bats` および session-start 関連 bats 群が全 green（既存アサーションが壊れていない）

## Finishing

- [ ] `.claude-plugin/plugin.json` の version を minor bump する（新規 optional gate ＝ session-start 内の経路推奨ステップ追加。DEVELOPMENT.md「Adding a new optional gate within an existing skill is a minor bump」）
- [ ] verify: `plugin.json` の version が直前リリースより minor 上がっており、`scripts/check-plugin-version.sh` が通る

- [ ] `CHANGELOG.md` の `[Unreleased]`（または新バージョン見出し）に Added エントリを追加する（session-start に autopilot/express 経路推奨を追加）
- [ ] verify: `CHANGELOG.md` 最上位リリース見出しの version が `plugin.json` の version と一致し、本変更を説明するエントリが存在する

- [ ] ドキュメント整合性チェック（autopilot SKILL.md は本 Issue で不変であることの確認を含む）
- [ ] verify: `git diff --name-only` に `skills/autopilot/SKILL.md` が含まれない。関連ドキュメント（session-start, express の参照）が変更内容と整合
