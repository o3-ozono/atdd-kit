# Acceptance Tests — #275 Diff-in-body

実体は `tests/test_autopilot_skill.bats` の `--- Diff-in-body (#275) ---` 節（境界 canary AT-000 + pin 5 件）。対象は `skills/autopilot/SKILL.md` の `## Flow` 節（AT-001〜AT-004）と `## Dialog economy` 節（AT-005）。

| AT | 対応 AC | 検証内容 | BATS test |
|----|---------|----------|-----------|
| AT-001 | AC-1 | 再提示は finding ごとの diff ブロック + key lines を、セッション内 + GitHub ゲートコメント両方の本文に含む | `diff-in-body (#275): AT-001` |
| AT-002 | AC-2 | 初回提示は key decisions を file/line 参照付きで提示し、summary-only gate を禁止する | `diff-in-body (#275): AT-002` |
| AT-003 | AC-3 | マージハンドオフは実装 diff（per-file stat + key hunks）を本文に含み、green ステータス要約のみを禁止する | `diff-in-body (#275): AT-003` |
| AT-004 | AC-4 | key lines / key decision の操作的定義が Flow 節に存在する | `diff-in-body (#275): AT-004` |
| AT-005 | AC-1/制約 | #267/#275 の調停句が Flow 節と Dialog economy 節の両方に pin されている | `diff-in-body (#275): AT-005` |
| US-1 E2E | AC-1 | 実 `claude -p` が SKILL.md から再提示時の diff-in-body 挙動（diff ハンク / finding 単位 / 両チャネル）を回復する | `tests/e2e/autopilot.bats` の `US-1 (#275)` |

静的 pin（文言の存在と極性）と E2E（LLM の挙動回復）の二層で検証する。実セッションでのゲート提示そのものはテスト境界外（乖離は skill-fix で還流）。

実行: `bats tests/test_autopilot_skill.bats` + `bats tests/e2e/autopilot.bats`
