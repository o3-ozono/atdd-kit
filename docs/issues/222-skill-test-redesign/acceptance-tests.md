# Acceptance Tests: skill テスト体系の再定義（#222）

> 注: B3 (#190) 未実装期間の手動代行。形式は `templates/docs/issues/acceptance-tests.md`（state marker: planned/draft/green/regression）に準拠。FS / CS は `user-stories.md` 参照。

## AT-001: 旧用語が active source から消えている (FS-1)

- [x] [green] AT-001: terminology grep test
  - **Given:** atdd-kit リポジトリ HEAD
  - **When:** `grep -rn "SAT\b\|Skill Acceptance\|Fast layer\|Integration layer\|L1 BATS\|L2 Fast\|L3 Integration\|BATS gate\|Fast SAT\|Integration SAT" --include="*.md" --include="*.sh" --include="*.bats" --include="*.yml" .` を以下除外で実行: `CHANGELOG.md`（履歴）、`docs/testing-skills.md`（廃止宣言を含む正典）、`docs/issues/222-skill-test-redesign/`（本 Issue 議論）、`docs/issues/179-*/`（epic）
  - **Then:** 0 hit (exit 1)

## AT-002: path-based 影響範囲算定 — 単一 skill 変更 (FS-2)

- [x] [green] AT-002: impact mapping for skill change
  - **Given:** `scripts/run-skill-e2e.sh` が存在し path-based マッピング実装済み
  - **When:** `bash scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md --dry-run`
  - **Then:** stdout に `tests/e2e/defining-requirements.bats` のみが対象として列挙される

## AT-003: path-based 影響範囲算定 — 共有資材変更 (FS-2 / CS-3)

- [x] [green] AT-003: impact mapping for shared assets
  - **Given:** `scripts/run-skill-e2e.sh` 実装済み
  - **When:** `bash scripts/run-skill-e2e.sh --changed-files rules/atdd-kit.md --dry-run`
  - **Then:** stdout に `tests/e2e/` 配下の **全 .bats** が対象として列挙される

## AT-004: runner ログに必須フィールド (FS-3 / CS-2)

- [x] [green] AT-004: runner log fields
  - **Given:** stub claude で `scripts/run-skill-e2e.sh` を実行
  - **When:** ログファイル `tests/e2e/.logs/<run-id>.log` を読む
  - **Then:** `run-id` / `target list` / `PASS-FAIL` / `git SHA (== git rev-parse HEAD)` / `timestamp (ISO8601)` の 5 フィールドが全て含まれる

## AT-005: PR コメント証跡フォーマット仕様の明示 (FS-4)

- [x] [green] AT-005: reviewer handoff log spec documented
  - **Given:** `docs/testing-skills.md` 書き換え後
  - **When:** 「証跡コメント規約」セクションを読む
  - **Then:** 必須フィールド (`git SHA` / `target list` / `PASS-FAIL summary`)、配置 (PR コメント貼付)、検証側 (`reviewing-deliverables` skill)、**コメント運用ルール (最新 1 件を update、旧コメントは delete)** の 4 点が明示されている

## AT-006: 1 skill = 1 E2E ファイル / 1 US = 1 case 構造の例示 (FS-5)

- [x] [green] AT-006: e2e structure example documented
  - **Given:** `docs/testing-skills.md` 書き換え後
  - **When:** 「Skill E2E Test 構造」セクションを読む
  - **Then:** `tests/e2e/<skill>.bats` 内部に `@test "I want to <goal>, so that <reason>" { ... }` を 1 US = 1 case で配置する例（最低 1 つの完全なスニペット）が含まれる

## AT-007: 関連 4 Issue にコメント連携済み (FS-6)

- [x] [green] AT-007: cross-issue propagation
  - **Given:** PR #224 ready 化前
  - **When:** `gh issue view <N> --comments` を #204 / #207 / #208 / #196 に対して実行
  - **Then:** 4 Issue それぞれの最新コメントに `#222` への参照と本 Issue 結論に基づく AC 更新案が含まれる

## AT-008: evals 廃止依存なし (CS-1)

- [x] [green] AT-008: no evals dependency
  - **Given:** `scripts/run-skill-e2e.sh` 実装後
  - **When:** `grep -n "evals\|skill-creator" scripts/run-skill-e2e.sh`
  - **Then:** 0 hit（evals/evals.json 系に依存しない）

## AT-009: runner ログに git SHA 必須 (CS-2)

- [x] [green] AT-009: git sha mandatory in log
  - **Given:** `scripts/run-skill-e2e.sh` を `--changed-files <X>` 付きで実行
  - **When:** 出力ログから `git_sha` フィールドを抽出
  - **Then:** 値が `git rev-parse HEAD` の結果と完全一致

## AT-010: 共有資材変更時のみ全実行 (CS-3)

- [x] [green] AT-010: full-run gating
  - **Given:** path-based マッピング実装済み
  - **When:** `bash scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md --dry-run` を実行
  - **Then:** 全 E2E 実行にならず単一 skill のみが対象（`rules/templates/methodology` 変更時の挙動と異なることを確認）

## ライフサイクル

| 状態 | 意味 |
|------|------|
| [planned] | テスト設計済み・未実装（本ファイル現在の状態） |
| [draft] | 実装中・まだ通過していない |
| [green] | テスト通過済み |
| [regression] | リグレッション対象として継続監視中 |
