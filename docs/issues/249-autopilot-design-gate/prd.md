# PRD: autopilot 設計承認ゲート — 期待フローとの乖離と AL-2 凍結矛盾の解消

> 承認アンカー: ユーザー指示（2026-06-10 /goal）「私の理解では autopilot を実行した場合、実装に必要な設計部分までは私と壁打ち → その後成果物ができたら私のレビュー → 承認されたら atdd を実施という流れ。まずはそれ通りになっているか、なっていなかったら修正したい」。本 PRD はこの明示指示を要求として確定する。

## Problem

現実装（#246 / v3.6.0）の autopilot は人間ゲートが **AC 承認（discover）と merge の 2 点のみ**（AL-1）。AC 承認後は user-stories → plan+AT → ATDD 実装まで一気に自律走行し、ユーザーが期待する「設計成果物（US / plan / AT）のレビュー・承認を経てから ATDD に入る」フローになっていない。

さらに実装内部に構造矛盾がある: AL-2 freeze は `prd.md + user-stories.md` をループ開始前に pin するが、ループ最初のステップ `extracting-user-stories` が `user-stories.md` を修正するため、修正が入った瞬間 `check_pin` が ac-drift を検出して halt する（偽 escalation）。US step がレビュー指摘を 1 件でも受けたら構造的に前へ進めない。

## Why now

- ユーザーが autopilot の運用開始前にフロー齟齬の検証・修正を明示要求した（上記 /goal）。
- ac-drift 矛盾は autopilot の最初の実運用で必ず顕在化する構造バグであり、運用開始前に直す必要がある。

## Outcome

- autopilot の人間ゲートが 3 点（①要求承認 ②設計承認 ③merge）になり、②で near-green の設計成果物をユーザーがレビュー・承認してから ATDD（impl phase）が走る。
- AL-2 の pin がフェーズごとに分離され（design phase = prd.md / impl phase = prd.md + user-stories.md）、ループが自分の生成物を anchor として凍結する矛盾が消える。
- 既存 BATS（更新後）+ 新規アサーションが全 green。

## What

- `skills/autopilot/SKILL.md`: 収束ループを design phase（extracting-user-stories, writing-plan-and-tests）と impl phase（running-atdd-cycle）に分割し、間に設計承認ゲート（人間）を新設。pin を `autopilot-prd.pin`（design anchor = prd.md）と `autopilot-design.pin`（impl anchor = prd.md + user-stories.md）の 2 段に分離。
- `docs/methodology/autopilot-iron-law.md`: AL-1 を 3 ゲートに、AL-2 を 2 段 pin に更新。
- テスト・ドキュメント同期: `tests/test_autopilot_skill.bats` / `tests/e2e/autopilot.bats` / `tests/README.md` / `README.md` / `README.ja.md` / `skills/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json`（3.6.0 → 3.7.0）。

## Non-Goals

- 自動マージはしない（merge は人間ゲートのまま）。
- flow skill 本体（defining-requirements / extracting-user-stories / writing-plan-and-tests / running-atdd-cycle / reviewing-deliverables）の恒久変更はしない（#246 C1 原則の維持）。
- #248（監査ログ堅牢化）のスコープには触れない。`lib/autopilot_convergence.sh` は変更しない（既存関数で 2 段 pin を表現できる）。
- #246 の歴史的成果物（docs/issues/246-*/）は書き換えない。

## Open Questions

- なし（ゲート配置はユーザー指示で確定。acceptance-tests.md を pin に含めない判断は running-atdd-cycle が lifecycle marker を更新する事実と coverage gate の存在から導出済み）。
