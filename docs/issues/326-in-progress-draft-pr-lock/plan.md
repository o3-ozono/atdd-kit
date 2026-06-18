# Plan: Draft PR 作成時に in-progress 付与 ＋ full-autopilot dispatch の GitHub-state プリフィルタ

<!-- 2-5 分粒度のタスク行と verification 行を交互に配置する（superpowers writing-plans 形式）。
     各タスクは単一の操作に限定し、verification で完了条件を即確認できる粒度にする。 -->

## アーキテクチャ概要

- **What ①/③（F1/F3）= PostToolUse hook**: `hooks/in-progress-label.sh` を新設。`gh pr create --draft` を検知して付与、`gh pr close`／`gh pr merge` を検知して除去する。既存 hook 群（`branch-lease-guard.sh` の PreToolUse、`bash-output-normalizer.sh` の PostToolUse）と同じ流儀（stdin から JSON 受け取り → `tool_input.command` をパース → fail-safe で必ず exit 0）。`hooks/hooks.json` の `PostToolUse / matcher: Bash` 配列に登録する。skill 群は未編集（C3）。
- **What ②（F2）= 呼び出し側＋env 注入プリフィルタ**: `cmd_select` の純粋性（C1）を維持するため、`lib/full-autopilot-dispatch.sh` に「busy 判定関数」を env 注入可能な形で追加し、`cmd_select` の前段でキュー候補を絞る。GitHub 問い合わせ本体は `full-autopilot-run.sh`（統合層）か注入された関数に隔離する。
- Issue 番号解決ロジック（PR body `Closes #<N>` / branch 名プレフィックス `<N>-...`）は付与・除去で共有する単一関数にする（F1/F3 の DRY、C2 の対称性）。

## Implementation

### A. in-progress ラベル hook（F1 付与 / F3 除去 / C3 hook 準拠）

- [ ] `hooks/in-progress-label.sh` を新規作成し、stdin から JSON を読み、`tool_name == "Bash"` 以外・空 stdin・`jq` 不在・`gh` 不在はすべて即 `exit 0`（fail-safe、`bash-output-normalizer.sh` の AC5 と同じ方針）にする骨格を置く
- [ ] verify: 空 stdin と非 Bash tool_name の JSON を流して exit 0・無副作用（ラベル API を叩かない）であることを手動確認

- [ ] `resolve_issue_number(cmd)` 関数を実装する。`gh pr create` のコマンド文字列から (1) `--body`／`Closes #<N>` パターン、(2) `git branch --show-current` の `<N>-...` プレフィックス、の順で Issue 番号を解決し、解決不能なら空を返す
- [ ] verify: `Closes #324` を含む body と `324-foo` ブランチの両入力で `324` が返り、どちらも無い入力で空が返る（関数単体を bash で直接呼んで確認）

- [ ] `gh pr create --draft` 検知ブロックを実装する。`is_draft_create(cmd)` で `^gh pr create` かつ `--draft` を判定し、`resolve_issue_number` で得た Issue へ `gh issue edit <N> --add-label in-progress` を実行する。既に付与済みでも no-op（冪等、C2）
- [ ] verify: `gh pr create --draft --body "Closes #324"` 相当の JSON を流すとラベル付与コマンドが（モック gh 経由で）1 回だけ呼ばれ、`--draft` 無しでは呼ばれないことを確認

- [ ] `gh pr close` / `gh pr merge` 検知ブロックを実装する。`is_pr_close_or_merge(cmd)` で判定し、リンク Issue から `gh issue edit <N> --remove-label in-progress` を実行する。ラベルが無い場合は no-op（冪等、F3／C2 の対称除去）。close/merge 時の Issue 番号解決はブランチ名 or PR 番号→`gh pr view`→headRefName で行う
- [ ] verify: `gh pr close` 相当の JSON でラベル除去コマンドが呼ばれ、ラベル未付与状態でも非ゼロ終了しない（exit 0）ことを確認

- [ ] `hooks/hooks.json` の `PostToolUse / matcher: "Bash"` の `hooks` 配列に `in-progress-label.sh` を追記する（`bash-output-normalizer.sh` と並置、`timeout` 付き）
- [ ] verify: `jq . hooks/hooks.json` がパース成功し、PostToolUse Bash の hooks 配列に新 hook のエントリが含まれる

### B. dispatch GitHub-state プリフィルタ（F2 / C1 純粋性維持 / C2 冪等）

- [ ] `lib/full-autopilot-dispatch.sh` に `is_issue_busy(issue)` を env 注入可能な形で追加する（既定実装は `gh pr list`／`gh issue view --json labels` で open PR or `in-progress` ラベルを判定、`FAD_BUSY_CMD` 等の env で差し替え可能）。`cmd_select` 本体の lease 合成ロジックは無改変のまま維持する（C1）
- [ ] verify: `FAD_BUSY_CMD` にスタブを注入した状態で関数を直接呼び、busy 判定が注入関数に委譲されることを確認

- [ ] `cmd_select` の前段にプリフィルタを適用する。候補ループで `is_issue_busy` が真の Issue は `cmd_acquire` を試みずスキップする（lease 取得前に除外＝二重 dispatch を冪等にブロック、C2）。busy 判定の GitHub 問い合わせ単位（候補ごと引く／一括取得して突合）は実装時に API 回数最小で確定する
- [ ] verify: busy 注入されたキューに対し `select` 実行で当該 Issue が出力されず、busy でない Issue だけが lease・出力される

## Testing

- [ ] `tests/test_in_progress_label.bats`（`@covers: hooks/in-progress-label.sh`）を作成し、`test_branch_lease_guard.bats` 流儀でモック `gh`／`git` を `FAKE_BIN` に置いて付与・除去・冪等・fail-safe を検証する
- [ ] verify: `bats tests/test_in_progress_label.bats` が green

- [ ] `tests/test_full_autopilot_dispatch.bats` に F2 プリフィルタケース（busy Issue 除外 / busy でない Issue は従来どおり選択 / `cmd_select` 純粋性の回帰）を追加する
- [ ] verify: `bats tests/test_full_autopilot_dispatch.bats` が green（既存 FAD-1〜4 も回帰なし）

- [ ] スイート全体を走らせ回帰がないことを確認する
- [ ] verify: `bats tests/` が全 green

## Finishing

- [ ] バージョンを bump（新 hook 追加＝minor）し `CHANGELOG.md` に `### Added` エントリを追加する（`.claude-plugin/plugin.json` と同一 PR）
- [ ] verify: plugin.json の version が CHANGELOG の最上位リリース見出しと一致する（DEVELOPMENT.md の versioning ルール）

- [ ] `hooks/README.md` に `in-progress-label.sh` 行を追加し、必要なら `lib/README.md` の dispatch 記述を更新する
- [ ] verify: `hooks/README.md` に新 hook の行があり、`tests/test_hook_distribution.bats` が green（hook 配布整合）

- [ ] ドキュメント整合性チェック（`docs/workflow/issue-ready-flow.md` の in-progress 付与タイミング、`docs/workflow/workflow-detail.md` の Draft PR Locking との責任分掌注記）
- [ ] verify: 関連ドキュメントが「hook が Draft PR と連動して in-progress を付与・除去する」記述と整合し、skill-gate が概念上の owner である旨が崩れていない
