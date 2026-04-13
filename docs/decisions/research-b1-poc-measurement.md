# Research B1: 最小 PoC + オーバーヘッド実測

調査日: 2026-04-13
Issue: #31 セッション統計収集の価値検討
担当: Researcher B1

---

## 1. PoC 構成

### Hook Script（最適版: bash + jq 1回呼び出し）

```bash
#!/bin/bash
# PostToolUse hook: tool イベントを JSONL に記録
# 配置場所: /path/to/hooks/stat-logger.sh

LOGFILE="${CLAUDE_STAT_LOGFILE:-/tmp/atdd-kit-stats/events.jsonl}"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

jq -c --arg ts "$TIMESTAMP" \
  '{ts: $ts, event: .hook_event_name, tool: .tool_name, sid: .session_id}' \
  >> "$LOGFILE"

exit 0
```

### Settings.json への組み込みイメージ（参考）

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "*",
        "hooks": [
          {
            "type": "command",
            "command": "/path/to/hooks/stat-logger.sh",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

### 実行コマンド例（単体テスト）

```bash
echo '{"session_id":"s1","hook_event_name":"PostToolUse","tool_name":"Bash"}' \
  | bash stat-logger.sh
```

---

## 2. 実測結果

### 2-A. 実行時間（macOS, bash + jq v2 実装）

| n | 合計時間 | 1イベントあたり |
|---|---------|----------------|
| 100 | 1989 ms | **19.9 ms** |
| 1000 | 15270 ms | **15.3 ms** |

**コスト内訳（n=100 平均）:**

| コンポーネント | コスト |
|--------------|-------|
| bash プロセス起動 | ~7.5 ms |
| date コマンド | ~2.9 ms |
| jq stdin 処理 + ファイル追記 | ~6.0 ms |
| **合計 (v2)** | **~16 ms/event** |

> 注: Linux 環境では bash 起動コストが 2-5ms 程度のため、合計 8-12 ms/event と推定される。

### 2-B. ログサイズ（ツール種別）

| ツール | JSONL 1行サイズ |
|--------|---------------|
| Bash | 93 bytes |
| Read | 93 bytes |
| Edit | 93 bytes |
| Agent | 94 bytes |
| **平均** | **~94 bytes** |

---

## 3. 1000 イベント/セッション相当の累計オーバーヘッド推定

| シナリオ | イベント数 | 累計実行時間 | ログ累計サイズ |
|---------|-----------|-------------|--------------|
| 小規模セッション | 50 | ~764 ms | ~4.6 KB |
| 中規模セッション | 200 | ~3,054 ms | ~18.4 KB |
| 大規模セッション | 1,000 | ~15,270 ms | **~92 KB** |

**LLM 推論時間との比較:**
- LLM 推論時間（代表値）: 3,000 ms/ターン
- 200 events のフック累計: ~3,054 ms
- LLM 時間に対するオーバーヘッド比: **約 0.5%**

---

## 4. 実装上の制約・注意点

### 4-1. PostToolUse は非ブロッキング
Claude Code の PostToolUse hook は tool 実行完了後に発火するが、Claude の次回応答生成を直接ブロックしない。そのためユーザー体感への影響は限定的と考えられる。

### 4-2. プロセス起動コストが支配的
macOS では bash 起動に ~7.5ms かかる。hook がイベントごとに新プロセスを立ち上げる設計のため、スクリプト内処理の最適化より「hook 呼び出し回数を減らす matcher 設定」の方が効果が高い。

例: `"matcher": "Bash|Write|Edit"` に絞ると呼び出し頻度を削減可能。

### 4-3. stdin に tool_response が含まれる可能性
PostToolUse では `tool_response` フィールドにツールの出力が含まれる。大きなファイルを Read した場合などは stdin サイズが数 KB 〜 数 MB になりうる。本 PoC では抽出するフィールドを最小化（tool_name、session_id のみ）しているため影響なし。

### 4-4. セッション ID の一意性
`session_id` フィールドは Claude Code が一意に付与する。セッション間の区別には使える。ただしセッションをまたぐ集計には別途セッション境界の検出が必要。

### 4-5. chezmoi / settings.json の制約
本リポの `.claude/settings.json` は chezmoi 管理下のため直接編集禁止。hook の実際の組み込みは別途 Issue 化して atdd-kit の設定テンプレートとして提供する方式が適切。

---

## 5. クリーンアップ実行確認

```bash
$ rm -rf /tmp/atdd-kit-poc/
$ ls /tmp/atdd-kit-poc/ 2>&1
ls: /tmp/atdd-kit-poc/: No such file or directory
```

---

## 6. 引用ソース

- Claude Code Hooks 公式ドキュメント: https://code.claude.com/docs/en/hooks
  - stdin の JSON フィールド仕様（session_id, hook_event_name, tool_name, tool_input, tool_response）
  - PostToolUse の decision control 仕様
