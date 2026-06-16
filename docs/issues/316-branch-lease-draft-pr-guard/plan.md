# Plan: session-start の Draft PR 接触を二層でブロック（branch-lease guard ＋ 推奨の非 Draft 限定）

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

> 設計判断（lease store の置き場所・TTL・PR close 時の即時無効化）は `design-doc.md` に記録した。本 Plan はその決定（**共有 lease store `/tmp/claude-branch-leases/`、TTL ＋ orphan 掃除、override env**）を前提にタスク化する。User Stories の CS-1/CS-2（クロスセッション可視・TTL stale）が上位の正であり、PRD What §2 の `.claude/branch-lease.json` 表現はこの共有ストア方式で上書きする（design-doc 参照）。

## Implementation

### Layer 1 — session-start ガイドライン（FS-1 / FS-2）

- [ ] `skills/session-start/SKILL.md` Step 2 の「Highest priority: PRs with `mergeable == CONFLICTING` — recommend rebase」を、**ready（非 Draft）かつ `@me` の PR にのみ適用**するよう条件を限定する（Draft PR は対象外と明記）
- [ ] verify: `grep -nE 'CONFLICTING' skills/session-start/SKILL.md` で当該箇所に「ready（非 Draft）」「`@me`」の限定語が含まれることを目視確認

- [ ] 同 Step 2 に「**Draft PR は actionable task にせず、read-only で `🔒 別セッション作業中` として表示するのみ**」のルールを追記する（rebase / checkout / push を提案しない旨を明記）
- [ ] verify: `grep -nE '🔒|別セッション作業中|read-only' skills/session-start/SKILL.md` が新ルール行をヒットする

- [ ] Previous Work / Recommended Tasks の出力例で、Draft PR が `🔒 別セッション作業中` の read-only 行として現れ、Recommended Tasks 表（actionable）には載らないことが分かるよう例示を整える
- [ ] verify: SKILL.md の出力例に Draft PR の read-only 表示例があり、Recommended Tasks 表の行ではないことを目視確認

### Layer 2 — branch-lease guard フック新設（FS-3 / FS-4 / FS-5 / FS-6 / CS-1 / CS-2）

- [ ] `hooks/branch-lease-guard.sh` を新規作成し、`set -uo pipefail` ＋ fail-safe（git/jq 不在・stdin 不正・想定外条件は allow 相当で素通り）の骨格を置く（`main-branch-guard.sh` / `sim-pool-guard.sh` の fail-safe 型を踏襲）
- [ ] verify: `bash -n hooks/branch-lease-guard.sh` が構文エラーなし。空 stdin・不正 JSON を流すと PreToolUse allow JSON（exit 0）を返す

- [ ] stdin の `tool_name == "Bash"` の `tool_input.command` をパースし、**write-back 操作のみ**を対象判定する関数を実装する（対象: `git push` / `git push --force*` / `gh pr edit` / `gh pr merge` / `gh pr ready`。非対象: `git checkout` / `git switch` / ローカル `git rebase` / その他）
- [ ] verify: `git checkout`・`git switch`・`git rebase`（push 無し）・`ls` 等を流すと allow（FS-4）。`git push`・`gh pr merge` 等を流すと判定ロジックに入る

- [ ] 対象ブランチ解決を実装する（`git push` は引数 or 現在ブランチ、`gh pr *` は対象 PR の head ブランチ）。**main/master は常に allow**（FS-4）
- [ ] verify: main ブランチへの `git push` が常に allow されることをユニットで確認

- [ ] 共有 lease store（`BRANCH_LEASE_DIR` env override、default `/tmp/claude-branch-leases/`）を実装する。branch 名キーのファイルに `{session_id, timestamp}` を保存し、クロスセッションで可視にする（CS-1）
- [ ] verify: push でリース取得後、別 `session_id` の呼び出しから同 lease ファイルが読めることをユニットで確認

- [ ] open Draft PR 判定を実装する（`gh pr view <branch> --json isDraft,state` 等で対象ブランチに open Draft PR があるか判定。`gh` 不在・取得失敗時は fail-safe allow）
- [ ] verify: open Draft PR ありのモック条件で hard block 経路に入り、無し or ready PR では入らないことを確認

- [ ] hard block を実装する：対象ブランチに open Draft PR があり、かつ**自セッションがリース未保有**なら `permissionDecision: "deny"` JSON（`emit_deny` 相当・**exit 0**）＋「別セッションが作業中」案内を返す（FS-3）。**本リポジトリの PreToolUse deny 機構は exit 0 ＋ deny JSON であり、exit 非ゼロは Claude Code 上 hook 実行エラー扱いでツールを確実にはブロックしない**（`sim-pool-guard.sh` の `emit_deny` / 全 sim BATS が確立した型を踏襲する）
- [ ] verify: 別セッション保有リース ＋ 対象 Draft ブランチへの write-back で stdout が `permissionDecision:"deny"` JSON（exit 0）になることをユニットで確認

- [ ] push 時のリース自動取得を実装する：非 main ブランチへの `git push` でリース未取得なら自セッション名義で取得。別セッションの **fresh** リースがあればブロック（FS-5）
- [ ] verify: リース未取得状態の自セッション push が allow ＋ lease ファイル生成。別セッション fresh リース存在時は deny

- [ ] `ATDD_BRANCH_LEASE_FORCE=1` の override を実装する：セット時は hard block を意図的に上書きして allow（FS-6）
- [ ] verify: deny 条件下でも `ATDD_BRANCH_LEASE_FORCE=1` で allow になることをユニットで確認

- [ ] TTL ＋アクセス時 orphan 掃除を実装する（`BRANCH_LEASE_TTL_LOCAL` / CI 用 env override を sim-pool の `SIM_TTL_LOCAL` 相当で用意。アクセス時に TTL 超過 lease を削除）（CS-2）
- [ ] verify: TTL を小さく設定して timestamp を過去にしたリースが、次アクセスで stale 扱い（削除）され、ブロックを生まないことをユニットで確認

- [ ] `hooks/hooks.json` の `PreToolUse` に Bash matcher で `branch-lease-guard.sh` を登録する（`main-branch-guard.sh` の登録形式・`${CLAUDE_PLUGIN_ROOT}`・timeout を踏襲）
- [ ] verify: `jq . hooks/hooks.json` が valid。PreToolUse に Bash matcher の branch-lease-guard エントリが存在する

## Testing

- [ ] フック単体 BATS `tests/test_branch_lease_guard.bats` を作成し、各挙動を pin する：write-back 判定 / 非 write-back 通過（FS-4）/ main 通過（FS-4）/ リース取得（FS-5）/ 別セッションブロック（FS-3）/ override（FS-6）/ TTL stale（CS-2）/ fail-safe
- [ ] verify: `bats tests/test_branch_lease_guard.bats` が全 green

- [ ] E2E BATS（`tests/e2e/` 配下、sim-pool e2e 群の型）を作成し、実 lease store ＋ 実 git ブランチ ＋ モック `gh` で「別セッション Draft ブランチへの push がブロックされ、自セッション push は通る」を end-to-end で pin する
- [ ] verify: `bats tests/e2e/<新規 e2e>.bats` が全 green

- [ ] Layer 1 を `tests/test_session_start_task_recommendation.bats` に pin 追加する：CONFLICTING rebase 推奨が ready（非 Draft）＋ `@me` 限定であること、Draft PR が read-only `🔒 別セッション作業中`・actionable 非対象であること（既存 #187 / #302 の pin は維持）
- [ ] verify: `bats tests/test_session_start_task_recommendation.bats` が全 green（既存 17 件 ＋ 新規 pin）

## Finishing

- [ ] `hooks/README.md` の Plugin Hooks 表に `branch-lease-guard.sh`（PreToolUse / Bash）の行を追加し、専用節（lease store・write-back 判定・override env・TTL・fail-safe・緊急回避）を追記する
- [ ] verify: `grep -n 'branch-lease-guard' hooks/README.md` が表＋節をヒットする

- [ ] `tests/README.md` に新規テストファイルの行を追加する（DEVELOPMENT.md L65 の不変条件：`tests/` 配下のファイル増減は同一 PR で `tests/README.md` を更新）：`### Hooks & Scripts` 表に `test_branch_lease_guard.bats`（branch-lease-guard PreToolUse hook / #316）の行、`## Skill E2E Tests (tests/e2e/)` 直下の表に新規 E2E ファイル行（branch-lease guard の end-to-end pin / #316）を追加する。**この E2E は flow-skill E2E（10 本の `tests/e2e/<skill>.bats`）ではないため `test_skill_test_coverage.bats` の 10-skill 揃い検証には含めない**
- [ ] verify: `grep -n 'branch-lease' tests/README.md` が Hooks & Scripts 行と E2E 行の両方をヒットする

- [ ] `.claude-plugin/plugin.json` の version を minor bump し、`CHANGELOG.md`（Keep a Changelog）に `### Added`（branch-lease guard フック）＋ `### Changed`（session-start CONFLICTING rebase の非 Draft 限定）を同一 PR で追記する
- [ ] verify: plugin.json version == CHANGELOG 最上位 release 見出し（不変条件）。新フックは minor（DEVELOPMENT.md「新規 hook/optional gate = minor」）

- [ ] ドキュメント整合性チェック（hooks/README.md・CHANGELOG・session-start SKILL.md・本 Issue dir 成果物の相互整合）
- [ ] verify: 関連ドキュメントが変更内容と整合している
