# Plan: extracting-user-stories skill (Step B2)

## Implementation

- [ ] `skills/extracting-user-stories/SKILL.md` 本実装（frontmatter + Trigger / Input / Output / Flow / Responsibility Boundary / Integration）
- [ ] verify: `wc -l` で 200 行以下、`defining-requirements` と同じセクション構成、HARD-GATE が削除されている

- [ ] `templates/docs/issues/user-stories.md` を必要に応じて補強（現状で persona 痕跡なし / Constraint Story 例入り。差分があれば微修正）
- [ ] verify: `grep -i 'as a ' templates/docs/issues/user-stories.md` が空、Constraint Story セクション存在

## Testing

- [ ] `tests/test_extracting_user_stories_skill.bats` 新規追加（frontmatter / セクション / 行数 / persona 痕跡なし / Constraint Story セクションを検証）
- [ ] verify: `bats tests/test_extracting_user_stories_skill.bats` green

- [ ] `tests/test_v1_skill_skeletons.bats` の skeleton 件数を 1 減らして整合
- [ ] verify: `bats tests/test_v1_skill_skeletons.bats` green

## Finishing

- [ ] `CHANGELOG.md` の `[Unreleased]` に「extracting-user-stories skill 実装 + SAT」エントリ追記
- [ ] verify: `CHANGELOG.md` を Keep a Changelog 形式で更新

- [ ] ドキュメント整合性チェック（`rules/atdd-kit.md`, `CLAUDE.md` 不要更新）
- [ ] verify: 関連ドキュメントの記述が変更と整合
