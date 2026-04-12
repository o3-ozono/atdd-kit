# Plan Review: Developer Perspective

**Issue:** #11 — bug: autopilot の Agent Team で Developer/QA エージェントが滞留・大量生成される
**Reviewer:** Developer Agent
**Date:** 2026-04-12

## Overall Assessment

統合 Plan は的確で、スコープ・変更量・リスク対策のバランスが良い。autopilot.md のみの変更で完結し、既存テストとの互換性も十分に考慮されている。

**Verdict: PASS** — 指摘 0 件、軽微な改善提案 2 件

## 観点別レビュー

### 1. ファイル構成の妥当性

**判定: 妥当**

`commands/autopilot.md` のみの変更で十分な理由:

1. **バグの本質:** LLM が Phase 2〜4 で SendMessage の代わりに Agent tool を使うのは、禁止規則の欠落が原因。autopilot.md は LLM への指示書であり、Prompt Guard の追加先として正しい
2. **po.md の tools リスト変更は不適切:** PO は AC Review Round (L132) と Phase 0.9 Mid-phase resume (L95-100) で Agent tool が必要。tools リストから Agent を除外すると正当なユースケースが壊れる
3. **ランタイム制限は不要:** Agent Teams のツール制限はプラットフォーム側の機能であり、テキストレベルの Prompt Guard が現時点で最も現実的な対策

他に変更が必要なファイルはないことを確認済み:
- `agents/po.md` — 変更不要（Agent tool は正当に必要）
- `agents/developer.md`, `agents/qa.md` — 変更なし（SendMessage を持たない設計は正しい）
- `tests/` — 新規テストは QA 戦略に従い追加される

### 2. 実装順序のリスク

**判定: リスクなし**

提案された順序: C1 → C2-C5 → C6 → テスト

この順序は依存関係に沿っている:
- C1 (Rule 5 定義) が先行する必要がある — C2〜C5 と C6 が "Autonomy Rule 5" を参照するため
- C2〜C5 は互いに独立 — ファイル内の上から順に実施するのは自然
- C6 は C1 に依存するが C2〜C5 には依存しない — Step 2 と Step 3 は並列可能だが、順次実行でもリスクなし
- テストは全変更完了後に実行 — 正しい

**逆順リスクの検証:**
- C2〜C5 を C1 より先に実施すると "see Autonomy Rule 5" の参照先が存在しない状態で一時的に不整合になるが、最終的には解消される。git commit は全変更完了後なので実害なし

### 3. 技術リスク評価

#### Risk 1: 既存テスト `#165-AC1`/`#165-AC2` との衝突

**実装戦略の対策: 十分**

テストパターンを精密に検証した結果:

| テスト | grep パターン | Phase 2 C2 ガード文 | 結果 |
|--------|-------------|---------------------|------|
| L230 | `Use Agent tool.*Developer` | "New agent creation is prohibited...Developer/QA agents via SendMessage" | マッチしない (SAFE) |
| L231 | `Use Agent tool.*Developer` | (Phase 3 C4 も同様) | マッチしない (SAFE) |
| L253 | `Use Agent tool.*QA` | "New agent creation is prohibited...Developer/QA agents via SendMessage" | マッチしない (SAFE) |
| L254 | `Use Agent tool.*QA` | (Phase 4 C5 も同様) | マッチしない (SAFE) |

また、肯定テスト (L235, L239, L243, L258, L262, L266) は `SendMessage.*Developer` / `SendMessage.*QA` を検索しており、ガード文内の "SendMessage" が追加マッチするが、肯定テストなので無害。

#### Risk 2: Autonomy Rules の `-A 20` 範囲

**実装戦略の対策: 十分**

現状の Autonomy Rules セクション:
- L103: `## Autonomy Rules` (見出し)
- L105: 前文
- L107-L110: Rule 1〜4
- L112: Failure mode

C1 追加後:
- L111: Rule 5 (1 行追加)
- セクション合計: L103〜L113 = 11 行

既存テスト AC-6 (L64-82) は `grep -A 20` または `-A 25` を使用。Rule 5 の "Agent re-generation" は見出しから 8 行目に位置するため、`-A 20` で十分到達する。

#### Risk 3: C4/C5 のエージェント限定表現

**検証:**
- C4 (Phase 3): "Developer agent" のみ言及 — Phase 3 は Developer 専用なので正しい
- C5 (Phase 4): "QA agent" のみ言及 — Phase 4 は QA 専用なので正しい
- C2 (Phase 2): "Developer/QA agents" 両方言及 — Phase 2 は両方に SendMessage するので正しい
- C3 (Plan Review Round): "Developer/QA agents" 両方言及 — 同上

各フェーズの役割分担と一致しており、問題なし。

#### Risk 4: blockquote (`>`) 記法の影響

**検証:**
既存テストで blockquote 内容に影響を受けるパターンはない。grep は行単位で検索するため、blockquote のプレフィックス `> ` は grep パターンの前にあるだけで、マッチングに影響しない（`grep -q 'SendMessage.*Developer'` は `> **Constraint:** ...SendMessage...Developer...` にもマッチするが、肯定テストなので無害）。

### 4. テスト戦略との整合

QA の新規 12 テスト計画は実装戦略の 6 変更箇所すべてをカバーしている:
- AC1 (Rule 5): Autonomy Rules セクション内の検証
- AC2 (ガード): Phase 2〜4 + Plan Review Round の 4 セクション検証
- AC3 (逆参照): Phase 0.9 の検証
- AC4 (既存テスト): 86 テスト全パス

テスト追加先が `test_autopilot_agent_teams_setup.bats`（既存ファイル）であることも妥当。autopilot.md の構造テストが集約されている。

## 改善提案（任意）

### P1: C2〜C5 のガード文末に改行の一貫性

blockquote の後に空行を入れるか入れないかで、マークダウンのレンダリングが変わる。実装時に全 4 箇所で一貫させること（blockquote 後に空行 1 行を推奨）。

### P2: Rule 5 の文言で "Phase 2–4" の範囲明示

Rule 5 案の "in Phase 2–4" は Plan Review Round を含むか曖昧。実装時に "in Phase 2, Plan Review Round, Phase 3, and Phase 4" と列挙するか、"after AC Review Round" で包括的に表現するか統一すべき。実装戦略の C1 テキスト案は "in Phase 2–4" だが、Plan Review Round はフェーズ番号を持たないため、明示的に含めるのが安全。

推奨文言修正:
> do not create new instances of these agents in Phase 2, Plan Review Round, Phase 3, or Phase 4.
