# PRD: autopilot 復活 — 自律収束ループ（autopilot）

## Problem

atdd-kit の 6-step フローでは、各成果物（PRD / User Stories / Plan / AT / コード）を**人間が逐一レビューし、各 step を手で起動・確認する**。この**レビュー労力と手動介在点の多さ**が開発のボトルネックになっている（現状）。結果として、1 Issue を通すたびに人間が何度もループに入り、思考の連続性が途切れる。

旧 autopilot は v3.0.0(#202-207) で廃止されたが、それは「Agent Teams orchestration 中心の複雑な設計が開発・レビューしづらい状態を生んだ」ためであり、**「半自動運転」という発想自体は有効**である。

## Why now

実現可能性（新基盤が揃った）と必要性（レビュー労力がボトルネック）の**両輪**:

- `reviewing-deliverables` の **Workflow 化**(#235/#241: 動的パネル + 並列 + 敵対的検証 + documentation lens)
- **Workflow ツール**（決定論的 JS orchestration）と goal/loop プリミティブ
- `running-atdd-cycle` の **RED→GREEN**（実行可能 AT）、`skill-gate` の並列衝突検出(#197)
- 先行事例調査（`research.md`）で同型 OSS 6件以上 + ベンダー本番2件（OpenAI Codex / Anthropic code-review）を確認し、実現可能性が高いと判断

## Outcome

**MVP が動く実装完了基準**（運用 KPI は Phase 3 / 別 Issue）:

- 新 skill `autopilot`（autopilot orchestrator）が実装され、**既存の 6-step skill を使って** 1 step の成果物を**満足オラクル** `AND(実行可能 AT 緑, reviewing-deliverables verdict = correct, P0/P1 findings = 0)` まで自律収束させる end-to-end が動く。
- **autopilot 専用 Iron Law** が明文化され、人間ゲートを「最初（AC 承認）と最後（merge）」の2点に絞ることが正当化される。
- Unit Test + Skill E2E Test + `reviewing-deliverables` の Workflow レビューが全 green。
- 各反復の verdict が `docs/issues/<NNN>/autopilot-log.jsonl` に永続化される（監査基盤）。

## What

**autopilot の定義（本質）**: 個々の skill を autopilot のために恒久変更するのではなく、**既存の 6-step skill をそのまま使いながら、人間の介入点を「最初（要求固め + AC 承認）」と「最後（merge）」の2点だけに絞る半自動運転**。skill の役割（特に人間ゲートの扱い）は **autopilot を使った場合のみ**変わる。

in-scope:

- **E — `autopilot` skill（薄い orchestrator）**: 既存 skill（`extracting-user-stories` → `writing-plan-and-tests` → `running-atdd-cycle` → `reviewing-deliverables`）を順に呼び、中間を `generate → review → fix` で満足オラクルまで自律ループ。安全レール（MAX_ITERATIONS / sameness-detector(sha256) / stuck 検出(window=3) / COMPLETED_WITH_DEBT / JSONL 永続化 / 非収束時 human escalation）。
- **C — autopilot 専用 Iron Law（AL-1〜6）の明文化**: `docs/methodology/autopilot-iron-law.md` + `rules/atdd-kit.md` の1行参照 + skill 要約。標準 Iron Law を **autopilot モードのときだけ**上書きし、人間ゲート2点を正当化。「skill は autopilot を使った場合のみ役割が変わる（恒久改造しない）」原則を明記。
- **B — `reviewing-deliverables` の verdict を後方互換で構造化**: autopilot がループ判定に使う `findings[]` / `overall_correctness` / `evidence_ref` を追加。**通常モードの PASS/FAIL 出力は維持**（autopilot を使った場合のみ役割が変わる枠）。
- **A — design-doc 設計確定**: autopilot Iron Law 節 + autopilot の定義（半自動運転・人間ゲート2点・skill は autopilot モードのみ役割変更）を追記。
- **F — テスト + ドキュメント同期**: Unit Test + Skill E2E Test + `skills/README.md` / `lib/README.md` / `docs/methodology/README.md` sync。
- **G — リリース規約**: version bump（3.5.0→3.6.0）+ CHANGELOG。

## Non-Goals

- **D — `defining-requirements` の壁打ち強化（skill 恒久改造）はしない**。autopilot は既存 skill を使うのが本質で、skill を autopilot のためだけに恒久変更しない。壁打ち思想は design-doc §0 と autopilot Iron Law に記録済み（価値検証後に別 Issue）。
- **既存 skill のロジックを autopilot のために恒久変更しない**。autopilot を使った場合のみ役割（人間ゲートの扱い）が変わる。
- **自動マージはしない**。merge は人間ゲート（AL-1）。Anthropic *"does not approve or block PRs"* / OpenAI *"not a replacement"* と整合。
- **旧 autopilot（Agent Teams orchestration / persona / autonomy-levels / circuit_breaker.sh）の逐語復活はしない**。新基盤（Workflow/AT）に載せ替える。
- **KPI 閾値・eval 計測・全 step 自動展開・リスク tiering の精緻化（Phase 3）は別 Issue**。

## Open Questions

- design-doc の OQ2-5（US step の backstop / 成果物形態の最終確定 / 信頼度を上げる eval 指標と閾値 / コスト上限）は実装中または Phase 3（別 Issue）で詰める。
- B（verdict 構造化）の追加フィールドを autopilot モード限定で返すか常時返すか（後方互換は必須）は実装時に確定。
