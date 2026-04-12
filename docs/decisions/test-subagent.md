# 調査結果: SendMessage 使用箇所 & エージェント tools リスト

## 1. commands/autopilot.md — Phase 2〜4 の SendMessage 使用箇所

### Phase 2: plan (L148〜155)

| 行番号 | 送信先 | 目的 |
|--------|--------|------|
| L150 | Developer | 実装戦略の作成指示（ファイル構成、実装順序、依存関係、技術リスク） |
| L153 | QA | テスト戦略の作成指示（AC ごとのテスト層選定、カバレッジ戦略、リグレッションリスク分析） |

### Plan Review Round (L160〜171)

| 行番号 | 送信先 | 目的 |
|--------|--------|------|
| L164 | Developer, QA（並列） | 統合 Plan のレビュー依頼（AC 整合性、ファイル構成妥当性、テスト層妥当性） |

### Phase 3: Implementation (L175〜184)

| 行番号 | 送信先 | 目的 |
|--------|--------|------|
| L179 | Developer | ATDD 実装指示（atdd-kit:atdd スキル呼び出し） |

### Phase 4: PR Review (L188〜197)

| 行番号 | 送信先 | 目的 |
|--------|--------|------|
| L191 | QA | PR レビュー指示（Spec compliance + Code quality） |

### 合計: 5 箇所（Developer 宛 3 回、QA 宛 3 回 ※ Plan Review Round は並列で各1回）

## 2. agents/ ディレクトリ — エージェント定義と tools リスト

### po.md (Product Owner)

- Read, Grep, Glob, Bash, Agent, Skill, TaskCreate, TaskUpdate, TaskList, SendMessage, TeamCreate, EnterWorktree, ExitWorktree, WebSearch, WebFetch
- **skills:** なし（frontmatter に skills フィールドなし）

### developer.md (Developer)

- Read, Write, Edit, Grep, Glob, Bash, Agent, Skill, TaskCreate, TaskUpdate, TaskList
- **skills:** atdd-kit:atdd, atdd-kit:verify, atdd-kit:debugging

### qa.md (QA)

- Read, Grep, Glob, Bash, Agent, WebSearch, WebFetch
- **skills:** なし（frontmatter に skills フィールドなし）

### researcher.md (Researcher)

- Read, Grep, Glob, Bash, WebSearch, WebFetch
- **skills:** なし（frontmatter に skills フィールドなし）

## 3. 特記事項

- SendMessage は PO (po.md) の tools リストにのみ含まれる。Developer, QA, Researcher には含まれない
- Developer のみ Write/Edit ツールを持ち、コード編集が可能
- QA と Researcher はコード編集ツール（Write/Edit）を持たず、読み取り専用
- PO のみ TeamCreate, EnterWorktree, ExitWorktree を持ち、チーム・ワークツリー管理を担当
