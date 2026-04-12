# AC Review: Developer Perspective

**Issue:** #11 — bug: Autonomy Rules に Agent tool 再生成禁止規則が欠落
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Assessment

AC セットは的確にバグの根本原因を捉えており、修正アプローチ（Prompt Guard）は autopilot.md の既存構造と整合する。変更量は小さく、既存テストとの互換性も問題ない。

**Verdict: PASS** — 軽微な提案あり（下記参照）

## 観点別レビュー

### アーキテクチャ整合性

autopilot.md の Tools 行は既に Phase 2〜4 で Agent を除外している:

| セクション | Tools 行 | Agent 含む? |
|-----------|----------|-------------|
| AC Review Round (L128) | `Agent, SendMessage` | はい（唯一の正当な spawn 地点） |
| Phase 2 (L146) | `SendMessage, Skill` | いいえ |
| Plan Review Round (L160) | `SendMessage` | いいえ |
| Phase 3 (L175) | `SendMessage, Skill` | いいえ |
| Phase 4 (L187) | `SendMessage` | いいえ |

しかし、Autonomy Rules (L103-112) には明示的な「Agent tool 再生成禁止」がない。LLM は Tools 行を参照するが、それだけでは行動制約として不十分な場合がある（特にコンテキストが長くなると Tools 行が埋もれる）。Autonomy Rules に明文化することで、二重の防御層になる。

**結論:** AC1 は既存構造を補強するものであり、矛盾は生じない。

### 技術的実現性

**Prompt Guard で十分か:** はい。

理由:
1. autopilot.md は LLM への指示書であり、Prompt Guard が最も直接的な対策
2. po.md の tools リストから Agent を除外する方法は不適切 — PO は AC Review Round (L132) と Phase 0.9 Mid-phase resume (L95-100) で Agent tool が必要
3. ランタイムのツール呼び出し制限はプラットフォーム側の機能であり、現時点では autopilot.md のテキストレベルの対策が現実的

**他に必要な変更:** なし。変更は autopilot.md のみで完結する。

### エッジケース

1. **Phase 0.9 Mid-phase resume (L95-100):**
   セッション再開時に Developer/QA が存在しない場合、Agent tool での再生成が必要。AC3 でこれを「セッション再開時のみ」の例外として明記するのは適切。禁止規則の文言に「Phase 0.9 Mid-phase resume を除く」を明示すべき。
   - 現状 L95-100 は既にこの例外を記述しているが、Autonomy Rules 側から逆参照がない
   - AC1 の実装時に、新ルールと Phase 0.9 の双方向参照を入れることを推奨

2. **Developer/QA がクラッシュ・応答不能になった場合:**
   Autonomy Rules L112 の「report what failed → STOP → user decides next step」が適用される。Agent tool 再生成禁止と整合する（ユーザー判断に委ねる）。新しいエージェント障害復旧手順は今回のスコープ外で問題ない。

3. **Explore subagent の使用:**
   既に Autonomy Rule 2 (L108) で禁止済み。新規禁止規則との重複なし。

4. **AC Review Round での正当な Agent tool 使用を阻害しないか:**
   AC1 の禁止対象は「AC Review Round 以降」。AC Review Round 自体での spawn は禁止対象外。この境界が実装時に曖昧にならないよう、「AC Review Round で spawn した後は」と起点を明確にすべき。

### 実装複雑度

**変更量:** 小（autopilot.md のみ、推定 10〜15 行の追加・修正）

| 変更箇所 | 内容 | 行数目安 |
|----------|------|---------|
| Autonomy Rules | ルール 5 追加（Agent 再生成禁止、Phase 0.9 例外明記） | 2〜3 行 |
| Phase 2 | 注意書き 1 行追加 | 1 行 |
| Plan Review Round | 注意書き 1 行追加 | 1 行 |
| Phase 3 | 注意書き 1 行追加 | 1 行 |
| Phase 4 | 注意書き 1 行追加 | 1 行 |
| Phase 0.9 | 例外の補足（Autonomy Rules への逆参照） | 1 行 |

### テストへの影響

既存テスト `test_autopilot_agent_teams_setup.bats` の構造を確認した:
- **#165-AC1 (L227-244):** Phase 2, 3 で Agent tool が Developer に使われていないことを検証 → AC2 の注意書き追加と互換性あり
- **#165-AC2 (L250-267):** Phase 2, 4 で Agent tool が QA に使われていないことを検証 → 同上
- **AC-6 (L60-87):** Autonomy Rules の既存ルール検証 → AC1 のルール追加で新テスト追加が必要

**AC4 で追加すべきテストケース案:**
```
#11-AC1: Autonomy Rules に Agent re-generation 禁止文言が存在
#11-AC2: Phase 2〜4 各セクションに Agent tool 禁止注意書きが存在
#11-AC3: Phase 0.9 Mid-phase resume に例外条件が明記されていること
```

## 提案

### P1: Autonomy Rules 新ルールの文言案

> 5. **Agent re-generation** — After AC Review Round spawns Developer and QA, do not use Agent tool to create new instances of these agents in Phase 2–4. Use SendMessage to communicate with existing agents. Exception: Phase 0.9 Mid-phase resume (session restart only).

### P2: Phase 2〜4 注意書きの文言案

各セクションの手順冒頭に統一フォーマットで追加:

> **Important:** Do NOT use Agent tool to spawn new Developer/QA agents. Use SendMessage to communicate with agents spawned in AC Review Round.

### P3: 双方向参照の追加

Phase 0.9 Mid-phase resume セクション末尾に:

> This is the only exception to Autonomy Rule 5 (Agent re-generation prohibition).
