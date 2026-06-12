# Plan: express skill の再導入 — 機能破壊リスクのないドキュメント級タスクの省略経路

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> **前提:** PRD の Open Questions 3 点（発動形態 / skill-gate 統合方式 / 旧 PR #96 再利用度）は
> `docs/issues/284-express-skill/design-doc.md` で確定済み。本 Plan はその決定
> （D1: コマンド起動のみ、D2: skill-gate 側 SKILL.md を編集、D3: 旧 #96 の骨格を流用し
> 自動 merge を撤去・適用基準は SKILL.md に内蔵）を前提とする。

## Implementation

### skills/express/SKILL.md 新設（v1.0 最小構成・英語・200 行以内）

- [ ] `skills/express/` ディレクトリを作成し、SKILL.md の frontmatter を書く（`name: express`、`description` はトリガー条件のみ: "Use when explicitly invoked via /atdd-kit:express for trivial, documentation-grade changes..." — ワークフロー要約は書かない）
- [ ] verify: `scripts/lint_skill_descriptions.sh` が express に VIOLATION を出さない / `grep -q '^name: express' skills/express/SKILL.md`

- [ ] Step 1（入力検証）を書く: Issue 番号必須（なしは起動エラーで STOP = AC3）、`gh issue view` で not found / closed / `in-progress` 付きを STOP
- [ ] verify: Issue 番号必須のエラーメッセージと STOP 分岐 3 種（not found / closed / in-progress）が grep で確認できる

- [ ] Step 2（適用基準チェック + 発動承認）を書く: OK 例 / NG 例の表を SKILL.md に内蔵（OK: docs/README 追記・typo・コメント・gitignore・バージョン bump のみ等 / NG: 新機能・振る舞い変更・依存追加・CI/hooks 変更・セキュリティ影響等）、「迷ったらフルフロー（`/atdd-kit:defining-requirements <n>`）」を明記、`<APPROVAL-GATE>` でユーザの明示的承認 + 該当 OK 基準（理由）の取得を必須化（AC1/AC2）
- [ ] verify: `grep -q '<APPROVAL-GATE>' skills/express/SKILL.md` && OK/NG 双方の基準と `defining-requirements` へのフォールバック記述が grep で確認できる

- [ ] Step 3（最短実行）を書く: `express/<n>-<slug>` ブランチ作成 → 実装 → conventional commit → push。中間成果物（`docs/issues/<NNN>/` 配下の PRD/US/plan/AT/レビューレポート）を作らないことを明記。対象リポジトリが atdd-kit 自身の場合の AC7（plugin.json version bump + CHANGELOG 更新は省略不可）を含める
- [ ] verify: `grep -q 'express/<' skills/express/SKILL.md` && version bump / CHANGELOG の記述が grep で確認でき、`docs/issues/` 成果物を生成する手順が存在しない

- [ ] Step 4（PR 作成）を書く: `express-mode` ラベル付与 + PR body 固定セクション `## Express Mode`（該当した OK 基準 = 理由を記録）。ラベル欠落時は `/atdd-kit:setup-github` を案内（AC5/AC6）
- [ ] verify: `grep -q 'express-mode' skills/express/SKILL.md` && `grep -q '## Express Mode' skills/express/SKILL.md`

- [ ] Step 5（CI ゲートと人間 merge）を書く: `<HARD-GATE>` で CI green まで merge 不可（AC4）、merge は人間が行う — skill 内に `gh pr merge` の自動実行手順を置かない（PRD Non-Goal / CS-1）
- [ ] verify: `grep -q '<HARD-GATE>' skills/express/SKILL.md` && SKILL.md に自動 merge を実行する手順（`gh pr merge`）が存在しない

- [ ] スコープ逸脱フォールバック（AC9）を書く: 実装中に diff が適用基準を超えたら（コードファイル接触等）express を中断し、フルフロー（`/atdd-kit:defining-requirements <n>`）への切り替えを利用者に報告。Red Flags 表（承認なし開始・CI バイパス・ラベル/理由欠落・スコープ超過続行）を最後に置く
- [ ] verify: 逸脱時の中断 + 報告 + フルフロー誘導が grep で確認できる / `grep -qi 'red flag' skills/express/SKILL.md`

- [ ] SKILL.md 全体を読み直し、AC が要求しないゲート・成果物テンプレート・多段承認が混入していないこと（CS-3）と行数を確認する
- [ ] verify: `wc -l < skills/express/SKILL.md` が 200 以下 / 承認ゲートが APPROVAL-GATE（発動承認）の 1 つだけである

### コマンドエントリと skill-gate 統合

- [ ] `commands/express.md` を新設する（skill-fix 形式の薄いエントリ: description frontmatter + Usage + skills/express/SKILL.md への委譲 + When (NOT) to Use の要約）
- [ ] verify: `test -f commands/express.md` && `grep -q 'atdd-kit:express' commands/express.md`

- [ ] `skills/skill-gate/SKILL.md` の Pre-check: Issue Work Routing に express 分岐を追加する: 明示的な `/atdd-kit:express <issue>` 発動は正規ルートとして認識し defining-requirements へ誘導しない（Issue 必須のため Iron Law #1 とも整合 = AC8）。Parallel Collision Detection は express 開始時にも適用する
- [ ] verify: `grep -q 'express' skills/skill-gate/SKILL.md` && 編集前後で `bats tests/test_skill_gate_collision.bats` が green

- [ ] `commands/setup-github.md` のラベル作成ブロックに `gh label create "express-mode" --color "FEF2C0" --description "PR created via /atdd-kit:express fast path" --force` を追加する（AC5 の前提整備）
- [ ] verify: `grep -q 'express-mode' commands/setup-github.md`

## Testing

- [ ] `tests/test_express_skill.bats` を新設する（`# @covers: skills/express/SKILL.md` ヘッダ付き）。`docs/issues/284-express-skill/acceptance-tests.md` の AT-001〜AT-010 に対応する構造アサーション（APPROVAL-GATE / OK・NG 基準 / Issue 必須 / HARD-GATE CI / 自動 merge 不在 / express-mode ラベル / `## Express Mode` セクション / version bump + CHANGELOG / skill-gate の express 認識 / 逸脱フォールバック / 200 行以内 / 中間成果物生成手順の不在）を書く
- [ ] verify: `bats tests/test_express_skill.bats` が green

- [ ] `tests/test_skill_structure.bats` の `ALL_SKILLS` 配列に `express` をアルファベット順で追加する（"ALL_SKILLS matches actual skill directories" の保全）
- [ ] verify: `bats tests/test_skill_structure.bats` が green

- [ ] 影響範囲のテストを一括実行する: `bats tests/test_skill_structure.bats tests/test_skill_description_lint.bats tests/test_skill_gate_collision.bats tests/test_express_skill.bats tests/test_check_bats_covers.bats`
- [ ] verify: 上記すべて green

## Finishing

- [ ] `skills/README.md` の Skill List（Infrastructure もしくは適切な節）に express の行を追加する（Trigger: `/atdd-kit:express` 明示発動のみ / docs 級タスクの省略経路である旨）
- [ ] verify: `grep -q 'express' skills/README.md`

- [ ] `commands/README.md` の Command List に `/atdd-kit:express` の行を追加する
- [ ] verify: `grep -q 'express' commands/README.md`

- [ ] `tests/README.md` に `test_express_skill.bats` をアルファベット順で追加する
- [ ] verify: `grep -q 'test_express_skill' tests/README.md` && 既存の並び順が崩れていない

- [ ] `CHANGELOG.md` の `[Unreleased]` に Added エントリを書き、`.claude-plugin/plugin.json` を `3.13.1` → `3.14.0` に minor bump する（新規 skill 追加 = minor、DEVELOPMENT.md 準拠）
- [ ] verify: `bats tests/test_changelog_format.bats tests/test_check_plugin_version.bats` が green

- [ ] ドキュメント整合性チェック（skills/README・commands/README・tests/README・CHANGELOG・SKILL.md の相互参照を通読し、design-doc.md の決定 D1-D3 と実装が一致しているか確認）
- [ ] verify: 関連ドキュメントが変更内容と整合している
