# Test Strategy: QA

Issue #11: bug: autopilot の Agent Team で Developer/QA エージェントが滞留・大量生成される

## 1. AC ごとのテスト層選定

| AC | テスト層 | 理由 |
|----|---------|------|
| AC1: Autonomy Rules に Rule 5 追加 | 構造テスト (BATS/grep) | autopilot.md の Autonomy Rules セクション内に禁止規則テキストが存在するかを grep で検証。既存 AC-6 テスト群と同一手法。 |
| AC2: Phase 2〜4 + Plan Review Round に SendMessage 専用ガード追加 | 構造テスト (BATS/grep) | 各フェーズセクション内にガード文言が存在するかを grep で検証。既存 #165-AC1/#165-AC2 テストと同一手法。 |
| AC3: Phase 0.9 と Rule 5 の双方向参照 | 構造テスト (BATS/grep) | Phase 0.9 内に Rule 5 への参照、Rule 5 内に Phase 0.9 への参照が存在するかを grep で検証。 |
| AC4: 既存テスト全パス | リグレッションテスト (BATS) | `bats tests/test_autopilot_agent_teams_setup.bats` の全 86 テストがパスすることを確認。 |

**設計判断:** このリポジトリのテストは全て BATS による構造テスト（マークダウン指示書の内容を grep で検証）であり、ランタイムの統合テストは存在しない。Prompt Guard パターンの修正であるため、「禁止規則のテキストが正しく記述されているか」を検証することがテストの目的である。

## 2. 具体的なテストケース一覧

テストは既存テストファイル `tests/test_autopilot_agent_teams_setup.bats` に `Issue #11` セクションとして追加する。

### AC1: Autonomy Rules に Rule 5 追加

```bash
# ---------------------------------------------------------------------------
# #11-AC1: Autonomy Rules — Agent re-generation prohibition (Rule 5)
# ---------------------------------------------------------------------------

@test "#11-AC1: Autonomy Rules contains agent re-generation prohibition" {
  grep -A 40 "## Autonomy Rules" "$AUTOPILOT" | grep -qi 'agent.*re-\?gen\|re-\?spawn.*prohibit\|new agent.*prohibit\|Agent tool.*prohibit'
}

@test "#11-AC1: Rule 5 is numbered as item 5 in Autonomy Rules" {
  grep -A 40 "## Autonomy Rules" "$AUTOPILOT" | grep -q '^5\.'
}

@test "#11-AC1: Rule 5 specifies SendMessage as the correct alternative" {
  grep -A 40 "## Autonomy Rules" "$AUTOPILOT" | grep -qi 'SendMessage'
}

@test "#11-AC1: Rule 5 scopes prohibition to after AC Review Round" {
  # 禁止範囲は AC Review Round 後（Phase 2 以降）であることを明示
  grep -A 40 "## Autonomy Rules" "$AUTOPILOT" | grep -qi 'AC Review Round\|Phase 2'
}

@test "#11-AC1: Rule 5 is covered by existing Failure Mode" {
  # Rule 5 が Autonomy Rules セクション内にあり、共通 Failure Mode の適用を受ける
  # (Autonomy Rules の末尾 "Failure mode: report what failed..." で全ルールをカバー)
  count=$(grep -c '## Autonomy Rules' "$AUTOPILOT")
  [ "$count" -eq 1 ]
  grep -A 50 "## Autonomy Rules" "$AUTOPILOT" | grep -q 'Failure mode.*STOP'
}
```

### AC2: Phase 2〜4 + Plan Review Round に SendMessage 専用ガード追加

```bash
# ---------------------------------------------------------------------------
# #11-AC2: SendMessage-only guard in Phase 2-4 and Plan Review Round
# ---------------------------------------------------------------------------

@test "#11-AC2: Phase 2 contains SendMessage-only guard" {
  grep -A 25 "## Phase 2: plan" "$AUTOPILOT" | grep -qi 'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'
}

@test "#11-AC2: Plan Review Round contains SendMessage-only guard" {
  grep -A 20 "## Plan Review Round" "$AUTOPILOT" | grep -qi 'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'
}

@test "#11-AC2: Phase 3 contains SendMessage-only guard" {
  grep -A 25 "## Phase 3: Implementation" "$AUTOPILOT" | grep -qi 'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'
}

@test "#11-AC2: Phase 4 contains SendMessage-only guard" {
  grep -A 20 "## Phase 4: PR Review" "$AUTOPILOT" | grep -qi 'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'
}
```

### AC3: Phase 0.9 と Rule 5 の双方向参照

```bash
# ---------------------------------------------------------------------------
# #11-AC3: Bidirectional cross-reference between Phase 0.9 and Rule 5
# ---------------------------------------------------------------------------

@test "#11-AC3: Phase 0.9 Mid-phase resume references Autonomy Rules or Rule 5" {
  grep -A 60 "## Phase 0.9" "$AUTOPILOT" | grep -qi 'Autonomy Rules\|Rule 5\|only exception\|session.*re-start\|session.*resume'
}

@test "#11-AC3: Rule 5 references Phase 0.9 Mid-phase resume as exception" {
  # Rule 5 のテキスト内に Phase 0.9 の例外への言及がある
  grep -A 40 "## Autonomy Rules" "$AUTOPILOT" | grep -qi 'Phase 0.9\|Mid-phase resume\|session.*re-start\|exception'
}

@test "#11-AC3: Mid-phase resume is the only Agent tool usage outside AC Review Round" {
  # Phase 0.9 の Mid-phase resume と AC Review Round 以外に Agent tool でのスポーン記述がないこと
  # (既存テスト #165-AC5 と補完関係)
  ! sed -n '/## Phase 2:/,/## Phase 5:/p' "$AUTOPILOT" | grep -qi 'spawn.*Developer\|spawn.*QA'
}
```

### AC4: 既存テスト全パス（リグレッション）

```bash
# ---------------------------------------------------------------------------
# #11-AC4: Regression — existing tests remain passing
# ---------------------------------------------------------------------------

# AC4 は独立テストケースではなく、bats 全体実行で検証:
#   bats tests/test_autopilot_agent_teams_setup.bats
# 全 86 既存テスト + #11 新規テストが全パスすること。
#
# 特に以下の既存テストとの非干渉を重点確認:
# - #165-AC1 (行 227-232): Phase 2/3 で "Use Agent tool.*Developer" が存在しないこと
# - #165-AC2 (行 250-255): Phase 2/4 で "Use Agent tool.*QA" が存在しないこと
# - AC-6 (行 60-87): Autonomy Rules の既存 4 項目が保持されること
```

## 3. 既存テストとの関係

### 流用可能な既存テスト

| 既存テスト | 関係 | 扱い |
|-----------|------|------|
| AC-6 テスト群 (行 60-87) | AC1 と同じ Autonomy Rules セクションを対象 | そのまま流用（Rule 1-4 の存在確認は変更不要） |
| `#165-AC1` (行 227-232) | AC2 と補完関係（Phase 2/3 で Agent tool が不在） | そのまま流用（AC2 のガード追加と矛盾しない前提） |
| `#165-AC2` (行 250-255) | AC2 と補完関係（Phase 2/4 で Agent tool が不在） | そのまま流用 |
| `#165-AC5` (行 317-323) | AC3 と補完関係（AC Review Round のみ Agent tool） | そのまま流用 |
| `#165-AC6` (行 329-343) | AC3 と補完関係（Mid-phase resume ロジック） | そのまま流用 |

### 新規追加が必要なテスト

| テストケース | AC | 理由 |
|------------|-----|------|
| Rule 5 存在確認 | AC1 | 既存 AC-6 テストは Rule 1-4 のみ検証 |
| Rule 5 番号確認 | AC1 | 5 番目として正しく番号付けされていること |
| Rule 5 の SendMessage 代替指示 | AC1 | 禁止だけでなく代替手段の提示を検証 |
| Rule 5 のスコープ確認 | AC1 | AC Review Round 後に限定されていること |
| Rule 5 の Failure Mode 包含 | AC1 | 共通 Failure Mode の適用範囲内であること |
| Phase 2 ガード | AC2 | 新規追加文言の存在確認 |
| Plan Review Round ガード | AC2 | 新規追加文言の存在確認 |
| Phase 3 ガード | AC2 | 新規追加文言の存在確認 |
| Phase 4 ガード | AC2 | 新規追加文言の存在確認 |
| Phase 0.9 → Rule 5 参照 | AC3 | Mid-phase resume が例外であることの明示 |
| Rule 5 → Phase 0.9 参照 | AC3 | Rule 5 テキスト内の例外言及 |
| spawn スコープ確認 | AC3 | Phase 2-4 に spawn 記述がないこと（#165-AC5 補完） |

**新規テスト数:** 12 テスト

### 衝突リスクのあるテスト（AC4 重点確認対象）

| 既存テスト | 衝突リスク | 対策 |
|-----------|-----------|------|
| `#165-AC1` 行 230: `! grep -A 15 "## Phase 2: plan" \| grep -q 'Use Agent tool.*Developer'` | **中** — AC2 のガード文言に "Use Agent tool" を含めると失敗 | ガード文言に "Use Agent tool" パターンを使わない（後述） |
| `#165-AC1` 行 231: `! grep -A 15 "## Phase 3: Implementation" \| grep -q 'Use Agent tool.*Developer'` | **中** — 同上 | 同上 |
| `#165-AC2` 行 253: `! grep -A 20 "## Phase 2: plan" \| grep -q 'Use Agent tool.*QA'` | **中** — 同上 | 同上 |
| `#165-AC2` 行 254: `! grep -A 15 "## Phase 4: PR Review" \| grep -q 'Use Agent tool.*QA'` | **中** — 同上 | 同上 |
| AC-6 行 80: `grep -A 25 "## Autonomy Rules" \| grep -q "STOP"` | **低** — grep 範囲 25 行以内に STOP が残っていれば OK | Rule 5 追加後も共通 Failure Mode の STOP が 25 行以内にあることを確認 |

## 4. カバレッジ戦略とリグレッションリスク分析

### カバレッジマトリクス

| 検証観点 | AC1 | AC2 | AC3 | AC4 |
|---------|-----|-----|-----|-----|
| 禁止規則テキストの存在 | x | | | |
| 禁止規則の番号付け | x | | | |
| 代替手段（SendMessage）の提示 | x | x | | |
| 禁止スコープの明示 | x | | | |
| Failure Mode の包含 | x | | | |
| Phase 2 ガード | | x | | |
| Plan Review Round ガード | | x | | |
| Phase 3 ガード | | x | | |
| Phase 4 ガード | | x | | |
| Phase 0.9 → Rule 5 参照 | | | x | |
| Rule 5 → Phase 0.9 例外 | | | x | |
| spawn スコープ確認 | | | x | |
| 既存 86 テスト全パス | | | | x |

### リグレッションリスク

| リスク | 重大度 | 対策 |
|--------|--------|------|
| AC2 ガード文言が `#165-AC1`/`#165-AC2` の否定テストを壊す | **高** | ガード文言の制約を厳守: "Do NOT spawn new agents" や "Agent re-generation is prohibited" は OK。"Use Agent tool" を含む文言は NG。 |
| AC1 の Rule 5 追加で Autonomy Rules セクションが長くなり、AC-6 テスト（`grep -A 20`/`grep -A 25`）が影響を受ける | **低** | 既存 Rule 1-4 と Failure Mode は現在 10 行程度。Rule 5 を 2-3 行で追加しても `grep -A 20` の範囲内に収まる。 |
| AC3 の双方向参照追加で Phase 0.9 セクションが長くなり、`#165-AC6`（`grep -A 60`）が影響を受ける | **低** | Phase 0.9 は現在 18 行。参照文言を 1 行追加しても `grep -A 60` の範囲内。 |
| AC Review Round の Agent tool 記述に影響 | **なし** | AC Review Round は修正対象外。既存テスト AC-2（行 97-129）に影響なし。 |

### AC2 ガード文言の制約（Developer 向け実装ガイダンス）

既存テストとの衝突を回避するため、AC2 のガード文言は以下の制約に従う必要がある:

**使用可能な文言パターン:**
- "Do NOT spawn new agents -- use SendMessage only"
- "Agent re-generation is prohibited (see Autonomy Rules Rule 5)"
- "Continue via SendMessage. Do NOT create new Developer/QA agents"

**使用不可の文言パターン（既存テスト失敗を引き起こす）:**
- "Do NOT use Agent tool to spawn Developer" (`Use Agent tool.*Developer` にマッチ)
- "Use Agent tool is prohibited for QA" (`Use Agent tool.*QA` にマッチ)

### テスト実行計画

1. 実装前: `bats tests/test_autopilot_agent_teams_setup.bats` を実行し 86/86 パスを確認（ベースライン）
2. 新規テスト追加: #11 セクションの 12 テストを追加
3. 実装後: `bats tests/test_autopilot_agent_teams_setup.bats` を実行し 98/98 パス（86 既存 + 12 新規）を確認
4. 全テスト: `bats tests/` で全テストファイルのリグレッションがないことを確認
