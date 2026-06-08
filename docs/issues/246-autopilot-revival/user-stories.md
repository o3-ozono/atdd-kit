# User Stories: autopilot 復活 — 自律収束ループ（converging-deliverables）

## Functional Story

### F1: 半自動運転オーケストレーション

**I want to** `converging-deliverables` を起動すると既存の 6-step skill（`extracting-user-stories` → `writing-plan-and-tests` → `running-atdd-cycle` → `reviewing-deliverables`）が順に自動実行され、人間の介入が「最初（AC 承認）」と「最後（merge）」の2点に絞られる,
**so that** 各 step を手で起動・レビューする労力が前倒しで収束し、人間は near-green を確認するだけになる.

### F2: 満足オラクルによる自律収束

**I want to** 各 step の成果物が `AND(実行可能 AT 緑, reviewing-deliverables の verdict = correct, P0/P1 findings = 0)` を満たすまで `generate → review → fix` が自律反復し、満たしたら次 step へ進む,
**so that** AI が自分の成果物を客観ゲート（実行可能 AT + 独立レビュー）で検証し、false-green なく収束する.

### F3: 安全に失敗する（非収束時の停止と監査）

**I want to** 非収束・予算超過・同一失敗反復を検出して human escalation で停止し（MAX_ITERATIONS / sameness-detector(sha256) / stuck 検出(window=3) / COMPLETED_WITH_DEBT）、各反復の verdict を `docs/issues/<NNN>/autopilot-log.jsonl` に永続化する,
**so that** 無限ループや silent fake-green に陥らず、外部真実源を残して安全に人間へ引き継げる.

### F4: autopilot 専用 Iron Law

**I want to** autopilot モードのとき標準 Iron Law を autopilot 専用 Iron Law（人間ゲート = AC 承認 / merge の2点、AL-1〜6）で上書きする,
**so that** 「承認済み AC なしに実装しない」等と相反する autopilot の動作が、逸脱ではなく正当な設計として扱われる.

## Constraint Story (Non-Functional)

### C1: 既存 skill を恒久変更しない（autopilot モードのみ役割変更）

**I want to** autopilot の実装が既存 skill のロジックを恒久変更せず、autopilot を使った場合のみ役割（人間ゲートの扱い）が変わる（`reviewing-deliverables` の verdict 構造化も後方互換で、通常モードの PASS/FAIL を維持する）,
**so that** 通常フローの利用者に影響を与えず、autopilot は薄い orchestrator に留まる.

### C2: ゼロ依存 + 行数規律

**I want to** 安全レール（sameness-detector の sha256 等）が pure bash + 標準ツールで実装され外部依存がなく、`skills/converging-deliverables/SKILL.md` が埋め込み Workflow script 込みで妥当な行数 budget に収まる,
**so that** atdd-kit のゼロ依存原則と skill 粒度（レビュー単位の見やすさ）が保たれる.

### C3: skill 変更のテスト証拠

**I want to** `converging-deliverables` に Unit Test + Skill E2E Test が付き、`reviewing-deliverables` の verdict 拡張に BATS アサーションが付く,
**so that** skill 変更が構造的に検証され、回帰しない（DEVELOPMENT.md「Skill Changes Require Test Evidence」）.
