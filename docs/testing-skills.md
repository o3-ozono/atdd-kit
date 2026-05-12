# Testing Skills

atdd-kit の skill テスト体系。**Unit Test** と **Skill E2E Test** の 2 層に統一されている。

> v1.0 で旧用語（SAT / L1-L3 / Fast layer / Integration layer）は廃止された（#222）。本文書がテスト体系の単一の正典。

## (a) 2 層の定義

| 層 | claude 起動 | 検証対象 | 場所 | 失敗時ゲート | 想定コスト/回 |
|---|----------|---------|-----|------------|------|
| **Unit Test** | ❌ 呼ばない | SKILL.md の構造（行数 / 出力 path 言及 / 上下流名）、shell script ロジック、grep ベースの用語規約 | `tests/*.bats` | CI `skill-tests` ジョブ FAIL | $0 |
| **Skill E2E Test** | ✅ `claude -p` を呼ぶ | LLM が SKILL.md を読んで規定の挙動を返すか（キーワード抽出 / 上下流順序 / multi-turn 振る舞い） | `tests/e2e/<skill>.bats` | reviewing-deliverables 引き渡し前ゲート（local 必須、CI 任意） | ~$0.10–$5 |

**境界:** `claude` バイナリを呼ぶか呼ばないかが唯一の分類軸。stub claude や jsonl リプレイは Unit Test 側に分類される。

## (b) Skill E2E Test の構造（1 skill = 1 ファイル、1 User Story = 1 case）

`tests/e2e/<skill>.bats` 1 ファイルに、各 User Story 1 つを 1 個の `@test` ブロックで対応させる。テスト名は User Story の Connextra そのもの。

```bash
#!/usr/bin/env bats
# tests/e2e/defining-requirements.bats
# @covers: skills/defining-requirements/SKILL.md

setup() {
  : "${CLAUDE_BIN:?CLAUDE_BIN must be set or claude in PATH}"
}

@test "I want to read the SKILL.md and recover the 6 PRD sections, so that section coverage is verified" {
  out=$(claude -p --max-turns 1 --permission-mode bypassPermissions <<EOF
List the six PRD sections defined in this skill, in order.

$(cat skills/defining-requirements/SKILL.md)
EOF
  )
  [[ "$out" =~ Problem ]]
  [[ "$out" =~ "Why now" ]]
  [[ "$out" =~ Outcome ]]
  [[ "$out" =~ What ]]
  [[ "$out" =~ "Non-Goals" ]]
  [[ "$out" =~ "Open Questions" ]]
}

@test "I want to see upstream session-start cited before downstream extracting-user-stories, so that chain order is preserved" {
  # ...
}
```

User Stories は `docs/issues/<NNN>/user-stories.md` に定義された Functional Story / Constraint Story を 1:1 で写す。`extracting-user-stories` skill (#189) 完成後は User Story 抽出と E2E `@test` 生成が同一フォーマットで連動する。

## (c) 影響範囲算定ロジック（path-based）

変更ファイルから影響を受ける skill を **`scripts/run-skill-e2e.sh`** が path-based マッピングで自動算定する。

| 変更ファイルの prefix | 影響範囲 |
|-------------------|---------|
| `skills/<X>/...` | `tests/e2e/<X>.bats` のみ |
| `rules/...`, `templates/...`, `docs/methodology/...` | 全 `tests/e2e/*.bats` |
| `lib/<file>`, `scripts/<file>` | SKILL.md が当該 file を参照する全 skill の E2E |
| その他 | 影響なし（実行対象 0） |

```bash
# skill 1 つ変更（軽量）
scripts/run-skill-e2e.sh --changed-files skills/defining-requirements/SKILL.md

# 共有資材変更（全 E2E）
scripts/run-skill-e2e.sh --changed-files rules/atdd-kit.md

# 複数ファイル
scripts/run-skill-e2e.sh --changed-files skills/foo/SKILL.md,scripts/bar.sh

# 全実行
scripts/run-skill-e2e.sh --all

# 対象列挙のみ（実行しない）
scripts/run-skill-e2e.sh --changed-files <list> --dry-run
```

## (d) 証跡コメント規約（reviewing-deliverables 引き渡しゲート）

atdd-kit 自体の修正 PR では、reviewing-deliverables への引き渡し前に **影響範囲分の Skill E2E Test all green ログを PR コメントに貼付する** ことが必須。

### 必須フィールド

`scripts/run-skill-e2e.sh` が `tests/e2e/.logs/<run-id>.log` に出力する 5 フィールド:

| フィールド | 値の例 |
|----------|------|
| `run-id` | `20260512T083000Z-12345` |
| `git_sha` | `git rev-parse HEAD` の結果（最新コミット SHA） |
| `timestamp` | ISO8601 `2026-05-12T08:30:00Z` |
| `targets` | 対象 `tests/e2e/*.bats` の列挙 |
| `results` + `summary` | 各 target の `PASS` / `FAIL` + `summary: PASS (N/N)` |

### 検証側（reviewing-deliverables skill）

reviewer は次を確認する:

1. PR コメントに最新ログが貼付されているか
2. ログ内の `git_sha` が PR HEAD と一致するか（古いログでの merge を防ぐ）
3. `summary: PASS (N/N)` で `FAIL` が 0 件か

`git_sha` 不一致なら **変更後に再実行が必要**。reviewer はその場で差し戻す。

### コメント運用ルール（最新 1 件を update）

PR 内に **証跡コメントは 1 つだけ** 保持し、追加 commit ごとに同じコメントを update する。複数のログコメントを並べない。

1. 最初の動作実証時に新規コメントを投稿（タイトルは `## Skill E2E Test 証跡`）
2. 追加 commit ごとに同じコメントを `gh api -X PATCH /repos/{owner}/{repo}/issues/comments/{comment_id}` で update
3. 古い証跡コメントが残っている場合は `gh api -X DELETE ...` で削除
4. コメント本文に `Updated: <ISO8601>` と最新 `git_sha` を含めて、history は git ログで追う

ねらい: PR レビュアーが「どれが最新ログか」を判断する手間を取り除く。`git_sha` は 1 件のコメントを見れば一意に決まる。

### 配布プロジェクトでの扱い

atdd-kit を **適用するプロジェクト**（プラグイン利用者）は本ゲートの対象外。本ゲートは atdd-kit リポジトリ自身の修正 PR にのみ適用される。

## (e) Unit Test の追加

1. `tests/test_<topic>.bats` を作成（テンプレート: `tests/test_bats_runner.bats` 参照）
2. `bats tests/test_<topic>.bats` で local 実行
3. PR で `skill-tests` ジョブが自動実行

## (f) Skill E2E Test の追加

1. `tests/e2e/<skill>.bats` を作成（1 skill = 1 ファイル、`@covers: skills/<skill>/SKILL.md` ヘッダ）
2. 対応する User Stories を `docs/issues/<NNN>/user-stories.md` から 1 US = 1 `@test` で写す
3. local 実行: `bash scripts/run-skill-e2e.sh --changed-files skills/<skill>/SKILL.md`
4. 全 green を確認後、ログを PR コメントに貼付
5. 変更後の追加 commit でも **同じ手順で再実行 → 最新ログを再投稿**

## (g) Cost Baseline

| 層 | 想定コスト/回 |
|---|--------------|
| Unit Test | $0 |
| Skill E2E Test (1 skill) | ~$0.10 |
| Skill E2E Test (全 skill, `--all`) | ~$5.00 |

Skill E2E Test は影響範囲算定で対象を絞るのが基本。全実行は `rules/` / `templates/` / `docs/methodology/` 変更時に自動的に発生する。

## (h) Exit Codes（`scripts/run-skill-e2e.sh`）

| Code | 意味 |
|------|------|
| 0 | PASS / dry-run 成功 / 影響範囲 0 件 |
| 1 | 1 つ以上の Skill E2E Test FAIL |
| 3 | usage / infra error（フラグ不正、bats バイナリ未設置等） |

## (i) GH_TOKEN

Skill E2E Test 内で `gh` を呼ぶ場合、`.claude/settings.local.json` の `env.GH_TOKEN` を使う。Token はトランスクリプトに書き込まれないこと、verbose mode でも mask されることを Unit Test で検証する。
