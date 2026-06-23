# PRD: autopilot 収束ループの根本再設計 — 収束信号を客観ゲートに一本化し、LLM レビューをループから外す

> 統合: 本 #355 は #345「reviewing-deliverables の収束性改善」を集約する。#345 はクローズ済み。
> 再設計の根拠は [research.md](research.md)（2026-06-23 deep-research, 20 confirmed / 5 killed）に集約。

## Problem

**現状**: autopilot 収束ループ（impl phase）は満足オラクル `AND(redObserved, atGreen, coverageOk, overall_correctness==correct, P0/P1==0)` を全項同時真まで `generate→review→fix` で回す。収束信号の一部を **LLM レビュー（reviewing-deliverables）の自己判定**に置いている。

**困ること（実観測）**:
1. **非収束**: レビューのたびに別角度の細かい指摘（nitpick）が湧き、前ラウンドの blocker を全解消しても FAIL が継続。停止条件が回数上限（MAX_ITERATIONS）だけになり、demonstrably-done な成果物でも空転する。P0 数が「多→4→0→1」と振動した実例（#341 / stockbot-jp #7 で4ラウンド連続 FAIL）。
2. **長時間・高コスト**: LLM レビュー1ラウンドが ~6M トークン・~1時間。impl phase 全体で複数時間。レビュー自体が長時間化の主因。

**根本原因（research.md で裏付け）**:
- 外部の客観信号なしの自己判定ループは構造的に収束しない（Huang 2310.01798「LLMは推論を自己修正できない」/ Feedback Friction 2506.11930 / Self-Refine 2303.17651）。観測された P0 振動はこの現象そのもの。
- 敵対レビューの nitpick 膨張は precision-recall Pareto 上で構造的、dedup や多数決では止まらない（CriticGPT 2407.00215）。
- 実運用の最強プレイヤーは全員レビューを収束/ブロッキングから外している（OpenAI: precision over recall・support tool / Anthropic: "Claude does not approve or block PRs" advisory-only / langchain open-swe: LLM レビューノードを廃止し決定論ゲート+step limit へ退化）。
- #345 で投入した対症策（多視点合議 2/3・dedup・round memory・max 3 rounds）は「レビュアーを賢くする」方向で、直すレイヤを間違えていた。

## Why now

#341 の autopilot 実走で約2時間・大量トークンを空転で浪費。autopilot / full-autopilot は本プロジェクトの自律実行基盤であり、収束しないループはすべての自律フローのコスト・信頼性・体験を直接毀損する。「レビュアーを賢く」方向の追加実装も収束に至らないことが本 Issue 自身の impl phase 実走（6 iteration 全 FAIL）で再確認された。

## Outcome

完了時に達成されている状態:

1. **autopilot 収束ループから LLM レビューを完全除去**。impl-phase オラクル = 客観ゲートのみ `AND(redObserved, atGreen, coverageOk)`。`overall_correctness` / blocking-findings 項を削除。design-phase はレビューループを持たず、生成 → 人間の Gate②（設計承認）で収束する（差し戻しは `rejectionFindings` で再生成）。
2. **客観ゲートを Issue クラスに適合**（triggering instance の真因）: AT が実行可能（`tests/acceptance/`）でも skill/doc 変更の BATS pin（`tests/*.bats`）でも、red-first（変更前 赤 → 変更後 緑）と red.jsonl 記録・AC→AT カバレッジが成立するよう一般化する。`tests/acceptance/AT-<NNN>.*` 固有のファイル名前提・git log 考古学を撤廃。
3. **red-gate 堅牢化（F8 維持）**: `record_red_evidence` が test SHA と impl baseline SHA を red.jsonl に直接記録、`check_red_evidence` は記録値を読むだけ（git log 考古学なし）。deterministic に `redObserved` 確定。
4. **停止条件の整理**: 収束 = 客観ゲート green。非収束時は既存 rails（MAX_ITERATIONS / sameness / stuck）＋ 客観ゲートが確立不能な場合の `gate-unverifiable` 早期 escalation。
5. **reviewing-deliverables は autopilot ループから外す**: スキル自体は #345 前の形に戻し、明示起動の standalone スキル（Step 5 / 人間補助）として存続。人間判断は merge gate（Gate③）に集約。

**測定可能な合否**: #341 / #345 再現シナリオで (a) demonstrably-done（test green ＋ AC カバレッジ）がレビュー nitpick に veto されず収束する、(b) レビューループ除去によりラウンドあたりのトークン・時間が大幅減、(c) skill/doc 変更（BATS pin）の Issue でも red-first / red.jsonl / coverage が成立し redObserved が deterministic に確定する。

## What（スコープ内）

- `skills/autopilot/SKILL.md` — impl-phase オラクルからレビュー項を削除（客観ゲートのみ）。design-phase のレビューループ除去。red-gate プロンプトを red.jsonl 記録値読み取りに（F8）。Issue クラス適合の客観ゲート。stop 理由整理。冒頭の「reviewing-deliverables を in-loop reviewer とする」記述を撤廃。
- `lib/autopilot_convergence.sh` — `record_red_evidence` の impl_sha 記録・`check_red_evidence` の記録値判定（F8 維持）。`record_halt` の `gate-unverifiable` enum 維持（客観ゲート確立不能の早期 escalation）。
- `skills/running-atdd-cycle/SKILL.md` — red-first / `record_red_evidence`（test SHA + impl baseline SHA）を全テスト modality（実行可能 AT・BATS pin）に一般化。
- `skills/reviewing-deliverables/SKILL.md` — #345 前（main）の形に revert。autopilot 連携記述を「standalone / 人間補助」に整理。
- `docs/methodology/autopilot-iron-law.md`（AL-3/AL-4/AL-5: オラクル定義・レビュー除去）、`docs/methodology/autopilot-overview.md` ほかレビューを in-loop と記す methodology ドキュメントの追従。

## Non-Goals

- **red-first 方針そのもの（#334）** — 変更しない。red 観測の必須性は維持し、記録方法の堅牢化と modality 一般化のみ。
- **coverage-gate / atGreen の内部判定ロジック本体** — オラクルの構成要素として残し、内部アルゴリズムは対象外。
- **3ゲート（AL-1）の構造** — User gate の数・位置は不変。
- **reviewing-deliverables スキルの削除** — 削除はしない。autopilot ループから外すだけ。standalone として存続。

## Open Questions（Gate① で解決済み）

1. LLM レビューを advisory に残すか → **解決: 残さない。収束ループから完全除去**（ユーザー決定 2026-06-23）。
2. design-phase の収束信号 → **解決: レビューループ無し。生成 → 人間 Gate②**。
3. multi-round の最適ラウンド数 → 文献で確定値なし。既存 rails（MAX_ITERATIONS / sameness / stuck）で bound、レビュー除去で実効ラウンドは大幅減の見込み。
