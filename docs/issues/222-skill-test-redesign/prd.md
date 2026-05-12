# PRD: skill テスト体系の再定義（SAT 廃止 / Skill E2E Test 導入）

## Problem

「SAT / L1-L3」が atdd-kit 独自で参考プロジェクトに前例なし、書かれても実 claude で実行されない fast-*.sh が merge され、`evals/evals.json` 廃止予定 (#204) と現役運用 (`/atdd-kit:auto-eval`) が衝突。結果、レビュー基準がブレ、関連 4 Issue (#204/#207/#208/#196) の AC が宙に浮く。

## Why now

Step B 系列 7 PR (#189-#195) が並列着手可能な状態で待機しており、未確定のまま進めると #188/#221 同様の死蔵テスト merge が再発する。「SAT」実出現は現状 5 箇所のみで廃止コストが最も低い時期。

## Outcome

skill テストを **Unit Test (claude 呼ばない)** と **Skill E2E Test (実 claude 起動)** の 2 層に再定義。atdd-kit 自体の修正時、ATDD ループ外側で「影響範囲分の Skill E2E Test all green + git SHA 一致ログ」が reviewer 引き渡しの強制ゲートとして成立し、その後の追加変更でも local で再 pass が必須化された状態。

## What

- skill テストを「Unit Test (BATS, claude 呼ばない)」「Skill E2E Test (実 claude 起動)」の 2 層に統一、旧用語 (SAT / L1-L3 / Fast / Integration) を CHANGELOG.md 以外から全廃
- 影響範囲算定: **path-based マッピング** — `skills/<X>/` 変更 → 対応 E2E、`rules/` `templates/` `methodology/` 変更 → 全 E2E、`lib/` `scripts/` 変更 → 利用元 skill の E2E
- atdd-kit 自体の修正で reviewing-deliverables 引き渡し前に「影響範囲分 E2E all green + git SHA 一致ログ」を PR コメント必須化（証跡主義）
- **1 skill = 1 E2E ファイル**、内部 `@test "I want to X, so that Y" { ... }` で 1 User Story = 1 case
- 専用 runner `scripts/run-skill-e2e.sh` を整備（影響範囲算定 + 対象 E2E 実行 + ログ生成）
- `evals/evals.json` 系は #204 で廃止、Skill E2E Test に一本化
- 旧用語廃止 + #204/#207/#208/#196 の AC 再記述案を本 Issue 配下で提示

## Non-Goals

- CI workflow 実装変更 → #208 (改題)
- `testing-skills.md` 本文最終書き換え → #207 または別 PR
- `fast-*.sh` / `integration-*.sh` のリネーム / 統廃合 → 結論後別 PR
- stub claude false-positive 対処 → Skill E2E Test 整備で自然解消の可能性、結論後別 Issue

## Open Questions

1. `scripts/run-skill-e2e.sh` runner の入出力仕様詳細（writing-plan-and-tests で確定）
2. PR コメントへのログ貼付フォーマット詳細（reviewing-deliverables skill 設計時に確定）
