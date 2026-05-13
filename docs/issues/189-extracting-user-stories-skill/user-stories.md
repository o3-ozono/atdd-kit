# User Stories: extracting-user-stories skill (Step B2)

## Functional Story

### F1: PRD から User Stories を再現性ある形で抽出

**I want to** PRD (`docs/issues/<NNN>/prd.md`) から persona 抜き Connextra Story と Constraint Story を半自動で抽出して `docs/issues/<NNN>/user-stories.md` に保存できる,
**so that** AT 作成の入力となる中間アーティファクトが揃い、後工程の網羅性が安定する.

### F2: Story 候補を一括でレビューして承認

**I want to** skill が抽出した Story 候補を一括で提示してもらい、まとめて確認・修正・承認できる,
**so that** 1 件ずつの問答よりレビュー負荷が小さく、思考のフローを止めずに進められる.

## Constraint Story (Non-Functional)

### C1: SKILL.md の行数制約

**I want to** `skills/extracting-user-stories/SKILL.md` が 200 行以内に収まっている,
**so that** 他の capability-name skill と粒度が揃い、レビュー単位の見やすさが保たれる.

### C2: 出力言語の固定

**I want to** 生成される `user-stories.md` の本文が日本語のみで出力される,
**so that** #223 の i18n 廃止方針と整合し、ユーザーの読解負荷が一定になる.

### C3: persona 表記の不採用

**I want to** 出力に `As a [persona]` 形式が一切現れない,
**so that** #216 / #218 の persona 不採用判断と機構として一致する.
