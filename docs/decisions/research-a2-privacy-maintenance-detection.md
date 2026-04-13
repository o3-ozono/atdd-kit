# Research A2: プライバシー・保守負荷・未稼働役割検出

Issue #31 デスクリサーチ — Researcher A2 担当

作成日: 2026-04-13

---

## 1. プライバシーリスク評価

### 1.1 hooks が受け取る情報

Claude Code の hooks は全イベントで以下の共通フィールドを stdin 経由で受け取る（公式ドキュメント確認済み）:

```json
{
  "session_id": "abc123",
  "transcript_path": "/Users/.../.claude/projects/.../00893aaf.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default|plan|auto|...",
  "hook_event_name": "EventName"
}
```

加えて、イベント種別ごとに以下の追加フィールドが含まれる:

| イベント | 追加フィールド（機密リスクあり） |
|----------|--------------------------------|
| PreToolUse / PostToolUse | `tool_name`, `tool_input`（コマンド全文・ファイル内容・URLを含む） |
| PostToolUse | `tool_response`（ツール出力全文） |
| UserPromptSubmit | `prompt`（ユーザー入力全文） |
| SubagentStop | `agent_transcript_path`, `last_assistant_message` |

### 1.2 transcripts に含まれる情報

`transcript_path` は JSONL 形式の会話全文ログへのパスであり、hooks は自由に読み取れる。
JSONL には以下が含まれる:

- ユーザーとの会話全文（設計議論・要件定義・機密要件を含む可能性）
- ツール呼び出し内容（コマンド・ファイルパス・内容）
- ツール応答（ファイル内容・コマンド出力・API レスポンス）

### 1.3 情報種別 × リスクレベル × 緩和策

| 情報種別 | 具体例 | リスクレベル | 緩和策 |
|----------|--------|-------------|--------|
| Bash コマンド全文 | `curl -H "Authorization: Bearer <token>"` などにトークンが混入 | **HIGH** | hooks でのコマンドロギングを最小限に留め、Bash の `command` フィールドのみ記録し認証情報をマスク |
| Write/Edit のファイル内容 | APIキー・シークレット・個人情報を含む設定ファイルの書き込み内容 | **HIGH** | `tool_input.content` / `old_string` / `new_string` は記録しない。ファイルパスとサイズのみ記録 |
| UserPromptSubmit の `prompt` | ユーザーが入力した要件・設計案・個人情報 | **HIGH** | prompt フィールドは一切収集しない |
| transcript_path | JSONL 全文読み取り可能 | **HIGH** | hooks から transcript を読まない。パスのみ使用するなら記録してもよいが内容は対象外 |
| WebFetch / WebSearch の query/URL | 機密ドメインへのアクセス・検索クエリが外部に漏洩 | **MEDIUM** | URL のドメインのみ記録、パスは除外 |
| AskUserQuestion の responses | フォーム回答・選択内容が残留 | **MEDIUM** | 回答選択肢のラベルのみ記録、自由入力は除外 |
| session_id / cwd / permission_mode | ワークディレクトリや権限モードが漏洩 | **LOW** | 記録してもよいが、cwd はリポジトリ名以上は絞る |
| tool_name | 利用ツール名（機密情報なし） | **LOW** | 記録可 |
| SubagentStop の last_assistant_message | エージェント出力全文 | **MEDIUM** | 記録しない。イベント発生とエージェント種別のみ記録 |

### 1.4 機密が混入しやすいケース

1. **Bash コマンドへの認証情報埋め込み**: `gh api` コールや `curl` に `GH_TOKEN`・パスワードが引数として渡るケース
2. **設定ファイルの書き込み**: `.claude/settings.local.json` (GH_TOKEN 含む) を Write ツールで編集するケース
3. **エージェント間の SendMessage**: 機密設計情報が `tool_input` 経由で hook に流れ込むケース
4. **UserPromptSubmit フック**: ユーザーが要件をそのまま書いたプロンプトを収集するケース（Issue #31 のユースケース）

### 1.5 推奨緩和策まとめ

- **最小収集の原則**: `tool_name`・`hook_event_name`・`session_id`・イベント発生日時のみを基本セットとする
- **Bash は特別扱い**: コマンド全文は収集せず「Bash ツール呼び出しが発生した」という事実のみ記録
- **opt-out 機能**: プロジェクトの `.claude/workflow-config.yml` に `telemetry: false` を設定すると収集しない
- **ローカル限定**: 統計はリモート送信せず、ローカルファイル (`$XDG_CACHE_HOME/atdd-kit/stats/`) に保存
- **ハッシュ化不要**: 秘匿すべきは「収集しない」で対処。ハッシュ化は後で分析できなくなる一方で不完全な保護
- **公式ドキュメントに sanitization/redaction の仕組みなし**: Claude Code 側でのマスク機能は存在しないため、hook 実装側で対処必須

---

## 2. 保守負荷の見積もり

### 2.1 Claude Code の hooks/events 仕様変更への追随コスト

**現状の仕様進化リスク:**

- Claude Code は 2025 年以降、SubagentStart/SubagentStop・TeamCreate・WorktreeCreate など新イベントを継続追加している
- イベントペイロードのフィールド追加（例: `agent_id`, `agent_type`, `agent_transcript_path`）はドキュメント改訂で随時発生
- フィールド廃止・リネームは破壊的変更につながる

**追随コスト例:**
- `SubagentStop` の `agent_type` フィールドが変更された場合、未稼働役割検出ロジックの修正が必要（後述 §3）
- `UserPromptSubmit` イベントは現在 `exit 2` でブロック可能だが、仕様が変わるとフック動作が変わる
- イベント名の追加ではなく統廃合が発生した場合（例: PreToolUse/PostToolUse の統合）は全統計スキーマの再設計が必要

**定性的評価:** 中程度。仕様変更の頻度は高くないが、追加されるたびに対応が必要。テストがないため追随コストの検知が遅れやすい。

### 2.2 ログフォーマット進化（schema versioning）

- 統計ファイルを JSONL や SQLite で保存する場合、フィールド追加・削除のたびにスキーマバージョンアップが必要
- `schema_version` フィールドをログの先頭に付与する設計が最低限必要
- 旧バージョンのログを分析スクリプトが読めなくなるリスク（後方互換性の問題）

**作業例:**
- v1 → v2 移行時: マイグレーションスクリプトの作成 + 既存ログの変換
- 集計クエリ（jq / awk）の更新
- ドキュメント (`docs/`) のスキーマ定義更新

### 2.3 ローテーション・容量管理・分析スクリプトの保守

| 保守項目 | 具体的作業 | 頻度 |
|---------|-----------|------|
| ログローテーション | セッションごとに JSONL を 1 ファイル生成 → 月次で圧縮・削除スクリプト追加 | 初期実装 + 仕様変更ごと |
| 容量管理 | キャッシュディレクトリ (`$XDG_CACHE_HOME/atdd-kit/`) の上限設定（例: 100MB） | 設計時のみ |
| 分析スクリプト | `jq` / `bash` で集計クエリ作成・維持 | フィールド変更ごと |
| CI での eval-guard.sh との競合回避 | 新 hook を追加するたびに既存 hook との実行順序・入力形式の整合確認 | hook 追加ごと |
| テスト | BATS テストで hook の入出力を検証 | hook 変更ごと |

### 2.4 総合評価

セッション統計収集機能を追加した場合の追加保守負荷:

- **hooks 実装**: 1〜2 本のシェルスクリプト（PreToolUse / PostToolUse + SessionStart/SessionEnd）
- **初期実装工数**: 中（スキーマ設計・プライバシー制御・ローテーション含めると 3〜5 日相当）
- **継続保守**: 低〜中（Claude Code API 変更時の追随、半年に 1 回程度の修正想定）
- **最大リスク**: スキーマとクエリの乖離。分析スクリプトがサイレントに壊れてもテストなしでは検知できない

---

## 3. 未稼働役割検出可能性（Issue #45 関連）

### 3.1 検出対象

`agents/po.md` を含む全エージェント定義（developer, qa, tester, reviewer, researcher, writer）について「定義済みだが未稼働」かを検出する。

現時点での定義済みエージェント（`agents/` 以下）:
| エージェント | autopilot での使用 | 単独呼び出し |
|-------------|-------------------|-------------|
| po.md | team-lead として spawn される | `claude --agent po` |
| developer.md | Phase 3 (development/bug) | `@developer` |
| qa.md | AC Review Round / Plan Review / Phase 3 | `@qa` |
| tester.md | Phase 1/3 (bug) | `@tester` |
| reviewer.md | Phase 4 (variable count) | `@reviewer` |
| researcher.md | Phase 3 (research, variable count) | `@researcher` |
| writer.md | Phase 3 (documentation) | `@writer` |

**Issue #45 の問題**: autopilot フローに po.md が team-lead として組み込まれているが、実際のセッションで POエージェントが spawn されているか確認できていない。

### 3.2 検出可能なシグナル

統計収集が実装されていた場合、以下のシグナルで未稼働役割を検出できる:

| シグナル | 対応 hook イベント | 検出できること |
|---------|-----------------|--------------|
| TeamCreate 実行有無 | PreToolUse (tool_name: "TeamCreate") | autopilot セッションが開始したかどうか |
| SubagentStart の agent_type | SubagentStart イベント | どのエージェントが spawn されたか |
| SubagentStop の agent_type | SubagentStop イベント | どのエージェントが完了したか |
| SendMessage の `to` フィールド | PreToolUse (tool_name: "SendMessage") | PO からどのエージェントにメッセージが送られたか |
| Agent ツールの subagent_type | PreToolUse (tool_name: "Agent") | Explore サブエージェント利用状況 |

**注意**: `SendMessage` の `tool_input` には `to` フィールド（宛先エージェント名）が含まれるが、`message` フィールドの内容は収集しない（プライバシーリスク HIGH）。

### 3.3 検出ロジックの設計例

```bash
# 集計スクリプト例（jq）
# 入力: JSONL 形式の統計ログ
# 出力: エージェント別 spawn 回数

jq -s '
  .[]
  | select(.hook_event_name == "SubagentStart")
  | .agent_type
' stats/*.jsonl \
| sort | uniq -c | sort -rn
```

**判定例:**
```
  42 developer
  38 qa
  10 reviewer
   5 tester
   3 researcher
   1 writer
   0 po        ← 0回ならStaticに "未稼働" と判定
```

**しきい値設計:**

| 条件 | 判定 |
|------|------|
| 直近 30 日で agent_type の出現回数 = 0 | 未稼働（廃止候補） |
| 直近 30 日で出現回数 < 3 | 稀稼働（再設計候補） |
| 出現回数 > 0 かつ TeamCreate と共起なし | 単独呼び出しのみ（autopilot では使われていない） |

### 3.4 PO エージェントの現状分析（静的解析）

セッション統計なしでも静的解析で判断できる情報:

1. **参照経路**: `commands/autopilot.md` が `po.md` を team-lead として参照している。`skills/` や他 `commands/` からの直接参照はなし
2. **単独起動**: `agents/README.md` に `claude --agent po` の例示があるが、実セッションでの使用証拠なし
3. **skills から呼ばれていない**: `grep -r "po" skills/` で `skills/` 内に PO を直接呼び出すコードなし
4. **Issue #45 の結論**: autopilot 実行時にのみ PO が team-lead として spawn される設計。autopilot が実行されない通常ワークフローでは PO は一切使われない

### 3.5 限界・偽陽性リスク

| 限界 | 詳細 |
|------|------|
| エージェント名の変動 | `agent_type` は変数（CustomAgent の名前は変わりうる）。固定名の po/developer/qa 以外は追跡困難 |
| 「短期稼働」vs「未稼働」の区別 | research タスクのような頻度が低いタスクでは researcher が「0回」に見えても廃止候補ではない |
| autopilot 未使用環境 | autopilot を一度も実行していないプロジェクトでは全エージェントが「0回」になる（偽陽性） |
| セッションまたがりの集計 | worktree ごとにセッションが分かれるため、集計期間の設定次第で過少カウントが起きる |
| TeamCreate なしの単独利用 | `@developer` 形式の単独呼び出しは `agent_type` が異なる可能性（検証が必要） |

**偽陽性リスクの緩和:**
- しきい値判定に「TaskType との組み合わせ」を加える（例: research タスクが 0 件なら researcher=0 は正常）
- 集計期間を柔軟に設定（30日 / 90日 / 全期間）
- 「未稼働」フラグは自動廃止につなげず、Issue 起票のトリガーに留める

---

## 4. 総合評価と推奨

### 収集するべきフィールド（最小セット）

セッション統計を実装するならば、以下のフィールドのみを収集することを推奨する:

```json
{
  "schema_version": 1,
  "session_id": "abc123",
  "hook_event_name": "SubagentStart",
  "timestamp": "2026-04-13T10:00:00Z",
  "tool_name": "TeamCreate",
  "agent_type": "developer"
}
```

収集しないフィールド: `tool_input`（コマンド・ファイル内容）、`tool_response`、`prompt`、`transcript_path`（パスは使わない）

### 推奨: 段階的導入

| フェーズ | 内容 | コスト |
|---------|------|--------|
| Phase 1（今すぐできる） | 静的解析（grep/コード読み）で未稼働役割を特定 → Issue #45 で po.md の扱いを決定 | 0 |
| Phase 2（低コスト） | SubagentStart/Stop のみ記録するシンプルな hook を 1 本追加。フィールドは最小セット | 低 |
| Phase 3（中コスト） | 分析スクリプト + ローテーション + opt-out 機能の整備 | 中 |

### 「やらない」判断の根拠になりうるもの

- Claude Code 側でのプライバシー制御（sanitization）が一切ないため、実装ミスによる機密漏洩リスクが常に存在する
- 現状の保守リソースが限られており、スキーマ追随コストが「管理されないまま」になるリスクが高い
- Issue #45（PO 稼働確認）は静的解析だけで十分判断できる（統計収集は必須ではない）

---

## 5. 引用ソース

| ソース | 内容 |
|--------|------|
| Claude Code 公式 hooks ドキュメント (code.claude.com/docs/en/hooks) | hook イベント一覧・ペイロードスキーマ・セキュリティ注意事項 |
| `hooks/hooks.json` (本リポジトリ) | 現在の plugin 配布 hook 定義（SessionStart のみ） |
| `hooks/eval-guard.sh` (本リポジトリ) | PreToolUse hook の実装例・`tool_input.command` の取り出し方 |
| `hooks/session-start` (本リポジトリ) | SessionStart hook の実装例 |
| `commands/autopilot.md` (本リポジトリ) | PO エージェントの参照経路・Agent Composition Table |
| `agents/po.md`, `agents/README.md` (本リポジトリ) | PO エージェントの定義と利用方法 |
| `gh issue view 45` | Issue #45 PO エージェント稼働確認の Scope・Completion Criteria |
| `gh issue view 31` | Issue #31 セッション統計収集の Scope・除外事項 |
| `docs/superpowers-architecture-learnings.md` (本リポジトリ) | JSONL transcript 解析パターン（Item #17）の設計メモ |
