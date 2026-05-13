# Acceptance Tests: extracting-user-stories skill (Step B2)

## AT-001: PRD から User Stories を抽出 (F1)

- [ ] [planned] AT-001: skill 実行で PRD から US が生成される
  - Given: `docs/issues/<NNN>/prd.md` が存在し Section What が記述されている
  - When: `/atdd-kit:extracting-user-stories <NNN>` を実行する
  - Then: `docs/issues/<NNN>/user-stories.md` が生成され、`## Functional Story` と `## Constraint Story` の両セクションを含む

## AT-002: Story 候補の一括レビュー (F2)

- [ ] [planned] AT-002: skill が Story 候補を 1 回のメッセージで一括提示する
  - Given: skill が PRD を読み込み Story 候補を生成した
  - When: skill がユーザーに提示する
  - Then: 1 ターン内に全候補が提示され、ユーザーが `ok` を返すと書き出しに進む（1 件ずつの問答 loop が発生しない）

## AT-003: SKILL.md 行数制約 (C1)

- [ ] [planned] AT-003: SKILL.md は 200 行以内
  - Given: リポジトリに `skills/extracting-user-stories/SKILL.md` がある
  - When: `wc -l < skills/extracting-user-stories/SKILL.md` を実行する
  - Then: 値が `200` 以下

## AT-004: 出力言語固定 (C2)

- [ ] [planned] AT-004: SKILL.md が出力言語を日本語に固定するルールを含む
  - Given: SKILL.md が存在する
  - When: ファイル本文を検査する
  - Then: 「出力言語: 日本語」相当の指示が記述されている（Connextra 句 `I want to / so that` は形式句として許容）

## AT-005: persona 表記の不在 (C3)

- [ ] [planned] AT-005: 出力に `As a [...]` パターンが現れない
  - Given: SKILL.md および `templates/docs/issues/user-stories.md`
  - When: `grep -rE '^As a ' skills/extracting-user-stories/ templates/docs/issues/user-stories.md` を実行する
  - Then: マッチが 0
