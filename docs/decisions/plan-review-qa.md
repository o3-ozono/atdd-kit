# Plan Review: QA Perspective

Issue #11: bug: autopilot の Agent Team で Developer/QA エージェントが滞留・大量生成される

## 1. テスト層の妥当性

**判定: 適切**

全 AC を BATS/grep 構造テストで検証する方針は、このリポジトリのテスト戦略として妥当。

理由:
- autopilot.md は LLM へのプロンプト（マークダウン指示書）であり、ランタイムの単体テスト/統合テストの対象ではない
- 修正対象が「テキストの追加」のみ（コードロジック変更なし）であるため、「正しいテキストが正しい場所に存在するか」を検証する構造テストが最適なテスト層
- 既存テスト（Issue #153, #165, #180, #7）すべてが同じ BATS/grep パターンを採用しており、一貫性がある
- E2E テスト（実際に autopilot を実行してエージェント滞留が解消されるかの検証）はコストが高く、Prompt Guard の効果は LLM の指示追従能力に依存するため、構造テストで十分

## 2. カバレッジ網羅性

### 実装変更とテストの対応表

| 実装変更 (C1-C6) | テストケース | カバレッジ |
|------------------|------------|-----------|
| C1: Rule 5 追加 | #11-AC1 (5 テスト): 存在確認、番号確認、SendMessage 代替提示、スコープ確認、Failure Mode 包含 | 完全 |
| C2: Phase 2 ガード | #11-AC2 Phase 2 テスト | 完全 |
| C3: Plan Review Round ガード | #11-AC2 Plan Review Round テスト | 完全 |
| C4: Phase 3 ガード | #11-AC2 Phase 3 テスト | 完全 |
| C5: Phase 4 ガード | #11-AC2 Phase 4 テスト | 完全 |
| C6: Phase 0.9 逆参照 | #11-AC3 (3 テスト): Phase 0.9→Rule 5 参照、Rule 5→Phase 0.9 例外、spawn スコープ | 完全 |

**判定: 6 変更すべてに対応するテストが存在し、カバレッジに抜けなし**

### 既存テストによる暗黙的カバレッジ

以下の既存テストが AC4（リグレッション）として間接的にカバレッジを提供:

| 既存テスト | カバレッジ提供内容 |
|-----------|-----------------|
| AC-6 テスト群 (行 60-87) | Rule 1-4 が C1 追加後も保持されていること |
| #165-AC1 (行 227-232) | Phase 2/3 で Agent tool が使われていないこと（C2/C4 ガード文言の衝突検出） |
| #165-AC2 (行 250-255) | Phase 2/4 で Agent tool が使われていないこと（C2/C5 ガード文言の衝突検出） |
| #165-AC6 (行 329-343) | Phase 0.9 Mid-phase resume ロジックが保持されていること |

## 3. 実装戦略とテスト戦略の整合性

### 3.1 C1 (Rule 5) とテスト AC1 の整合性

**判定: 整合**

実装文言:
> "Once Developer and QA are spawned in AC Review Round, do not create new instances of these agents in Phase 2–4. Communicate with existing agents exclusively via SendMessage. Exception: Phase 0.9 Mid-phase resume handles session-restart re-creation only."

テスト検証項目との照合:
- "agent re-generation prohibition" → `grep -qi 'agent.*re-gen\|re-spawn.*prohibit\|new agent.*prohibit'` -- "do not create new instances" がマッチ: OK
- "numbered as item 5" → `grep -q '^5\.'` -- Rule 5 として番号付けされる前提: OK
- "SendMessage as correct alternative" → `grep -qi 'SendMessage'` -- "exclusively via SendMessage" がマッチ: OK
- "scopes prohibition to after AC Review Round" → `grep -qi 'AC Review Round\|Phase 2'` -- "spawned in AC Review Round" がマッチ: OK
- "Failure Mode" → Autonomy Rules セクション内に配置されるため共通 Failure Mode 適用: OK

### 3.2 C2-C5 (ガード文言) とテスト AC2 の整合性

**判定: 整合（制約付き）**

実装文言:
> `> **Constraint:** New agent creation is prohibited in this phase. Communicate with existing Developer/QA agents via SendMessage only (see Autonomy Rule 5).`

テスト検証パターン:
```
grep -qi 'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'
```

照合:
- "SendMessage only" が実装文言 "via SendMessage only" にマッチ: OK

既存テストとの衝突検証:
- `#165-AC1` パターン: `'Use Agent tool.*Developer'` -- 実装文言に "Use Agent tool" は含まれない: OK (衝突なし)
- `#165-AC2` パターン: `'Use Agent tool.*QA'` -- 同上: OK (衝突なし)

**重要確認:** 実装文言 "New agent creation is prohibited" は既存テストのパターンにマッチしない。安全。

### 3.3 C6 (Phase 0.9 逆参照) とテスト AC3 の整合性

**判定: 整合**

実装文言:
> "Note: This mid-phase resume is the sole exception to Autonomy Rule 5..."

テスト検証パターン:
- `grep -qi 'Autonomy Rules\|Rule 5\|only exception'` -- "sole exception to Autonomy Rule 5" がマッチ: OK
- `grep -qi 'Phase 0.9\|Mid-phase resume\|exception'` -- Rule 5 テキスト内の "Exception: Phase 0.9 Mid-phase resume" がマッチ: OK

### 3.4 実装順序とテスト実行の整合性

実装順序 C1 → C2-C5 → C6 → テストは論理的に正しい:
1. C1 で Rule 5 を定義（AC1 テストの前提条件）
2. C2-C5 で Rule 5 を参照するガードを配置（AC2 テストの前提条件）
3. C6 で双方向参照を完成（AC3 テストの前提条件）
4. テスト実行で全 98 テストパスを確認

## 4. リスクと推奨事項

### リスク 1: AC-6 テストの grep 範囲

**リスク度: 低**

AC-6 テスト `grep -A 20 "## Autonomy Rules"` は現在 4 ルール + Failure Mode で約 10 行。Rule 5 を 2-3 行で追加すると約 13 行。`grep -A 20` の範囲内に収まる。

ただし、Rule 5 の文言が実装戦略の記述（3 行: 本文 + Exception 句）どおりだと:
- 行 103 (## Autonomy Rules) から数えて Rule 5 の末尾が行 113 付近
- Failure Mode が行 114 付近
- `grep -A 20` は行 123 まで取得
- 余裕あり: OK

### リスク 2: テストパターンの柔軟性

**リスク度: 低**

AC2 テストの grep パターン `'SendMessage only\|SendMessage.*continue\|Do NOT spawn\|re-generation.*prohibit'` は OR 条件で複数パターンを許容しており、実装文言の微調整に耐性がある。実装文言 "via SendMessage only" は最初のパターンにマッチする。

### 推奨事項

1. **実装完了後の全テスト実行を必ず実施:** `bats tests/` で全テストファイルを実行し、他の Issue のテストへの波及影響がないことを確認する
2. **テストを先に追加する ATDD パターンの遵守:** 12 新規テストを先に追加 → 失敗確認 → 実装 → パス確認、の順序で進める
3. **ガード文言の blockquote 記法:** 実装戦略の `> **Constraint:**` は markdown の blockquote であり、grep のパターンマッチには影響しないが、`grep -A N` の行数カウントには 1 行として計上される点に留意

## QA Verdict

**PASS** -- 実装戦略とテスト戦略は整合しており、カバレッジに抜けなし。既存テストとの衝突リスクは実装文言の制約によって適切に管理されている。実装に進めて問題なし。
