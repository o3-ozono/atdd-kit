# Acceptance Tests — #275 Diff-in-body

実体は `tests/test_autopilot_skill.bats` の `--- Diff-in-body (#275) ---` 節（pin 4 件）。対象は `skills/autopilot/SKILL.md` の `## Flow` 節。

| AT | 対応 AC | 検証内容 | BATS test |
|----|---------|----------|-----------|
| AT-001 | AC-1 | 再提示は finding ごとの diff ブロック + key lines を、セッション内 + GitHub ゲートコメント両方の本文に含む | `diff-in-body (#275): AT-001` |
| AT-002 | AC-2 | 初回提示は key decisions を file/line 参照付きで提示し、summary-only gate を禁止する | `diff-in-body (#275): AT-002` |
| AT-003 | AC-3 | マージハンドオフは実装 diff（per-file stat + key hunks）を本文に含み、green ステータス要約のみを禁止する | `diff-in-body (#275): AT-003` |
| AT-004 | AC-4 | key lines / key decision の操作的定義が Flow 節に存在する | `diff-in-body (#275): AT-004` |

実行: `bats tests/test_autopilot_skill.bats`（#276 修正時点で 57 件 green）
