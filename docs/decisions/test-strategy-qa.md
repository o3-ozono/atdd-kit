# Test Strategy: QA

Issue #1: bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している

## 1. AC ごとのテスト層選定

| AC | テスト層 | 理由 |
|----|---------|------|
| AC1: 静的検証 — CLONE_REQUIRED_TOOLS に 3 ツール含有 | 構造テスト (BATS/sed+grep) | スクリプトファイルの配列内容を直接検証。`test_sim_failclosed_guard.bats` AC3.12-AC3.13 と同じ確立済みパターン。 |
| AC2: 否定テスト — READONLY_TOOLS に含まれていない | 構造テスト (BATS/sed+grep) | READONLY に誤配置されるとクローン確保なしで ALLOW されるため、否定検証が必須。AC3.12 と同じパターン。 |
| AC3: 初回呼び出し — DENY + session_set_defaults 案内 | 動的テスト (BATS/run_guard+jq) | guard スクリプトを実際に実行し、DENY レスポンスと additionalContext の内容を検証。`test_sim_auto_inject.bats` AC5.1 と同じパターン。 |
| AC4: 2 回目以降 — ALLOW | 動的テスト (BATS/run_guard+jq) | session_set_defaults 実行後の ALLOW を検証。`test_sim_auto_inject.bats` AC5.2 と同じパターン。 |
| AC5: 既存ツールの動作維持 | 既存テストスイート全パス | 新規テスト不要。既存の 9 テストファイルが全てパスすることで回帰がないことを保証。 |

**設計判断:** このバグの根本原因は「配列への追加漏れ」である。静的検証（AC1/AC2）で根本原因を直接テストし、動的検証（AC3/AC4）でルーティングの正しさを検証する二層構造とする。AC5 は既存テストスイートに完全に委譲し、新規テストでの二重メンテナンスを避ける。

## 2. テストファイル構成

### 新規作成

| ファイル | 目的 |
|---------|------|
| `addons/ios/tests/test_sim_clone_required_variants.bats` | AC1-AC4 の全テストケースを格納 |

### 命名規則

既存の sim 関連テストファイルの命名パターンに従う:
- `test_sim_failclosed_guard.bats` — fail-closed ガード
- `test_sim_ephemeral_clone.bats` — エフェメラルクローン
- `test_sim_auto_inject.bats` — 自動インジェクション
- `test_sim_persist_block.bats` — persist ブロック
- **`test_sim_clone_required_variants.bats`** — CLONE_REQUIRED バリアントツール (new)

### 既存テストとの関係

```
addons/ios/tests/
  test_sim_clone_required_variants.bats  # [NEW] AC1-AC4
  test_sim_failclosed_guard.bats         # [既存] AC5 で利用（回帰検証）
  test_sim_ephemeral_clone.bats          # [既存] AC5 で利用（回帰検証）
  test_sim_auto_inject.bats              # [既存] AC5 で利用（回帰検証）
  test_sim_persist_block.bats            # [既存] AC5 で利用（回帰検証）
  test_sim_golden_init.bats              # [既存] AC5 で利用（回帰検証）
  test_sim_golden_set_fallback.bats      # [既存] AC5 で利用（回帰検証）
  test_sim_init_guidance.bats            # [既存] AC5 で利用（回帰検証）
  test_sim_orphan_cleanup.bats           # [既存] AC5 で利用（回帰検証）
  test_sim_pool_docs.bats               # [既存] AC5 で利用（回帰検証）
```

## 3. テストケース一覧

### テストファイル: `addons/ios/tests/test_sim_clone_required_variants.bats`

全テストケースの詳細設計:

```
# =================================================================
# AC1: 静的検証 — CLONE_REQUIRED_TOOLS に 3 ツールが含まれる
# =================================================================
# パターン: sed -n + grep（test_sim_failclosed_guard.bats AC3.12 と同一）

@test "AC1.1: CLONE_REQUIRED_TOOLS contains build_sim"
  入力: なし（スクリプトファイルの静的解析）
  手法: sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD" | grep -q
  期待: "mcp__XcodeBuildMCP__build_sim" が見つかる

@test "AC1.2: CLONE_REQUIRED_TOOLS contains build_run_sim"
  入力: なし
  手法: 同上
  期待: "mcp__XcodeBuildMCP__build_run_sim" が見つかる

@test "AC1.3: CLONE_REQUIRED_TOOLS contains test_sim"
  入力: なし
  手法: 同上
  期待: "mcp__XcodeBuildMCP__test_sim" が見つかる

# =================================================================
# AC2: 否定テスト — READONLY_TOOLS に含まれていない
# =================================================================
# パターン: ! grep -q（test_sim_failclosed_guard.bats AC3.12 と同一）

@test "AC2.1: build_sim is NOT in READONLY_TOOLS"
  入力: なし
  手法: sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD" | ! grep -q
  期待: "mcp__XcodeBuildMCP__build_sim" が見つからない

@test "AC2.2: build_run_sim is NOT in READONLY_TOOLS"
  入力: なし
  手法: 同上
  期待: "mcp__XcodeBuildMCP__build_run_sim" が見つからない

@test "AC2.3: test_sim is NOT in READONLY_TOOLS"
  入力: なし
  手法: 同上
  期待: "mcp__XcodeBuildMCP__test_sim" が見つからない

# =================================================================
# AC3: 初回呼び出し — DENY + session_set_defaults 案内
# =================================================================
# パターン: run_guard + jq（test_sim_auto_inject.bats AC5.1 と同一）

@test "AC3.1: first build_sim call is DENY with session_set_defaults instruction"
  入力: tool_name="mcp__XcodeBuildMCP__build_sim", tool_input={}, session_id="test-session-variants"
  手法: run_guard -> jq で permissionDecision と additionalContext を検証
  期待: permissionDecision == "deny"
         additionalContext に "session_set_defaults" を含む
         additionalContext に clone 名（"atdd-kit-" プレフィクス）を含む

@test "AC3.2: first build_run_sim call is DENY with session_set_defaults instruction"
  入力: tool_name="mcp__XcodeBuildMCP__build_run_sim", tool_input={}, session_id="test-session-variants-brs"
  手法: 同上（セッション ID を分離して独立テスト）
  期待: 同上

@test "AC3.3: first test_sim call is DENY with session_set_defaults instruction"
  入力: tool_name="mcp__XcodeBuildMCP__test_sim", tool_input={}, session_id="test-session-variants-ts"
  手法: 同上（セッション ID を分離して独立テスト）
  期待: 同上

# =================================================================
# AC4: 2 回目以降 — ALLOW（session_set_defaults 実行後）
# =================================================================
# パターン: run_guard 連続呼び出し + jq（test_sim_auto_inject.bats AC5.2 と同一）

@test "AC4.1: build_sim is ALLOW after session_set_defaults"
  入力:
    Step 1: run_guard "mcp__XcodeBuildMCP__build_sim" (初回 DENY、setup_flag 生成)
    Step 2: run_guard "mcp__XcodeBuildMCP__session_set_defaults" (ALLOW、setup_flag touch)
    Step 3: run_guard "mcp__XcodeBuildMCP__build_sim" (2 回目)
  手法: Step 3 の結果を jq で検証
  期待: permissionDecision == "allow"

@test "AC4.2: build_run_sim is ALLOW after session_set_defaults"
  入力: 同パターン（tool_name を build_run_sim に変更、セッション ID 分離）
  期待: permissionDecision == "allow"

@test "AC4.3: test_sim is ALLOW after session_set_defaults"
  入力: 同パターン（tool_name を test_sim に変更、セッション ID 分離）
  期待: permissionDecision == "allow"
```

### テスト数サマリー

| カテゴリ | テスト数 |
|---------|---------|
| AC1: 静的検証 CLONE_REQUIRED 含有 | 3 |
| AC2: 否定テスト READONLY 非含有 | 3 |
| AC3: 初回 DENY + 案内 | 3 |
| AC4: session_set_defaults 後 ALLOW | 3 |
| AC5: 既存テストスイート全パス | 0（新規テスト不要） |
| **合計** | **12** |

## 4. カバレッジ戦略

### 静的検証 + 動的検証の二層構造

```
レイヤー 1: 静的検証（AC1 + AC2）
  目的: 根本原因の直接検証 — 配列に正しいエントリがあること
  手法: sed + grep でスクリプトファイルを解析
  利点: ルーティングロジック変更に強い、実行環境不要
  限界: 実行時のルーティング動作は検証できない

レイヤー 2: 動的検証（AC3 + AC4）
  目的: エンドツーエンドの動作検証 — ツール呼び出しが正しく処理されること
  手法: mock xcrun 環境で guard スクリプトを実行
  利点: main() のルーティング、handle_xcodebuildmcp のロジックを通しで検証
  限界: mock 環境のため、実際の simctl 動作は検証できない

レイヤー 3: 回帰検証（AC5）
  目的: 既存機能の非破壊保証
  手法: 既存テストスイート（9 ファイル）の全パス
  利点: 新規テストのメンテナンスコストゼロ
  限界: 新ツール追加による副作用のうち、既存テストがカバーしていないパスは検出できない
```

### カバレッジマトリクス

| コードパス | AC1 | AC2 | AC3 | AC4 | AC5 |
|-----------|-----|-----|-----|-----|-----|
| `CLONE_REQUIRED_TOOLS` 配列定義 (L51-79) | x | | | | |
| `READONLY_TOOLS` 配列定義 (L33-48) | | x | | | |
| `main()` READONLY 分岐 (L383-386) | | | | | x |
| `main()` CLONE_REQUIRED 分岐 (L394-404) | | | x | x | x |
| `main()` fail-closed DENY (L407-408) | | | | | x |
| `handle_xcodebuildmcp()` setup_flag なし (L333-339) | | | x | | |
| `handle_xcodebuildmcp()` setup_flag あり (L341) | | | | x | |
| `handle_xcodebuildmcp()` session_set_defaults (L320-324) | | | | x | x |
| `in_array()` (L97-105) | | | x | x | x |

## 5. リグレッションリスク分析

### CLONE_REQUIRED_TOOLS 追加の影響範囲

変更は `CLONE_REQUIRED_TOOLS` 配列への 3 行追加のみ。以下の既存コードパスに影響する:

| コードパス | 影響 | リスク |
|-----------|------|--------|
| `in_array()` (L97-105) | 配列サイズが 26 -> 29 に増加。線形探索のため微小なパフォーマンス影響のみ。 | なし |
| `main()` CLONE_REQUIRED 分岐 (L394) | 新ツール名が `in_array` にマッチするようになる。既存ツール名のマッチには影響なし。 | なし |
| `main()` fail-closed DENY (L407) | 新ツール名が CLONE_REQUIRED で処理されるため、fail-closed に到達しなくなる。これが修正の本質。 | なし（意図通り） |
| `handle_xcodebuildmcp()` (L303-342) | `mcp__XcodeBuildMCP__build_sim` 等が `case mcp__XcodeBuildMCP__*` にマッチし、このハンドラに入る。既存ツール（build, test, run）の処理には影響なし。 | なし |

### 既存テストスイートへの影響

| テストファイル | 影響の有無 | 理由 |
|--------------|----------|------|
| `test_sim_failclosed_guard.bats` | なし | READONLY テスト（AC3.4-AC3.8）は既存ツール名を使用。fail-closed テスト（AC3.9-AC3.11）は `unknown_new_tool` を使用。配列メンバーシップテスト（AC3.12-AC3.15）は `session_set_defaults` と `session_use_defaults_profile` を検証。いずれも新ツール追加の影響なし。 |
| `test_sim_auto_inject.bats` | なし | `mcp__XcodeBuildMCP__build` と `mcp__ios-simulator__tap` を使用。新ツール名に言及していない。 |
| `test_sim_ephemeral_clone.bats` | なし | `mcp__ios-simulator__tap` と `mcp__ios-simulator__take_screenshot` を使用。 |
| `test_sim_persist_block.bats` | なし | `session_set_defaults` と `session_use_defaults_profile` を使用。 |
| `test_sim_golden_init.bats` | なし | ゴールデンイメージの初期化をテスト。CLONE_REQUIRED_TOOLS とは無関係。 |
| `test_sim_golden_set_fallback.bats` | なし | Device Set のフォールバックをテスト。 |
| `test_sim_init_guidance.bats` | なし | addon.yml のガイダンスをテスト。 |
| `test_sim_orphan_cleanup.bats` | なし | 孤児クローンのクリーンアップをテスト。 |
| `test_sim_pool_docs.bats` | なし | ドキュメントの構造をテスト。 |

**結論:** 既存テストスイートへの影響はゼロ。全テストが修正前後で同一の結果を返す。

## 6. テストの setup/teardown

### 流用元: `test_sim_auto_inject.bats`

AC3/AC4 の動的テストには `test_sim_auto_inject.bats` の setup/teardown をそのまま流用する。理由:

1. mock `xcrun` が clone, boot, list devices のすべてのケースをカバー
2. ゴールデンマーカー事前作成（`touch "$SIM_MARKER_DIR/atdd-kit-golden-initialized-iOS-18-0"`）で golden init をスキップ
3. `run_guard` ヘルパーが `jq -n` を使い、JSON エスケープが正確

### setup() の内容

```bash
setup() {
  export SIM_SESSION_DIR="${BATS_TMPDIR}/sim-sessions-$$"
  export SIM_MARKER_DIR="${BATS_TMPDIR}/sim-markers-$$"
  export SIM_GOLDEN_NAME="iPhone 17 Pro"
  GUARD="addons/ios/scripts/sim-pool-guard.sh"

  mkdir -p "$SIM_SESSION_DIR" "$SIM_MARKER_DIR"
  # ゴールデンマーカー事前作成 -> ensure_golden の初回ブート処理をスキップ
  touch "$SIM_MARKER_DIR/atdd-kit-golden-initialized-iOS-18-0"

  # mock xcrun: simctl の応答をスタブ
  export MOCK_BIN="${BATS_TMPDIR}/mock-bin-$$"
  mkdir -p "$MOCK_BIN"
  cat > "$MOCK_BIN/xcrun" <<'MOCK'
#!/bin/bash
case "$*" in
  "simctl list devices available -j")
    echo '{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-0":[{"name":"iPhone 17 Pro","udid":"GOLDEN-UUID-1234","state":"Shutdown","isAvailable":true,"runtime":"com.apple.CoreSimulator.SimRuntime.iOS-18-0"}]}}'
    ;;
  simctl\ clone\ *) echo "CLONE-UUID-5678" ;;
  simctl\ boot\ *|simctl\ shutdown\ *|simctl\ bootstatus\ *) ;;
  "simctl list devices -j") echo '{"devices":{}}' ;;
  simctl\ delete\ *) ;;
  *) ;;
esac
MOCK
  chmod +x "$MOCK_BIN/xcrun"
  export PATH="$MOCK_BIN:$PATH"
}
```

**ポイント:**
- `SIM_SESSION_DIR` と `SIM_MARKER_DIR` を `BATS_TMPDIR` + `$$`（PID）でテストごとに分離
- mock `xcrun` は `MOCK_BIN` ディレクトリに配置し、`PATH` の先頭に追加
- `simctl list devices -j`（孤児クリーンアップ用）は空のデバイスリストを返す -> stale clone 処理をスキップ

### teardown() の内容

```bash
teardown() {
  rm -rf "$SIM_SESSION_DIR" "$SIM_MARKER_DIR" "$MOCK_BIN"
}
```

### run_guard ヘルパー

```bash
run_guard() {
  local tool_name="$1"
  local tool_input="${2:-\{\}}"
  local session_id="${3:-test-session-variants}"
  local json
  json=$(jq -n --arg tn "$tool_name" --argjson ti "$tool_input" --arg sid "$session_id" \
    '{tool_name: $tn, tool_input: $ti, session_id: $sid}')
  echo "$json" | bash "$GUARD"
}
```

**ポイント:**
- `jq -n` を使用し JSON エスケープを保証（`test_sim_auto_inject.bats` と同じ）
- デフォルト session_id は `"test-session-variants"` とし、既存テストの session_id と衝突しない
- AC3 の 3 テストは各ツールで異なる session_id を使用し、setup_flag の状態が干渉しないようにする

### AC3/AC4 の session_id 分離設計

AC3 と AC4 は setup_flag の状態に依存するため、テスト間の独立性が重要:

| テスト | session_id | 理由 |
|--------|-----------|------|
| AC3.1 (build_sim) | `test-session-variants-bs` | 独立した setup_flag を持つ |
| AC3.2 (build_run_sim) | `test-session-variants-brs` | 独立した setup_flag を持つ |
| AC3.3 (test_sim) | `test-session-variants-ts` | 独立した setup_flag を持つ |
| AC4.1 (build_sim) | `test-session-variants-bs4` | AC3.1 とは別のセッション |
| AC4.2 (build_run_sim) | `test-session-variants-brs4` | AC3.2 とは別のセッション |
| AC4.3 (test_sim) | `test-session-variants-ts4` | AC3.3 とは別のセッション |

**注意:** BATS は各 `@test` の前に `setup()` を実行するため、`SIM_SESSION_DIR` はテストごとに再作成される。ただし `$$` は同一 BATS プロセス内で不変なので、同一ディレクトリが再利用される。安全のため、各テストで異なる session_id を使用する。

### AC1/AC2 の静的テスト

AC1/AC2 は setup/teardown に依存しない。`$GUARD` 変数のみを使用し、スクリプトファイルを直接 sed+grep で解析する。ただし setup() で `GUARD` 変数が設定されるため、setup() は必要。

## 7. 注意すべき仕様: setup_flag の自動生成

`handle_xcodebuildmcp()` の L333-334 で、初回 DENY 時にも `touch "$setup_flag"` が実行される。これにより:

- 初回: DENY + session_set_defaults 案内 (setup_flag が生成される)
- 2 回目: ALLOW (setup_flag が存在するため)

つまり、`session_set_defaults` を呼ばなくても 2 回目以降は ALLOW される。AC4 のテストでは `session_set_defaults` を明示的に呼ぶ手順を踏むが、この自動 setup_flag 生成の仕様も認識しておく必要がある。

**テストへの影響:** AC4 のテストでは Step 1（初回 DENY）で setup_flag が生成されるため、Step 2（session_set_defaults）は setup_flag の存在には影響しない（既に存在する）。テストの意図は「session_set_defaults を経由する正しいフローで ALLOW になること」の検証であり、setup_flag の自動生成とは独立している。session_id を分離することで、AC3 と AC4 が互いの setup_flag 状態に影響しないことを保証する。
