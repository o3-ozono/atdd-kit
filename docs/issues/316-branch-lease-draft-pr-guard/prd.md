# PRD: session-start の Draft PR 接触を二層でブロック（branch-lease guard ＋ 推奨の非 Draft 限定）

## Problem

別セッションで session-start を実行したとき、**他セッションが作業中の Draft PR ブランチに触れようとする**事故が起きる。具体的には session-start の Recommended Tasks 最優先ルール（Step 2.1）が `mergeable == CONFLICTING` の PR に対し `git checkout <branch>` / `git rebase origin/main` / `git push --force-with-lease` を推奨し、その `<branch>` が他セッション作業中の Draft PR ブランチだと force-push で衝突する。

EXCLUDE_SET（open PR を持つ Issue を Recommended Tasks から除外）はこの rebase 推奨を別経路で素通りさせる。1 Issue = 1 worktree = 1 Draft PR（初コミットで open）の規律上、**open Draft PR の存在＝誰かが今そのブランチで作業中**という高確率 signal だが、現状その signal を尊重する強制がない。

ガイドライン（SKILL.md 記述）だけでは LLM 規律依存で漏れることが autopilot #304 実走中の運用で実証された。**ツール層での実強制が必要。**

## Why now

- autopilot を atdd-kit 自身で多重セッション dogfood する運用が定着し、並行セッションの衝突リスクが現実の頻度になっている。
- リポジトリには既に `sim-pool`（iOS シミュレータ排他制御の PreToolUse フック）という排他制御の実績ある型があり、その「ブランチ版」を作る下地が揃っている。
- 衝突は force-push を伴うため、起きると他セッションの作業を破壊し得る（高コストな失敗）。事故が起きる前に塞ぐ価値が高い。

## Outcome

1. **Layer 1（session-start ガイドライン）**: session-start が Draft PR を rebase 推奨・actionable task 化しない。CONFLICTING rebase 推奨は **ready（非 Draft）かつ `@me` の PR に限定**され、Draft PR は read-only で「🔒 別セッション作業中」として表示されるのみ。対応 BATS pin で担保。
2. **Layer 2（PreToolUse フックによる実強制 = branch-lease guard）**: 新設 PreToolUse（Bash matcher）フックが git/gh の **write-back 操作**（`git push`／`git push --force*`／`gh pr edit`／`gh pr merge`／`gh pr ready` 等リモート影響操作）をインターセプトし、対象ブランチに **open Draft PR があり、かつ自セッションがリースを保有していない**場合は **hard block（exit 非ゼロ）**する。`git checkout`／`switch`／ローカル `rebase` 等の非 write-back 操作はブロックしない。
3. **リース取得は自動**: フックが `git push`（非 main ブランチ）時にリース未取得なら自セッション名義で取得し、別セッションの fresh リースがあればブロックする（スキル改修不要・hook 自己完結）。
4. **stale 処理**: リースは **共有の lease store**（クロスセッションで可視。例 `/tmp/claude-branch-leases/`、branch 名キー → {session_id, timestamp}）に置き、sim-pool と同じく **TTL ＋アクセス時 orphan 掃除**で stale を期限切れにする。
5. **override エスケープハッチ**: 安全と判断したときの意図的上書き手段（例 `ATDD_BRANCH_LEASE_FORCE=1`）を残す（hard block だが袋小路を作らない）。
6. `sim-pool` と同様にフック単体テスト ＋ E2E で挙動を pin。

## What

1. **Layer 1 — session-start 修正**: Step 2.1 CONFLICTING rebase 推奨を ready（非 Draft）かつ `@me` の PR に限定。Draft PR を actionable task から除外し read-only「🔒 別セッション作業中」表示へ。対応 BATS（session-start task-recommendation スイート）に pin 追加。
2. **Layer 2 — branch-lease guard フック新設**:
   - 新規フックスクリプト（例 `hooks/branch-lease-guard.sh`）を PreToolUse の Bash matcher に登録（`hooks/hooks.json`）。
   - git/gh コマンドをパースし、write-back 操作のみ対象。対象ブランチを解決し、共有 lease store を参照。
   - リース取得（push 時自動）・別セッション保有時 hard block・`ATDD_BRANCH_LEASE_FORCE=1` で override。
   - TTL ＋アクセス時 orphan 掃除（sim-pool の `SIM_TTL_LOCAL` 相当の env override を用意）。
3. **テスト**: フック単体（lease 取得／別セッションブロック／override／TTL stale／非 write-back 通過／main 通過）＋ E2E。`hooks/README.md` 追従。

## Non-Goals

- **iOS / sim-pool 自体の変更**: branch-lease は sim-pool の型を踏襲する独立フックで、sim-pool には手を入れない。
- **worktree 単位のロック**: 本 Issue はブランチ単位のリース。worktree 排他は別途必要なら別 Issue。
- **session-start 以外の経路の網羅的監査**: Layer 1 は session-start の Draft 接触経路（CONFLICTING rebase 推奨）を塞ぐ。他スキルの Draft 接触は Layer 2 のツール層強制でカバーされるため、各スキル本文の個別監査はしない。
- **リース store のリモート共有（複数マシン間）**: 同一マシン上の並行セッション衝突が対象。マシンを跨ぐ排他は対象外。

## Open Questions

- TTL のデフォルト値（sim-pool は local 2h / CI 40min）と、PR が merge/close されたらリースを即時無効化するか否かは plan / design-doc で詰める（不変条件: stale リースが他セッションを恒久ブロックしてはならない）。
- branch-lease guard と `skill-gate`（並行セッション衝突・in-progress ラベル管理担当）の責務境界は plan で整理する。
