# PRD: main-branch-guard の判定をプロジェクトリポジトリ × 対象 worktree ブランチ基準に修正

> Gate ① 承認: 2026-06-10 ユーザー `ok`（autopilot 壁打ち、Section 1-6 確認済み）。

## Problem

`hooks/main-branch-guard.sh` + `hooks/main_branch_guard.py` は「セッション cwd のブランチが main/master か」×「静的パス allow-list（/tmp, ~/.claude, ~/.config 等）」だけで deny を判定しており、編集対象ファイルがどのリポジトリ・どのブランチ（worktree）に属するかを見ていない。

その結果、正当な編集が 2 モードで誤 deny される（2026-06-10 のセッションで両モード実発生）:

1. **リポジトリ外の別 git リポジトリ**: セッション cwd（atdd-kit, main）と無関係な `~/.local/share/chezmoi/`（dotfiles）配下のユーザー承認済み編集が deny され、Bash sed での回避が必要だった。
2. **同一リポジトリの feature ブランチ worktree**: `git worktree add ../atdd-kit-249 -b feat/...` で作成した worktree 配下への Write が、cwd が main にいるという理由で deny された（EnterWorktree のない環境では詰む）。

誤 deny は「Bash 経由で回避する」悪習を誘発し、ガード本来の実効性を侵食する。

## Why now

- #249 の作業中に 2 モードとも再現確認できたばかりで文脈が新鮮。
- worktree 運用は atdd-kit の標準規律（1 Issue = 1 worktree）であり、今後すべての Issue 作業で毎回踏む摩擦になっている。
- 回避パターンが定着する前に修正する必要がある。

## Outcome

- **偽陽性 2 モードの解消**: ① プロジェクトリポジトリ外のファイル編集は本フックでは deny されない（リポジトリ外編集の統制は `repo-external-edit` ルールの責務）。② 登録済み worktree（feature ブランチ）配下への編集は allow。
- **真陽性の維持**: プロジェクトリポジトリ内で、対象ファイルを含む worktree が main/master 上にある直接編集は引き続き deny（既存 allow-list 例外は不変）。
- **fail-safe 維持**: git / python3 不在・例外時は従来どおり `{}` allow。
- `tests/test_main_branch_guard.bats` に偽陽性 2 モードの負例が追加され、BATS 全 green。

## What

1. **`hooks/main_branch_guard.py`** — 判定を「対象ファイル基準」に変更:
   - canonicalize した file_path の所属 git リポジトリを解決し、**プロジェクトリポジトリ（フック cwd のリポジトリ）に属さない** → allow。同一リポジトリ判定は `git rev-parse --git-common-dir` の比較（worktree は common dir を共有）。
   - 属する場合、**対象ファイルを含む worktree のブランチ**が main/master 以外 → allow。
   - main/master 上 → 既存 allow-list 照合 → deny。
2. **`hooks/main-branch-guard.sh`** — 「cwd が main でなければ即 allow」の早期 return はモード 2 の取りこぼし原因のため、ブランチ判定を py 側へ移し、sh は入力読取り・git/python3 存在確認・fail-safe に役割を縮小。
3. **`tests/test_main_branch_guard.bats`** — 偽陽性 2 モードの負例 + 真陽性維持 + fail-safe の回帰を追加。
4. **ドキュメント同期** — `hooks/README.md` / `CHANGELOG.md` / `.claude-plugin/plugin.json` 3.7.0 → 3.7.1（patch）。

## Non-Goals

- **他リポジトリの main 保護はしない** — 本フックの管轄はセッションのプロジェクトリポジトリのみ（壁打ちで確定した割り切り。dotfiles のような main 直 push 運用リポジトリを誤 deny しないため）。
- **`repo-external-edit` ルールのフック化・自動強制はしない** — リポジトリ外編集の承認統制は人間ルールのまま。
- **allow-list（/tmp, ~/.claude, ~/.config 等）の見直しはしない** — 現状維持。
- **detached HEAD・サブモジュール等エッジの精緻化はしない** — 判定不能時は fail-safe（allow）の現行方針を維持。
- **フック登録方式（hooks/hooks.json の plugin-level PreToolUse）は変更しない**。

## Open Questions

- なし。
