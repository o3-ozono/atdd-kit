# Plan Review: QA

**Issue:** #3 -- bug: discover の autopilot モード検出が PO 直接呼び出しを認識しない
**Reviewer:** QA Agent
**Date:** 2026-04-12

## Overall Verdict: PASS

Plan は AC カバレッジ、テスト層選定、実装順序、変更対象ファイルの全てにおいて妥当。Blocking issue なし。

## R1: テスト層の妥当性

**Verdict: PASS**

全 AC を BATS (Unit) テストで検証する方針は適切。

- 対象は SKILL.md / autopilot.md のプロンプトテキスト。テキストパターン検証（sed + grep）で十分
- LLM 実行を伴わないため E2E 層は不要
- 既存テスト `test_discover_autopilot_approval.bats` と同一のテストパターンを踏襲しており、テスト基盤の一貫性がある

## R2: カバレッジ戦略の網羅性

**Verdict: PASS**

24 テストケースで以下をカバー:

| カテゴリ | テスト数 | カバレッジ |
|---------|---------|-----------|
| AC1: discover `--autopilot` 検出 | 6 | HARD-GATE, AUTOPILOT-GUARD, Step 7, Step 8 の4箇所全てをカバー |
| AC2: Standalone モード維持 | 3 | 承認要求、Issue コメント投稿、inline plan 実行を検証 |
| AC3: plan `--autopilot` 検出 | 1 | AUTOPILOT-GUARD のみ（plan は GUARD 以外に autopilot 分岐なし） |
| AC4: atdd `--autopilot` 検出 | 1 | AUTOPILOT-GUARD のみ（atdd は GUARD 以外に autopilot 分岐なし） |
| AC5: autopilot.md `--autopilot` 付与 | 2 | Phase 1 (discover), Phase 3 (atdd) |
| REGRESSION: 旧方式除去 | 3 | 3スキルの AUTOPILOT-GUARD から `teammate-message` 完全除去確認 |
| Cross-file consistency | 2 | HARD-GATE / autopilot AC Review Round の整合性 |
| AC Review Round (既存維持) | 5 | Three Amigos、reject handling、コメント投稿順序 |

**テスト戦略（QA策定）との整合性:** テスト戦略で提案した全テストケースが Plan に反映されている。テスト数も24件で一致。

### Negative test の重要性

Negative test 3件（REGRESSION セクション）は、旧方式 `<teammate-message>` が AUTOPILOT-GUARD から完全に除去されたことを検証する。これがなければ、旧方式と新方式が共存する中間状態が検出できない。Plan にこれが含まれている点は高評価。

## R3: AC との整合性

**Verdict: PASS**

| AC | Plan での対応 | テスト | 整合性 |
|----|-------------|-------|--------|
| AC1: discover `--autopilot` 検出 | HARD-GATE(L15), GUARD(L18-23), Step 7(L230-232), Step 8(L251) の4箇所を変更 | 6テストで4箇所を個別検証 | OK |
| AC2: Standalone モード維持 | Standalone 分岐テキストは変更しない | 既存3テストで維持を確認 | OK |
| AC3: plan `--autopilot` 検出 | AUTOPILOT-GUARD を変更 | 1テスト | OK |
| AC4: atdd `--autopilot` 検出 | AUTOPILOT-GUARD を変更 | 1テスト | OK |
| AC5: autopilot.md `--autopilot` 付与 | Phase 1(L124), Phase 3(L187) を変更 | 2テスト | OK |
| AC6: 既存テスト PASS | テストファイル更新（更新4, 統合1, 新規7） | `bats tests/` で全件 PASS | OK |

**行番号の検証結果:** Plan に記載された行番号を実ファイルと照合した結果、全て正確。

- discover SKILL.md L15: HARD-GATE 内 autopilot exception -- 確認済み
- discover SKILL.md L18-23: AUTOPILOT-GUARD -- 確認済み
- discover SKILL.md L230-232: Step 7 autopilot/standalone 分岐 -- 確認済み
- discover SKILL.md L251: Step 8 autopilot skip -- 確認済み
- autopilot.md L124: Phase 1 discover Skill 呼び出し -- 確認済み
- autopilot.md L187: Phase 3 atdd Skill 呼び出し -- 確認済み

## R4: 実装順序の妥当性

**Verdict: PASS**

```
1. AC3: plan AUTOPILOT-GUARD
2. AC4: atdd AUTOPILOT-GUARD
3. AC1+AC2: discover 全箇所
4. AC5: autopilot.md
5. AC6: テスト更新
```

この順序は適切:

- **AC3, AC4 を先行:** plan/atdd は変更箇所が AUTOPILOT-GUARD 1箇所のみで、最もシンプル。実装パターンを確立してから discover（4箇所）に進む
- **AC1+AC2 を同一コミット:** discover の4箇所は相互に依存（HARD-GATE の exception が Step 7 を参照）。分割すると中間状態で不整合が発生する
- **AC6 を最後:** テストは全実装完了後に更新・実行

**懸念点:** ATDD の Iron Law 4（1 AC = 1 commit）に従うと、AC1 と AC2 は別コミットが望ましいが、AC2 は「変更しない」ことの確認であり、独立したコミットの対象にはならない。AC1+AC2 の統合は妥当。

## R5: フラグ検出仕様の妥当性

**Verdict: PASS**

「ARGUMENTS 文字列に対する contains チェック（LLM が自然言語として解釈）」という仕様は、SKILL.md のプロンプト記述の性質に合致している。

- SKILL.md は引数パーサーではなく、LLM への指示テキスト
- `If ARGUMENTS contains --autopilot` は LLM が自然に解釈できる
- 全スキル共通パターンにすることで一貫性が保たれる

## R6: 変更対象ファイルの網羅性

**Verdict: PASS**

| # | File | AC | 必要性 |
|---|------|----|--------|
| 1 | `skills/plan/SKILL.md` | AC3 | 必須 -- AUTOPILOT-GUARD 変更 |
| 2 | `skills/atdd/SKILL.md` | AC4 | 必須 -- AUTOPILOT-GUARD 変更 |
| 3 | `skills/discover/SKILL.md` | AC1+AC2 | 必須 -- 4箇所変更 |
| 4 | `commands/autopilot.md` | AC5 | 必須 -- Phase 1/3 の Skill 呼び出し変更 |
| 5 | `tests/test_discover_autopilot_approval.bats` | AC6 | 必須 -- テスト更新 |

**CHANGELOG.md / plugin.json の扱い:** Plan に明記されていないが、これらは bug fix のため version bump が必要（DEVELOPMENT.md の Non-Negotiable Rules）。Developer が verify/ship 時に対応する想定で問題なし。

### Plan に含まれていないが影響を受けないファイルの確認

- `docs/autonomy-levels.md` -- autopilot モード検出には関係なし
- `agents/po.md`, `agents/developer.md`, `agents/qa.md` -- Skill 呼び出し時の args 指定は autopilot.md が担当。agent 定義には影響なし
- `.claude/rules/workflow-overrides.md` -- plan 承認スキップのルール。autopilot モード検出とは独立。変更不要

## R7: 検証手順の妥当性

**Verdict: PASS**

Plan の検証手順4項目:

1. `bats tests/test_discover_autopilot_approval.bats` -- 24テスト PASS: AC6 の直接検証
2. `bats tests/` -- 全テストスイート PASS: リグレッション確認
3. `grep -r 'teammate-message' skills/{discover,plan,atdd}/SKILL.md` -- 0件: 旧方式完全除去の確認
4. `grep -r '\-\-autopilot' skills/{discover,plan,atdd}/SKILL.md commands/autopilot.md` -- 全箇所ヒット: 新方式の存在確認

手順3, 4 は Negative test (REGRESSION セクション) と AC1/3/4/5 テストでカバーされているが、手動確認として明示されている点は良い。二重検証になり安全性が高い。

## Summary

| Check | Verdict | 備考 |
|-------|---------|------|
| R1: テスト層 | **PASS** | 全 AC が BATS Unit -- 適切 |
| R2: カバレッジ | **PASS** | 24テスト。テスト戦略と完全一致。Negative test 含む |
| R3: AC 整合性 | **PASS** | 全6 AC がカバーされ、行番号も正確 |
| R4: 実装順序 | **PASS** | シンプル → 複雑の順。AC1+AC2 統合は妥当 |
| R5: フラグ仕様 | **PASS** | LLM 指示テキストとして適切 |
| R6: ファイル網羅性 | **PASS** | 5ファイル8箇所。影響外ファイルも確認済み |
| R7: 検証手順 | **PASS** | 4項目の手動検証。テストとの二重検証で安全 |

**Blocking issues: 0件**
**Non-blocking recommendations: 0件**

Plan は承認可能です。
