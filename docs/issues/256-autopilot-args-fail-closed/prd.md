# PRD: autopilot 埋め込み Workflow script の args fail-closed 化（#252 先行対処後の残差分）

## Problem

- **現状**: Workflow ツールに渡した args が JSON 文字列のまま届く事象が #251 design phase で実発生。`args.issue` / `args.phase` が `undefined` になり、gen / review エージェントは worktree 名からの推測で動作（偶然のリカバリ）、audit は phantom dir を解決できず `COMPLETED_WITH_DEBT (record-error)` で停止した。
- **それによって困ること**: `PHASE` は `'impl'` 以外 → `'design'` フォールバックのため、**impl 実行時に文字列 args だと design に化ける**（設計承認ゲートの意味を壊す誤動作の温床）。推測で走ること自体が AL-2（anchor 接地）違反。

## Why now

- #252（PR #253、v3.7.2）で対応案 1・2 — 入力正規化（`typeof args === 'string' ? JSON.parse(args) : (args || {})`）と `Number.isInteger(NNN)` の fail-closed throw、およびその BATS pin — は**先行実装済み**。
- 残差分（phase の明示必須化）が未対応のまま impl 運用に入ると、最も危険な「impl→design 化け」だけが残る。#254 と合わせて autopilot 運用本格化の前提。

## Outcome

- 不正・欠落 args では収束ループが 1 イテレーションも走らない（fail-closed）。
- `phase` 未指定・不正値で即 throw（フォールバック既定値の廃止）。
- 全ガード（parse / issue / phase）が BATS で pin され、回帰で無言に消えない。

## What

- `skills/autopilot/SKILL.md` 埋め込み Workflow script: `A.phase !== 'design' && A.phase !== 'impl'` なら throw（`const PHASE = A.phase === 'impl' ? 'impl' : 'design'` のフォールバック廃止）。
- `tests/test_autopilot_skill.bats` に phase ガードの pin を追加（parse / issue ガードの pin は #252 で導入済み）。
- SKILL.md の Flow 節の invoke 指示へ「args は JSON オブジェクトとして渡す（文字列化した JSON を渡さない）」注記。

## Non-Goals

- Workflow ツール（harness）側の args 直列化挙動の修正 — プラグイン管轄外。ツール側が直っても script 側ガードは防御として残す（Issue 備考どおり）。
- `lib/autopilot_convergence.sh` の変更 — 監査ログ堅牢化は #248 のスコープ。
- #252 で導入済みの parse / issue ガードの再実装 — 本 Issue は残差分のみ。

## Open Questions

- なし（対応方針は Issue 本文で確定済み。#252 で先行実装された分との差分は本 PRD の What / Why now に反映済み。2026-06-10 Gate ① 承認）。
