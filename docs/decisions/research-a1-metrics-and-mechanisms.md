# Research A1 — メトリクス分類 + 収集手段評価

**作成日:** 2026-04-13
**対象 Issue:** #31 セッション統計収集価値の検討
**担当:** Researcher A1

---

## 1. 収集候補メトリクス一覧（カテゴリ別）

### A. ワークフロー実行メトリクス

| メトリクス | 説明 | 有用性 |
|-----------|------|--------|
| skill 発火回数（スキル別） | discover/plan/atdd/verify/ship/bug などの呼び出し数 | ワークフロー遵守率測定 |
| skill チェーン完走率 | discover→ship まで完走したセッション割合 | プロセス健全性指標 |
| agent 生成数（タイプ別） | Developer/QA/Reviewer/Researcher 等の spawn 数 | autopilot 利用状況 |
| command 使用頻度 | /atdd-kit:autopilot, /atdd-kit:auto-eval など | コマンド別活性度 |
| hook 発火回数（hookName 別） | PreToolUse:Bash, SessionStart 等のイベント数 | システム負荷把握 |

### B. セッション品質メトリクス

| メトリクス | 説明 | 有用性 |
|-----------|------|--------|
| セッション継続時間 | SessionStart → SessionEnd 間の elapsed | 1 Issue あたりの実工数推定 |
| ターン数（turn count） | user/assistant メッセージ交互回数 | セッション複雑度指標 |
| ツール呼び出し分布 | Bash/Read/Edit/Agent/Skill の比率 | ボトルネック特定 |
| hook 処理遅延（durationMs） | 各 hook の実行時間 | hook 性能監視 |

### C. エラー・リトライメトリクス

| メトリクス | 説明 | 有用性 |
|-----------|------|--------|
| エラー率（API エラー） | api_error イベント発生頻度 | 信頼性指標 |
| 平均リトライ回数 | attempt 属性値の分布 | 障害頻度把握 |
| hook ブロック回数 | permissionDecision=deny の件数 | ポリシー違反検出 |
| eval ガード発動回数 | eval-guard.sh が push をブロックした回数 | 品質ゲートの機能確認 |

### D. 使用量・コストメトリクス（Claude Code 組み込み済み）

| メトリクス | 説明 | 有用性 |
|-----------|------|--------|
| トークン使用量（input/output） | セッション・スキル別のトークン消費 | コスト配分 |
| コスト（USD） | API 呼び出しコスト | ROI 分析 |
| セッション数 | 期間中の起動数 | 採用度測定 |

### E. 役割稼働実績メトリクス（Issue #31 特記事項）

| メトリクス | 説明 | 有用性 |
|-----------|------|--------|
| agent タイプ別 spawn 実績 | po/developer/qa/tester/reviewer/researcher/writer の実績 | 未稼働役割の検出 |
| agent_transcript_path 生成数 | subagents/ 配下のファイル数 | エージェント実行の証跡 |

---

## 2. 収集機構ごとの評価

### 2-1. Hooks（PreToolUse / PostToolUse / SessionStart / Stop 等）

**取得できるもの:**
- ツール名（tool_name）、ツール引数（tool_input）、実行結果（tool_response）
- hook_event_name, session_id, transcript_path, cwd
- SubagentStart/SubagentStop で agent_id, agent_type を取得可能
- Skill ツール呼び出しを PostToolUse でキャプチャ → skill_name の取得が可能
  - `OTEL_LOG_TOOL_DETAILS=1` 設定で tool_parameters.skill_name が露出
- Agent ツール呼び出しを PostToolUse でキャプチャ → subagent_type の取得が可能
- Stop フックで SessionEnd 相当のイベントを検知可能

**取得できないもの:**
- セッション全体の集計値（hooks は逐次発火、集計は自前実装が必要）
- ユーザープロンプト本文（デフォルトでは prompt_length のみ）
- skill チェーンの遷移グラフ（hook 同士の因果関係は context で推論が必要）

**セットアップコスト:** 低〜中
- hooks.json に matcher を追記するだけで動作開始
- atdd-kit の既存 hooks.json (SessionStart, PreToolUse:Bash) を拡張するだけ
- 出力は `/dev/stderr` または専用ログファイルに append するシェルスクリプトで完結

**動作コスト:** 低
- 既存の eval-guard.sh で Bash 呼び出し 1 回あたり ~40-50ms
- 全ツールにマッチする hook を追加した場合は処理量に比例してオーバーヘッドが増加

**ソース:** hooks.json L1-17、eval-guard.sh（`hooks/eval-guard.sh`）、Claude Code Hooks ドキュメント（https://code.claude.com/docs/en/hooks）

---

### 2-2. Session Transcripts（JSONL ファイル解析）

**取得できるもの:**
- すべての tool_use（ツール名、引数）を `assistant` エントリの `content[]` から抽出可能
- Skill ツールの `input.skill` フィールド = スキル名（実測で確認済み）
- Agent ツールの `input.subagent_type` = エージェントタイプ（実測で確認済み）
- `user` エントリの `content` 中の `<command-name>` タグ = slash command（実測で確認済み）
- セッション時間（最初/最後のエントリの timestamp 差）
- ターン数（user/assistant エントリ数）
- attachment エントリ（hook 実行結果）から hook 発火回数・durationMs を取得可能
- subagents/ ディレクトリに agent-{id}.jsonl + agent-{id}.meta.json が生成される

**取得できないもの:**
- リアルタイム（セッション終了後の事後解析のみ）
- トークン数・コストは transcript には含まれない（OTel 経由が必要）

**セットアップコスト:** 低（解析スクリプトの作成のみ）
- `~/.claude/projects/<project>/` 配下を glob して python3 スクリプトで集計可能
- atdd-kit の zero-dependencies 制約に適合（外部パッケージ不要）
- subagent の transcript は `transcript_path` フィールドで親から参照可能

**動作コスト:** 低（オフライン処理）
- セッション中は一切オーバーヘッドなし
- Stop フックで事後解析スクリプトを起動する設計が最適

**ソース:** 実測（`~/.claude/projects/.../42eb0f20-...jsonl` の解析結果）

---

### 2-3. OpenTelemetry（OTel）

**取得できるもの（`CLAUDE_CODE_ENABLE_TELEMETRY=1` 必須）:**
- `claude_code.session.count` — セッション開始回数
- `claude_code.token.usage` — トークン消費（type: input/output/cacheRead/cacheCreation）
- `claude_code.cost.usage` — コスト（USD）
- `claude_code.lines_of_code.count` — コード変更行数
- `claude_code.commit.count` / `claude_code.pull_request.count` — PR/commit 数
- `claude_code.active_time.total` — アクティブ時間
- Events: user_prompt, tool_result（duration_ms, success, tool_name）, api_request, api_error

**Skill/Agent 固有データの取得条件:**
- `OTEL_LOG_TOOL_DETAILS=1` を設定した場合にのみ `tool_parameters.skill_name` が露出
- Skill ツールの skill_name は OTel ドキュメントで明示的に言及されている

**取得できないもの:**
- atdd-kit 独自のワークフロー状態（discover 完了、plan 承認済み等）
- hook 発火回数（OTel は Claude Code 標準メトリクスのみ）

**セットアップコスト:** 高
- OTel Collector（Prometheus/ClickHouse 等）の構築が必要
- atdd-kit の zero-dependencies 制約と相容れない外部インフラが必要
- 個人開発環境では console exporter なら外部インフラ不要（ただし永続化できない）

**動作コスト:** 中
- バックグラウンドで定期エクスポート（デフォルト: metrics 60s, logs 5s）
- 影響は軽微だが常時動作する

**ソース:** https://code.claude.com/docs/en/monitoring-usage（全文取得済み）

---

### 2-4. 外部スクリプト（Stop フック起動 / 定期バッチ）

**取得できるもの:**
- Transcript JSONL を事後解析して任意のメトリクスを計算可能
- GitHub API（`gh api`）と組み合わせて Issue/PR 進捗との相関分析も可能

**取得できないもの:**
- リアルタイムデータ（解析は Stop 後）

**セットアップコスト:** 低〜中
- hooks.json の Stop イベントに bash スクリプトを登録するだけ
- スクリプト自体は bash + python3 で実装（zero-dependencies 適合）

**動作コスト:** 低
- セッション終了後の 1 回処理のみ

---

## 3. 機構 × メトリクスのマトリクス

| メトリクス | Hooks | Transcript 解析 | OTel | 外部スクリプト |
|-----------|-------|-----------------|------|----------------|
| **skill 発火回数** | △ PostToolUse でリアルタイム取得可（OTEL_LOG_TOOL_DETAILS 不要） | ◎ input.skill から直接取得可 | ○ OTEL_LOG_TOOL_DETAILS=1 で取得可 | ◎ Transcript 解析と同等 |
| **agent 生成数** | ○ SubagentStart フックで取得可 | ◎ input.subagent_type から取得可 | △ tool_result の tool_name=Agent のみ | ◎ Transcript 解析と同等 |
| **command 使用頻度** | ✗ slash command はフック対象外 | ◎ user エントリの command-name タグから取得可 | ✗ | ◎ Transcript 解析と同等 |
| **tool 呼び出し分布** | ◎ PreToolUse/PostToolUse で逐次取得 | ◎ assistant エントリから集計可 | ◎ tool_result イベントで取得可 | ◎ Transcript 解析と同等 |
| **セッション時間** | △ SessionStart+Stop で計算可 | ◎ timestamp 差で計算可 | ○ active_time.total で取得可（積算） | ◎ Transcript 解析と同等 |
| **エラー率** | △ PostToolUseFailure で取得可 | ○ tool_response の success フィールドから取得可 | ◎ api_error イベントで取得可 | ◎ Transcript 解析と同等 |
| **hook 発火回数** | ◎ 自身が hook なので内部カウンタに書き込める | ◎ attachment エントリから取得可 | ✗ | ◎ Transcript 解析と同等 |
| **hook 処理遅延** | △ hook 内で計測は可能だが非標準 | ◎ attachment.durationMs から取得可 | ✗ | ◎ Transcript 解析と同等 |
| **トークン数・コスト** | ✗ | ✗ | ◎ 公式メトリクスとして提供 | ✗（OTel が必要） |
| **agent 稼働実績（役割別）** | ○ SubagentStart/Stop で agent_type を取得 | ◎ subagents/ の meta.json で agentType を確認可 | △ tool_result での間接的な取得のみ | ◎ Transcript 解析と同等 |
| **PR/commit 数** | ✗ | ✗ | ◎ 公式メトリクスとして提供 | △ gh api で補完可能 |

**凡例:** ◎ = 容易・直接取得可、○ = 条件付きで取得可、△ = 工夫が必要、✗ = 取得困難/不可

---

## 4. 優先度ランキングと根拠

### 推奨アプローチ: Transcript 解析 + Stop フック（段階 1）

**優先度 1: Stop フック × Transcript 解析スクリプト**

- **根拠:**
  1. セットアップコストが最も低い（bash スクリプト + hooks.json の Stop エントリ追加のみ）
  2. atdd-kit の zero-dependencies 制約に完全適合
  3. skill 名、agent タイプ、command 名、tool 分布をすべて 1 つのスクリプトで取得可能（実測で確認済み）
  4. 既存の `hooks/eval-guard.sh` の実装パターンをそのまま流用できる
  5. リアルタイム性は不要（Issue 単位での分析が目的）

- **実装イメージ:**
  ```bash
  # hooks.json に追加
  "Stop": [{ "type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/session-stats" }]
  ```
  ```bash
  # hooks/session-stats
  INPUT=$(cat)
  TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path')
  python3 "${CLAUDE_PLUGIN_ROOT}/scripts/analyze-session.py" "$TRANSCRIPT" >> "${CLAUDE_PLUGIN_DATA}/session-stats.jsonl"
  ```

- **取得可能なメトリクス:** skill 発火回数、agent 生成数、command 使用頻度、tool 分布、セッション時間、ターン数、hook 発火回数・遅延

**優先度 2: SubagentStart/Stop フック**

- agent 稼働実績のリアルタイム記録に追加（transcript 解析の補完）
- 特に「定義済みだが使われていない役割（例: po agent）の稼働実績を統計で検出」というニーズに直接対応
- `agent_type` フィールドが SubagentStart/Stop でのみ正式に提供される

**優先度 3: OTel（将来対応）**

- トークン数・コスト分析が必要になった場合に導入
- 外部 Collector の構築コストが高いため、現時点では `console` exporter で PoC を試す程度に留める
- `OTEL_LOG_TOOL_DETAILS=1` を設定するだけで skill_name が付与されるため、OTel 導入時のデータ品質は高い

### 見送り推奨: OTel のフル導入

- **根拠:** zero-dependencies 制約、外部インフラコスト、個人開発規模では過剰
- ただし Claude Code Enterprise 環境では管理者設定で一括配布が可能なため、チーム規模が拡大した場合は再評価

---

## 5. 引用ソース

| ソース | URL / ファイルパス | 参照内容 |
|-------|-------------------|---------|
| Claude Code Hooks ドキュメント | https://code.claude.com/docs/en/hooks | イベントタイプ 24 種、input/output JSON スキーマ、環境変数 |
| Claude Code Monitoring ドキュメント | https://code.claude.com/docs/en/monitoring-usage | OTel メトリクス一覧、Events スキーマ、OTEL_LOG_TOOL_DETAILS |
| atdd-kit hooks.json | `hooks/hooks.json` L1-17 | 既存 SessionStart フック設定 |
| atdd-kit eval-guard.sh | `hooks/eval-guard.sh` | PreToolUse hook の実装パターン |
| atdd-kit session-start hook | `hooks/session-start` | SessionStart フックの出力フォーマット |
| atdd-kit DEVELOPMENT.md | `DEVELOPMENT.md` | zero-dependencies 制約、arch 設計ルール |
| Transcript 実測（skill 発火） | `~/.claude/projects/-Users-hiroaki-ozono-github-com-o3-ozono-atdd-kit/42eb0f20-...jsonl` | Skill ツールの input.skill 構造、Agent ツールの input.subagent_type 構造 |
| Transcript 実測（command） | 同上 | user エントリの `<command-name>` タグ |
| Transcript 実測（attachment） | 同上 | hook_success の durationMs フィールド |
| Transcript 実測（subagent meta） | `~/.claude/projects/.../subagents/agent-*.meta.json` | agentType フィールド |
| simonw/claude-code-transcripts | https://github.com/simonw/claude-code-transcripts | JSONL format の事例 |
| Claude Code sessions（kentgigger） | https://kentgigger.com/posts/claude-code-conversation-history | セッション管理の事例 |

---

## まとめ（B2 統合担当向け）

1. **収集価値は高い** — skill/agent/command の実行状況は transcript から事後解析で取得可能であることを実測で確認
2. **最小コスト実現手段は Transcript 解析 + Stop フック** — bash + python3 のみで atdd-kit の zero-dependencies 制約を守りながら実装可能
3. **役割稼働実績の検出** — subagents/ の meta.json に agentType が記録されており、未稼働役割の検出に直接使える
4. **OTel はトークン/コスト分析に特化** — skill/agent 固有メトリクスは transcript 解析の方が容易かつ制約適合
5. **プライバシー上の懸念は低い** — transcript はローカルファイルのみを解析し、外部送信なし
