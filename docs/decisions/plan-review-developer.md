# Plan Review — Developer

## Issue: #7 — feat: autopilot 完了時に Agent Team を削除する

## Review Criteria

### R1: Target File Coverage — PASS

| File | Necessity | Verdict |
|------|-----------|---------|
| `commands/autopilot.md` L86 (Phase 0.9 Tools annotation) | TeamDelete を Tools リストに追加 — Phase 5 で使用するため必須 | OK |
| `commands/autopilot.md` L90 (Phase 0.9 ToolSearch) | deferred tool のスキーマ事前解決 — 必須 | OK |
| `commands/autopilot.md` L200 (Phase 5 Tools annotation) | TeamDelete を Phase 5 Tools に追加 — 必須 | OK |
| `commands/autopilot.md` L225-227 (Phase 5 steps) | TeamDelete ステップ挿入 — 核心変更 | OK |
| `tests/test_autopilot_agent_teams_setup.bats` | 新テストケース追加 — AC4 に対応 | OK |

**Missing files:** None. `commands/README.md` は機能的変更なし（Team 削除は autopilot.md 内部の Phase 変更であり、コマンドの Purpose 記述を変える必要はない）。CHANGELOG.md と plugin.json のバージョンバンプは Plan の Subtask Checklist (Finishing) にあるので OK。

### R2: Implementation Order Risk — PASS

AC 依存関係: AC1 (ToolSearch) -> AC2 (TeamDelete step) -> AC3 (step ordering) -> AC4 (tests)

この順序は正しい。AC1 は AC2 の前提条件（スキーマ解決なしに TeamDelete は呼べない）。AC3 は AC2 の実装結果を検証する制約。AC4 は全実装完了後のテスト追加。

**Risk:** None identified. 全 AC が単一ファイル (`autopilot.md`) への変更で、並行作業による競合リスクはない。

### R3: Technical Risk — PASS (minor note)

#### TeamDelete の呼び出しタイミング

Plan の配置: `ExitWorktree -> TeamDelete -> git checkout main`

**Verdict: OK.** ExitWorktree は worktree（ファイルシステム）を削除し、TeamDelete はチーム（論理リソース）を削除する。ファイルシステムのクリーンアップを先に行うのは正しい順序。TeamDelete は worktree の有無に依存しないため、ExitWorktree 後でも問題ない。

#### TeamDelete 失敗時の挙動

Plan には TeamDelete 失敗時の明示的なエラーハンドリングが記載されていない。ただし、Phase 5 の時点ではマージ済み・worktree 削除済みであり、TeamDelete の失敗は致命的ではない（orphan team が残るだけ）。autopilot.md は命令的ワークフロー定義であり、各ステップの実行は LLM ランタイムに委ねられるため、明示的な try-catch は不要。

**Minor note:** TeamDelete 失敗時のリカバリについて AC に規定がないため、現在のスコープでは「失敗しても STOP しない（マージ済みのため）」という暗黙の挙動になる。これは妥当。

#### ToolSearch の Phase 0.9 集約

TeamDelete は Phase 5 で初めて使用するが、Phase 0.9 で他の deferred tool と一括してスキーマ解決する設計。これは既存パターン（TeamCreate, SendMessage, EnterWorktree を Phase 0.9 で一括解決）と一貫しており、Phase 5 で別途 ToolSearch を呼ぶよりもシンプル。

### R4: Existing Test Compatibility — PASS

既存テスト (`test_autopilot_agent_teams_setup.bats`) を確認した。主に grep ベースで `autopilot.md` の構造を検証している。

変更が既存テストに影響するケース:
- L86 の Tools annotation 変更: テスト `AC-5: Tools annotation in Phase 0.9` は `**Tools:**` の存在のみチェック → 影響なし
- L200 の Tools annotation 変更: テスト `AC-5: Tools annotation in Phase 5` は `**Tools:**` の存在のみチェック → 影響なし
- L225-227 のステップ番号変更（step 7 → step 8）: 既存テストはステップ番号を grep しておらず → 影響なし

### R5: Step Numbering Impact — PASS

現在の Phase 5:
- Step 6: ExitWorktree (L225)
- Step 7: git checkout main (L226)

変更後:
- Step 6: ExitWorktree
- Step 7: TeamDelete (new)
- Step 8: git checkout main (renumbered)

ステップ 7 の挿入と既存ステップ 7 → 8 への繰り下げは正しい。autopilot.md 内の他フェーズからの Phase 5 ステップ番号参照は存在しないため、繰り下げによる不整合は発生しない。

### R6: Test Strategy — PASS

Plan のテスト戦略（BATS grep ベース）は既存テストパターンと一貫。テストケースとして以下が必要:
- Phase 0.9 ToolSearch に TeamDelete が含まれる (AC1)
- Phase 5 に TeamDelete ステップが存在する (AC2)
- ExitWorktree → TeamDelete → git checkout main の順序 (AC3)

これらは全て grep で検証可能であり、既存テストのアプローチと整合。

## Summary

| Check | Result |
|-------|--------|
| R1: File coverage | PASS |
| R2: Implementation order | PASS |
| R3: Technical risk | PASS |
| R4: Existing test compat | PASS |
| R5: Step numbering | PASS |
| R6: Test strategy | PASS |

**Overall: PASS** — 技術的な懸念なし。Plan はそのまま実装可能。
