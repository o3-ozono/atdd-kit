# AC Review: QA Perspective

Issue #1: bug: sim-pool-guard.sh が build_sim / build_run_sim / test_sim を CLONE_REQUIRED_TOOLS から除外している

## Overall Testability Assessment

**高い。** 既存の BATS テストパターン（`test_sim_failclosed_guard.bats`、`test_sim_auto_inject.bats`、`test_sim_ephemeral_clone.bats`）が十分に成熟しており、AC1-AC5 のすべてが同じパターンで検証可能。変更対象は `CLONE_REQUIRED_TOOLS` 配列への 3 エントリ追加のみであり、テストの複雑度も低い。

既存テストでは以下のパターンが確立されている:
- `run_guard` ヘルパーで JSON 入力を生成し、guard スクリプトにパイプ
- mock `xcrun` で `simctl` の応答をスタブ
- `jq -e` で出力 JSON の `permissionDecision` を検証
- `sed -n` + `grep` で配列メンバーシップを静的検証

**全 AC がこれらの確立済みパターンで記述でき、新しいテスト基盤は不要。**

## Per-AC Feedback

### AC1: build_sim の ALLOW (regression test)

**テスト可能性:** 高
- `test_sim_auto_inject.bats` の AC5.1-AC5.2 と同じパターンで検証可能
- 初回呼び出し時の DENY（setup_flag 未作成）と、`session_set_defaults` 後の ALLOW の 2 段階テストが必要

**フィードバック:**
- Then 節「クローン確保後に ALLOW される」は不正確。`handle_xcodebuildmcp` のロジック（L332-339）では、初回呼び出し時に `setup_flag` が存在しない場合は DENY + `session_set_defaults` 案内が返される。`session_set_defaults` 呼び出し後の 2 回目以降が ALLOW になる
- **推奨:** Then 節を以下に修正:
  > `CLONE_REQUIRED_TOOLS` に含まれ、`mcp__XcodeBuildMCP__*` パターンで `handle_xcodebuildmcp` にルーティングされる。`session_set_defaults` 実行後に ALLOW される（初回は DENY + 設定案内）

**境界条件:**
- `build_sim` に渡される `tool_input` のバリエーション（空 `{}`、パラメータ付き）-> 現在のロジックでは `tool_input` は ALLOW/DENY 判定に影響しないが、テストでは空と非空の両方を検証すべき

### AC2: build_run_sim の ALLOW (regression test)

**テスト可能性:** 高
- AC1 と同一のテストパターン

**フィードバック:**
- AC1 と同じ Then 節の問題（初回 DENY の挙動が未記述）
- AC1 と AC2 は本質的に同一のテストロジック。テスト実装ではパラメタライズ（同一テスト関数を 3 ツールで繰り返す）が望ましい

### AC3: test_sim の ALLOW (regression test)

**テスト可能性:** 高
- AC1/AC2 と同一

**フィードバック:**
- AC1 と同じ Then 節の問題
- 3 つの AC を個別に記述する設計は回帰テストとしては正しい（各ツールが個別に検証される）

### AC4: 既存ツールの動作維持

**テスト可能性:** 高
- 既存テストスイート全体（`test_sim_failclosed_guard.bats`、`test_sim_auto_inject.bats`、`test_sim_persist_block.bats` 等）がそのまま回帰テストとして機能する
- 追加で新しいテストを書く必要はなく、既存テストがすべてパスすることで AC4 を満たす

**フィードバック:**
- AC4 は独立したテストケースを新規作成するのではなく、既存テストスイートの全パスをもって検証とすべき。これにより二重メンテナンスを避けられる
- **推奨:** AC4 の検証方法を「既存 BATS テストスイートの全テストがパスすること」と明示する

**境界条件:**
- `CLONE_REQUIRED_TOOLS` 配列への追加が配列の末尾に行われ、既存エントリのインデックスに影響しないことを確認（bash の `in_array` はインデックスに依存しないため問題ないが、将来の配列参照変更に対する防御として）

### AC5: handle_xcodebuildmcp ルーティング

**テスト可能性:** 高
- `test_sim_auto_inject.bats` の AC5.1（初回 build -> DENY + instruction）と AC5.2（`session_set_defaults` 後 -> ALLOW）が既にこのルーティングを検証している
- 新ツール 3 つに対して同じパターンを適用するだけ

**フィードバック:**
- AC5 は AC1-AC3 の Then 節に含めるべき内容であり、独立した AC としては冗長。AC1-AC3 の Then 節を正確に記述すれば AC5 は自動的にカバーされる
- **推奨:** AC5 を AC1-AC3 に統合するか、AC5 を「実装の正確性検証」として位置づけ直す。具体的には:
  - 静的検証: `CLONE_REQUIRED_TOOLS` 配列に 3 ツールが存在すること（`sed -n` + `grep`）
  - 動的検証: 3 ツールが `handle_xcodebuildmcp` を経由すること（`setup_flag` の動作で間接検証）

## Missing Scenarios / Edge Cases

### 1. 配列メンバーシップの静的検証（重要度: 高）

AC1-AC3 は動的テスト（guard を実行して結果を検証）だが、根本原因が「配列への追加漏れ」であるため、**静的検証**（スクリプトファイルの `CLONE_REQUIRED_TOOLS` セクションに文字列が存在することを直接確認）も追加すべき。

```bash
@test "CLONE_REQUIRED_TOOLS contains build_sim" {
  grep -q '"mcp__XcodeBuildMCP__build_sim"' <(
    sed -n '/^CLONE_REQUIRED_TOOLS=/,/^)/p' "$GUARD"
  )
}
```

これは `test_sim_failclosed_guard.bats` の AC3.12-AC3.13 と同じパターンで、既に確立されている。このテストがあれば、仮に `main()` のルーティングロジックに将来変更があっても、配列自体の正しさが保証される。

**推奨:** AC1-AC3 それぞれに静的検証アサーションを追加、または専用の AC6 として切り出す。

### 2. READONLY_TOOLS に誤って追加されていないことの確認（重要度: 高）

3 ツールが `READONLY_TOOLS` に含まれていないことを検証する否定テストが必要。`READONLY_TOOLS` に含まれると、クローン確保なしで ALLOW されてしまい、シミュレータの分離が崩壊する。

```bash
@test "build_sim is NOT in READONLY_TOOLS" {
  ! grep -q '"mcp__XcodeBuildMCP__build_sim"' <(
    sed -n '/^READONLY_TOOLS=/,/^)/p' "$GUARD"
  )
}
```

これは `test_sim_failclosed_guard.bats` の AC3.12 と同じパターン。

### 3. 初回呼び出し時の DENY + session_set_defaults 案内（重要度: 中）

AC1-AC3 の Then 節は「ALLOW される」と記述しているが、`handle_xcodebuildmcp` のロジック上、**初回呼び出しは DENY** になる。この挙動を明示的にテストすべき:

```bash
@test "first build_sim call is DENY with session_set_defaults instruction" {
  result=$(run_guard "mcp__XcodeBuildMCP__build_sim" '{}')
  echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
  context=$(echo "$result" | jq -r '.hookSpecificOutput.additionalContext')
  [[ "$context" == *"session_set_defaults"* ]]
}
```

### 4. クローン UDID がツール入力に影響しないことの確認（重要度: 低）

`build_sim`、`build_run_sim`、`test_sim` は `mcp__XcodeBuildMCP__*` パターンなので `handle_xcodebuildmcp` で処理される。このハンドラは `emit_allow` を返すだけで `updatedInput` を付与しない（`handle_ios_simulator` とは異なる）。この挙動が正しいことを確認するテストがあると安心だが、優先度は低い。

### 5. fail-closed DENY から CLONE_REQUIRED ALLOW への遷移（重要度: 中）

修正前の状態では `build_sim` が `CLONE_REQUIRED_TOOLS` にないため fail-closed DENY される。修正後は CLONE_REQUIRED 経由で処理される。この状態遷移を明示的にテストする「修正前 -> 修正後」の回帰テストがあると、バグの再発防止に有効。ただし、修正後のスクリプトで「修正前の状態」を再現するのは困難なため、静的検証（Missing Scenario #1）で代替する。

## Suggested Test Approach

### 新規テストファイル

`addons/ios/tests/test_sim_clone_required_variants.bats` を新規作成し、3 つのバリアントツールのテストを集約する。

### テスト構成

```bash
# 静的検証: 配列メンバーシップ
@test "CLONE_REQUIRED_TOOLS contains build_sim"
@test "CLONE_REQUIRED_TOOLS contains build_run_sim"
@test "CLONE_REQUIRED_TOOLS contains test_sim"
@test "build_sim is NOT in READONLY_TOOLS"
@test "build_run_sim is NOT in READONLY_TOOLS"
@test "test_sim is NOT in READONLY_TOOLS"

# 動的検証: 初回 DENY + session_set_defaults 案内
@test "first build_sim call is DENY with session_set_defaults instruction"
@test "first build_run_sim call is DENY with session_set_defaults instruction"
@test "first test_sim call is DENY with session_set_defaults instruction"

# 動的検証: session_set_defaults 後の ALLOW
@test "build_sim is ALLOW after session_set_defaults"
@test "build_run_sim is ALLOW after session_set_defaults"
@test "test_sim is ALLOW after session_set_defaults"

# 回帰: 既存ツールは影響なし（既存テストスイートで担保）
```

### setup/teardown

`test_sim_auto_inject.bats` の setup/teardown をそのまま流用可能。mock `xcrun` パターン、環境変数設定、ゴールデンマーカー事前作成の 3 点セット。

### BATS パターン

| 検証タイプ | パターン | 参考テスト |
|-----------|---------|-----------|
| 静的: 配列含有 | `grep -q` + `sed -n` | `test_sim_failclosed_guard.bats` AC3.12-AC3.13 |
| 静的: 配列非含有 | `! grep -q` + `sed -n` | `test_sim_failclosed_guard.bats` AC3.12 |
| 動的: DENY 検証 | `jq -e '.hookSpecificOutput.permissionDecision == "deny"'` | `test_sim_auto_inject.bats` AC5.1 |
| 動的: ALLOW 検証 | `jq -e '.hookSpecificOutput.permissionDecision == "allow"'` | `test_sim_auto_inject.bats` AC5.2 |
| 動的: コンテキスト検証 | `jq -r '.hookSpecificOutput.additionalContext'` + `[[ *contains* ]]` | `test_sim_auto_inject.bats` AC5.5 |

## Summary

| AC | テスト可能性 | 指摘事項 |
|----|------------|---------|
| AC1 | 高 | Then 節が初回 DENY 挙動を反映していない。静的検証を追加すべき |
| AC2 | 高 | AC1 と同じ指摘。テスト実装では AC1 と統合可能 |
| AC3 | 高 | AC1 と同じ指摘 |
| AC4 | 高 | 既存テストスイートの全パスで検証可能。新規テスト不要 |
| AC5 | 高 | AC1-AC3 に統合可能。独立 AC としては冗長 |

**追加すべきシナリオ:**
1. 静的検証: `CLONE_REQUIRED_TOOLS` 配列メンバーシップ（必須）
2. 否定テスト: `READONLY_TOOLS` に含まれていないこと（必須）
3. 初回 DENY + `session_set_defaults` 案内の動的検証（推奨）
