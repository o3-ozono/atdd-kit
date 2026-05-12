# Plan: skill テスト体系の再定義（#222）

> 注: B3 (#190 writing-plan-and-tests skill) 未実装期間の手動代行。形式は `templates/docs/issues/plan.md`（superpowers writing-plans 形式）に準拠。

## Implementation

### A. 用語廃止と新体系ドキュメント化

- [ ] `tests/test_defining_requirements_skill.bats` の「Skill Acceptance Test」「BATS gate」記述を「Unit Test」/ 適宜「Skill E2E Test」へ置換
- [ ] verify: `grep -n "Skill Acceptance\|SAT\b" tests/test_defining_requirements_skill.bats` で 0 hit

- [ ] `tests/claude-code/samples/fast-defining-requirements.sh` のヘッダ「Fast-layer Skill Acceptance Test」を「Skill E2E Test (defining-requirements)」に置換
- [ ] verify: 同ファイルに `Skill E2E Test` が含まれ `Skill Acceptance` が含まれない

- [ ] `docs/testing-skills.md` を 2 層体系に書き換え（Unit Test 定義 / Skill E2E Test 定義 / 影響範囲算定ロジック表 / 証跡規約）
- [ ] verify: `grep -nE "(Fast layer|Integration layer|L[123]\b|SAT\b)" docs/testing-skills.md` で 0 hit

- [ ] CHANGELOG.md Unreleased セクションに「Renamed: skill testing terminology (SAT → Skill E2E Test / BATS gate → Unit Test)」を追加（既存 SAT 言及は履歴として保持）
- [ ] verify: CHANGELOG.md 先頭 Unreleased セクションに記載あり

### B. 影響範囲算定 runner

- [ ] `scripts/run-skill-e2e.sh` skeleton 作成（usage / `--help` / `--changed-files`, `--all` フラグ / exit code 0/1/3）
- [ ] verify: `bash scripts/run-skill-e2e.sh --help` で usage 表示、exit 0

- [ ] path-based マッピング関数実装: `skills/<X>/` → `tests/e2e/<X>.bats`、`rules/` / `templates/` / `docs/methodology/` → 全 E2E、`lib/` / `scripts/` → 利用元 skill 列挙
- [ ] verify: `tests/test_run_skill_e2e_impact.bats` の 5 ケース全て green

- [ ] 影響範囲算定結果に基づき対象 E2E を実行しログ (`run-id` / 対象一覧 / PASS-FAIL / git SHA `git rev-parse HEAD` / timestamp ISO8601) を `tests/e2e/.logs/<run-id>.log` に出力
- [ ] verify: dry-run (stub claude) でログファイルが生成され必須フィールド全て含む

### C. 関連 Issue AC 連携

- [ ] #204 (E3 evals 廃止) コメント: 「evals/evals.json は本 Issue 結論 (Skill E2E Test 一本化) と整合、廃止継続」を投稿
- [ ] verify: `gh issue view 204` 最新コメントに本 Issue 番号 #222 への参照あり

- [ ] #207 (F1 docs 更新) コメント: 「testing-skills.md は本 Issue で先行書き換え済み、F1 では本 Issue 結論との整合確認 AC を追加」
- [ ] verify: `gh issue view 207` 最新コメントに本 Issue 結論への参照あり

- [ ] #208 (G1 CI 整備) コメント: 「ジョブ名を `skill-e2e-test` 系に改題、対象を path-based 影響範囲算定済み E2E に限定する形で再記述」
- [ ] verify: `gh issue view 208` 最新コメントに改題提案 + 改 AC 案あり

- [ ] #196 (C1 SAT 揃い検証) コメント: 「『揃い』が指すのは Unit Test (BATS) + Skill E2E Test (1 skill = 1 ファイル) の両方、AC 再記述案を提示」
- [ ] verify: `gh issue view 196` 最新コメントに本 Issue 結論への参照あり

## Testing

- [ ] `tests/test_run_skill_e2e_impact.bats` を Unit Test として書く（path-based マッピング 5 ケース: skill 単独 / rules/ / templates/ / lib/ / scripts/）
- [ ] verify: `bats tests/test_run_skill_e2e_impact.bats` 全 case green

- [ ] `tests/test_skill_terminology_grep.bats` を Unit Test として書く（CHANGELOG.md 以外で旧用語が出現しないことを検証）
- [ ] verify: `bats tests/test_skill_terminology_grep.bats` green

## Finishing

- [ ] PR #224 description を本 Plan に合わせて更新（Step 2-3 手動代行の経緯、確定設計判断、関連 Issue 連携状況を記載）
- [ ] verify: PR #224 description に本 Issue 結論 + 関連 4 Issue リンクが含まれる

- [ ] PR #224 を Draft → ready 化（reviewer 引き渡し）
- [ ] verify: `gh pr view 224 --json isDraft` で `isDraft=false`
