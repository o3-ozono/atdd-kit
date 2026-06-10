# User Stories: main-branch-guard の判定をプロジェクトリポジトリ × 対象 worktree ブランチ基準に修正

## Functional Story

### US-1: プロジェクトリポジトリ外の編集を deny しない

**I want to** セッション cwd のプロジェクトリポジトリに属さないファイル（例: `~/.local/share/chezmoi/` 配下の dotfiles）への編集が main-branch-guard で deny されない,
**so that** ユーザー承認済みのリポジトリ外編集を Bash 経由で回避する悪習なしに実行できる.

### US-2: feature ブランチ worktree 配下の編集を allow する

**I want to** `git worktree add` で作成した feature ブランチ worktree 配下への編集が、セッション cwd が main にあっても allow される,
**so that** 1 Issue = 1 worktree の標準規律に従った作業が EnterWorktree のない環境でも誤 deny で詰まらない.

### US-3: main/master 上の直接編集は引き続き deny する

**I want to** 対象ファイルを含む worktree が main/master 上にある直接編集は、既存 allow-list 例外（/tmp, ~/.claude, ~/.config 等）を除き引き続き deny される,
**so that** ガード本来の目的である main ブランチへの直接編集防止の実効性が維持される.

### US-4: ブランチ判定を py 側へ集約する

**I want to** `hooks/main-branch-guard.sh` の「cwd が main でなければ即 allow」早期 return を廃し、ブランチ判定を `hooks/main_branch_guard.py` の対象ファイル基準判定に集約する,
**so that** sh 側の cwd 基準判定によるモード 2（worktree）の取りこぼしが構造的に発生しなくなる.

### US-5: ドキュメントとバージョンが同期されている

**I want to** `hooks/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json`（3.7.0 → 3.7.1 patch）が本変更と同期して更新されている,
**so that** プラグイン利用者がフックの新しい判定基準とリリース内容を正確に把握できる.

## Constraint Story (Non-Functional)

### CS-1: fail-safe（判定不能時は allow）

**I want to** git / python3 不在・例外発生・判定不能（detached HEAD 等）の場合は従来どおり `{}`（allow）を返すフェイルセーフが維持されている,
**so that** ガードの不具合や環境差異が正当な編集作業をブロックしない.

### CS-2: 回帰テストによる判定品質の保証

**I want to** `tests/test_main_branch_guard.bats` に偽陽性 2 モードの負例・真陽性維持・fail-safe の回帰テストが追加され BATS 全 green である,
**so that** 今後のフック変更で偽陽性・偽陰性が再発しないことを継続的に検証できる.
