# PRD: extracting-user-stories skill (Step B2)

> Issue: #189
> 作成日: 2026-05-12
> 担当: @o3-ozono

## Problem

- atdd-kit ユーザーは `defining-requirements` で PRD を書いた後、それを Acceptance Test の入力（Step 3）に繋ぐ中間ステップ（User Stories 抽出）を手作業で行うしかない。
- 結果、persona 視点に流れる / Story 粒度がバラつく / 制約 (NFR) の Story 化を忘れる、といったムラが生じ、後工程の AT 網羅性に影響する。

## Why now

- B1 (#221) で `defining-requirements` が main 投入され、Step 2 の入力（PRD）が initial の段階で揃った。
- このタイミングを逃すと、ユーザーは PRD → AT を直結する旧来の作り方を続けてしまい、新フローの「PRD → US → Plan+AT」という再現性ある経路が完成しないまま開発が進む。

## Outcome

- atdd-kit ユーザーが PRD から **再現性ある形で** persona 抜き Connextra Story と制約 Story (NFR) を抽出できる。
- 抽出された User Stories が `docs/issues/<NNN>/user-stories.md`（日本語）に保存され、後続 `writing-plan-and-tests` (Step 3) の入力として安定的に使える。

## What

- `/atdd-kit:extracting-user-stories <issue>` skill：PRD を読み込み、Story 候補を **一括で提示** してユーザーに承認させ、`docs/issues/<NNN>/user-stories.md` に書き出す。
- 出力形式：persona 抜き Connextra (`I want to <goal>, so that <reason>`) と制約 Story の混在を許容。出力言語は **日本語固定**。
- skill 構造は `defining-requirements` と同じ流儀（capability-name skill、≤ 200 行）に揃え、ユーザーが学習コストなく使える。

## Non-Goals

- persona の任意化 / INVEST チェック / Story Splitting 自動化 / Example Mapping の取り込み（v1.0 不採用が確定）。
- ユーザーが手編集した `user-stories.md` の resume / 差分更新（`defining-requirements` と同じ「再実行は上書き」方針）。

## Open Questions

- none remain.
