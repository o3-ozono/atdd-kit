# AC Review: QA Perspective

Issue #2: feat: session-start で Agent Teams 環境変数を自動設定する

## Overall Testability Assessment

既存の BATS テストパターン（マークダウンファイルの構造を grep で検証する方式）で AC1-AC5 のうち大部分は検証可能。ただし、AC1 と AC3 は **ランタイム動作**（settings.json の読み書き）を要求しており、純粋な構造テストでは不十分。session-start は SKILL.md（マークダウン指示書）であるため、「指示が正しく記述されているか」を構造テストで検証し、「実際に正しく動作するか」は手動検証またはスクリプトベースの統合テストで補完する必要がある。

## Per-AC Feedback

### AC1: 毎セッション自動設定

**テスト可能性:** 中
- SKILL.md に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` の設定手順が記述されていることは grep で検証可能
- SKILL.md に `settings.json` への書き込み指示があることは grep で検証可能
- 実際の JSON 操作の正確性（既存キーの保持、正しいネスト）はランタイムでしか検証できない

**境界条件:**
- `settings.json` に `env` キーが存在するが空オブジェクト `{}` の場合
- `env` に他のエントリ（例: `GH_TOKEN`）が既に存在する場合 -> AC2 でカバーされるが、AC1 の Then 節にも「他の既存設定を破壊しない」を明示すべき

**提案:** AC1 の Then 節を以下に修正:
> `.claude/settings.json` の `env` オブジェクトに `"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` が追加され、既存の `env` 以外のキー（hooks, attribution 等）が保持される

### AC2: 既存設定の保持

**テスト可能性:** 中
- 構造テスト: SKILL.md に「既存設定を変更しない」旨の指示が記述されていることを grep で検証可能
- ランタイム: 値が `"1"` 以外（例: `"true"`, `"0"`）の場合の挙動が未定義

**境界条件の不足:**
1. 値が `"1"` 以外の場合（例: `"true"`, `"0"`, `""`）-> 上書きするか保持するかを明示すべき
2. `env` に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` 以外のキーがある場合 -> 現在の記述「他の `env` エントリも保持される」でカバー済み

**提案:** Given を以下に拡充:
> `.claude/settings.json` に既に `env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が任意の値で設定済み

### AC3: settings.json 非存在時の新規作成

**テスト可能性:** 中
- 構造テスト: SKILL.md に「settings.json が存在しない場合は作成する」旨の指示が記述されていることを grep で検証可能
- ランタイム: 作成される JSON の構造が正しいか（最小限の有効な JSON か）は手動検証が必要

**境界条件の不足:**
1. `.claude/` ディレクトリ自体が存在しない場合 -> ディレクトリ作成まで必要か？ session-start は既に Claude Code セッション内で実行されるため `.claude/` は常に存在すると仮定してよいが、明示すべき
2. `settings.json` が存在するが空ファイル（0バイト）の場合 -> JSON パースエラーになる。この場合の挙動を定義すべき
3. `settings.json` が不正な JSON の場合 -> エラーハンドリングの定義が必要

**提案:** 以下のエッジケースを追加 AC または AC3 の注釈として追加:
- `.claude/` ディレクトリは Claude Code が管理するため存在を前提とする（前提条件として明記）
- 空ファイルまたは不正 JSON の場合は、新規作成と同じ扱いにする（既存内容を上書き）か、エラー報告して STOP するかを決定する

### AC4: autopilot Prerequisites Check のフォールバック案内

**テスト可能性:** 高
- 既存テスト `test_autopilot_agent_teams_setup.bats` と同じパターンで、`commands/autopilot.md` の該当セクションを grep で検証可能
- エラーメッセージの内容、STOP 指示の存在を検証可能

**フィードバック:**
- 現在の `commands/autopilot.md` の Prerequisites Check（L249）は既に「Agent Teams tools (TeamCreate, SendMessage) not found. Cannot proceed.」というメッセージで STOP するが、`settings.json` の `env` 設定を案内する記述がない
- AC4 はこのメッセージを拡充して設定方法を案内する変更
- メッセージ文言がテスト可能な形で確定していることは良い

**提案:** エラーメッセージに `.claude/settings.json` のパスを含めることを AC に明記。ユーザーがどのファイルを編集すべきか一意に特定できるようにする。

### AC5: Agent Teams 前提要件の明示

**テスト可能性:** 高
- `docs/workflow-detail.md` と `README.md`（または `README.ja.md`）に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` の記載があることを grep で検証可能
- 既存テストパターン（`test_doc_agent_teams_sync.bats`）と同じ手法

**フィードバック:**
- `docs/workflow-detail.md:69` に既に `Requires: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` の記載がある
- 「session-start が自動設定する」旨の記述が追加されるべきか？手動設定のドキュメントだけでは不十分
- 対象ドキュメントの範囲が未定義: `docs/workflow-detail.md` だけか、`README.md` にも記載するか

**提案:** AC5 の Then 節を具体化:
> `docs/workflow-detail.md` の autopilot セクションに `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` が必須要件として記載され、session-start による自動設定についても言及されている

## Missing Scenarios / Edge Cases

### 1. settings.json の `env` キーが存在しない場合（AC1 の亜種）
**Given:** `.claude/settings.json` が存在し、`env` キーがない（現在のこのリポジトリの状態）
**When:** session-start が実行される
**Then:** `env` オブジェクトが新規追加され、`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が含まれる

現在の AC1 は「`env.CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が未設定」としか書かれておらず、`env` キー自体がない場合を含むかどうかが曖昧。この状態はこのリポジトリの settings.json の実際の状態（`env` キーなし）と一致するため、最も一般的なケースとして明示すべき。

-> **推奨:** AC1 の Given を「`.claude/settings.json` に `env` キーが存在しない、または `env` 内に `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` が未設定」に修正

### 2. session-start のどのフェーズで実行するか
session-start の SKILL.md には Phase 0（リポジトリ更新）、Phase 1（情報収集）、Phase 2（状況評価）、Phase 3（レポート）がある。環境変数の設定をどのフェーズに組み込むかが AC に明示されていない。

-> **推奨:** AC1 に「Phase 0 の先頭で、リポジトリ更新の前に実行する」等のフェーズ指定を追加。環境変数設定は他のすべての操作に先行すべきであるため。

### 3. settings.json のパーミッション・ロックの問題
ファイルが読み取り専用の場合や、他のプロセスが書き込み中の場合のエラーハンドリングが未定義。

-> **推奨:** 低優先度。Claude Code のセッション内で settings.json のパーミッション問題が発生する可能性は極めて低い。AC に追加する必要はないが、実装時のエラーハンドリングとして考慮すべき。

### 4. autopilot 以外の Agent Teams ユースケース
AC4 は autopilot の Prerequisites Check に限定されている。将来、他のコマンドが Agent Teams を使用する場合にも同様のフォールバック案内が必要になるが、現時点では autopilot のみで十分。

## Suggested Test Approach

### 構造テスト（BATS）

```bash
# AC1: session-start SKILL.md に env 設定指示が存在
@test "AC1: session-start references CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' skills/session-start/SKILL.md
}

@test "AC1: session-start references settings.json env configuration" {
  grep -q 'settings.json' skills/session-start/SKILL.md
  grep -q 'env' skills/session-start/SKILL.md
}

# AC2: 既存設定保持の指示が存在
@test "AC2: session-start mentions preserving existing settings" {
  grep -qi 'preserv\|既存\|変更しない\|keep\|retain' skills/session-start/SKILL.md
}

# AC3: 新規作成の指示が存在
@test "AC3: session-start mentions creating settings.json if missing" {
  grep -qi 'creat\|作成\|not exist\|missing\|存在しない' skills/session-start/SKILL.md
}

# AC4: autopilot にフォールバック案内が存在
@test "AC4: autopilot Prerequisites Check mentions env setting guidance" {
  grep -A 20 "### Prerequisites Check" commands/autopilot.md \
    | grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS'
}

@test "AC4: autopilot Prerequisites Check mentions settings.json" {
  grep -A 20 "### Prerequisites Check" commands/autopilot.md \
    | grep -q 'settings.json'
}

# AC5: ドキュメントに前提要件が記載
@test "AC5: workflow-detail.md mentions CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS" {
  grep -q 'CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS' docs/workflow-detail.md
}
```

### 注意点
- 既存テストファイル `test_autopilot_agent_teams_setup.bats` の Session Initialization テスト（L215-217）が AC4 と重複する可能性あり。既存テストとの整合性を確認し、重複を避ける
- AC1-AC3 はスキルのマークダウン指示書に対する構造テストが主軸。ランタイム検証は手動で行うか、将来の eval フレームワークで対応する
