# Test Strategy: QA

Issue #22: bug: eval-guard.sh が main 側の SKILL.md 変更を誤検知する

## 1. AC ごとのテスト層選定

| AC | テスト層 | 理由 |
|----|---------|------|
| AC1: merge-base 基点の SKILL.md 変更検出 | Unit (BATS) — 動的 | git リポジトリの分岐状態を再現し、スクリプトを実行して stdout JSON を検証 |
| AC2: ブランチ導入の SKILL.md 変更検出 | Unit (BATS) — 動的 | ブランチ側の SKILL.md 変更を再現してブロック動作を検証 |
| AC3: 引数中の "git push" 誤検知防止 | Unit (BATS) — 動的 | stdin JSON の command フィールドに対する regex 挙動を検証 |
| AC4: チェーンコマンド中の git push 検出 | Unit (BATS) — 動的 | チェーンコマンドの command フィールドに対する regex 検証 |

全 AC が Unit (BATS) 動的テスト。Integration / E2E 層は不要。

**理由:** eval-guard.sh は stdin JSON → stdout JSON の純粋な変換スクリプト。外部依存は git コマンドのみで、一時 git リポジトリで完全に制御可能。Claude Code の hook フレームワークとの統合テスト（E2E）は scope 外。

## 2. テストファイル構成

### 新規テストファイル

```
tests/test_eval_guard.bats
```

**配置理由:** eval-guard.sh は `hooks/` 直下のコアスクリプト（addon 固有ではない）。`tests/` 配下に配置。

**既存テストとの関係:**
- `tests/` 配下の既存テストは全て静的テスト（grep でマークダウンを検証）
- `addons/ios/tests/` 配下の sim-pool-guard テストは動的テスト（スクリプト実行 + JSON 検証）
- eval-guard テストは sim-pool-guard の **動的テストパターン**（`run_guard()` ヘルパー + `jq` アサーション）を採用
- 加えて、git リポジトリのセットアップが必要（sim-pool-guard にはない要素）

**既存テストへの影響: なし。** eval-guard 専用の BATS テストは存在しないため、既存テストの修正は不要。

### テストファイルの内部構成

```
tests/test_eval_guard.bats
├── setup()                  — 一時 git リポジトリ + bare remote + eval マーカーディレクトリ
├── teardown()               — 一時ディレクトリの削除
├── run_eval_guard()         — ヘルパー関数（command → stdin JSON → スクリプト実行）
├── AC1 セクション (2 tests) — merge-base regression テスト
├── AC2 セクション (3 tests) — ブランチ側 SKILL.md 検出 + メッセージ検証
├── AC3 セクション (3 tests) — コマンド引数の誤検知防止
├── AC4 セクション (4 tests) — チェーンコマンド + パイプ検出
├── BOUNDARY セクション (6 tests) — 境界条件テスト
└── REGRESSION セクション (3 tests) — 既存動作の維持確認
```

## 3. テスト環境のセットアップ

### setup() 設計

eval-guard.sh は以下の外部状態に依存する:
1. **git リポジトリ** — `git branch --show-current`, `git diff --name-only origin/main...HEAD`
2. **eval マーカー** — `$XDG_CACHE_HOME/atdd-kit/eval-ran-<branch>`
3. **stdin JSON** — `{"command": "..."}` 形式の PreToolUse hook 入力

```bash
setup() {
  # --- 一時 git リポジトリ ---
  TEST_REPO="${BATS_TMPDIR}/eval-guard-repo-$$"
  mkdir -p "$TEST_REPO"
  git -C "$TEST_REPO" init -b main
  git -C "$TEST_REPO" config user.email "test@test.com"
  git -C "$TEST_REPO" config user.name "test"

  # initial commit with SKILL.md
  mkdir -p "$TEST_REPO/skills/session-start"
  mkdir -p "$TEST_REPO/skills/discover"
  echo "initial" > "$TEST_REPO/skills/session-start/SKILL.md"
  echo "initial" > "$TEST_REPO/skills/discover/SKILL.md"
  echo "readme" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -m "initial"

  # origin/main をシミュレート（bare リポジトリ + remote 設定）
  BARE_REPO="${BATS_TMPDIR}/eval-guard-bare-$$"
  git clone --bare "$TEST_REPO" "$BARE_REPO"
  git -C "$TEST_REPO" remote add origin "$BARE_REPO"
  git -C "$TEST_REPO" fetch origin

  # --- eval マーカーディレクトリ ---
  TEST_CACHE="${BATS_TMPDIR}/eval-guard-cache-$$"
  mkdir -p "$TEST_CACHE/atdd-kit"
  export XDG_CACHE_HOME="$TEST_CACHE"

  # --- eval-guard.sh の絶対パス ---
  GUARD="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/hooks/eval-guard.sh"
}
```

### teardown() 設計

```bash
teardown() {
  rm -rf "$TEST_REPO" "$BARE_REPO" "$TEST_CACHE"
}
```

### run_eval_guard() ヘルパー

sim-pool-guard の `run_guard()` パターンに倣い、command フィールドを含む JSON を stdin に渡す。eval-guard.sh は `git branch`, `git diff` を実行するため、カレントディレクトリを一時 git リポジトリにする必要がある。

```bash
run_eval_guard() {
  local command="$1"
  printf '{"command": "%s"}' "$command" | \
    (cd "$TEST_REPO" && bash "$GUARD")
}
```

### シナリオ別セットアップヘルパー

AC ごとにブランチ・コミット状態が異なるため、テスト内でセットアップヘルパーを呼ぶ。

```bash
# AC1 用: main 分岐後に main 側で SKILL.md 変更、ブランチは README のみ
create_main_side_change() {
  git -C "$TEST_REPO" checkout -b feature
  echo "changed" > "$TEST_REPO/README.md"
  git -C "$TEST_REPO" add README.md
  git -C "$TEST_REPO" commit -m "edit readme"
  git -C "$TEST_REPO" checkout main
  echo "changed on main" > "$TEST_REPO/skills/session-start/SKILL.md"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -m "main: update SKILL.md"
  git -C "$TEST_REPO" push origin main
  git -C "$TEST_REPO" checkout feature
}

# AC2 用: ブランチ上で SKILL.md を変更
create_branch_skill_change() {
  git -C "$TEST_REPO" checkout -b feature
  echo "changed on branch" > "$TEST_REPO/skills/session-start/SKILL.md"
  git -C "$TEST_REPO" add .
  git -C "$TEST_REPO" commit -m "branch: update SKILL.md"
}
```

## 4. 各 AC のテストケース設計

### AC1: merge-base 基点の SKILL.md 変更検出（regression test）

セットアップ: `create_main_side_change()` — main 分岐後に main 側で SKILL.md を変更。ブランチ側は README のみ。

```
main:     A --- B (SKILL.md changed, pushed to origin)
               \
feature:        C (README only) ← HEAD
```

| テスト ID | テスト名 | stdin command | 期待結果 |
|----------|---------|---------------|---------|
| AC1.1 | main 側 SKILL.md 変更で誤ブロックしない | `git push origin feature` | `{}` を返す |
| AC1.2 | main 側で複数 SKILL.md 変更でも誤ブロックしない | `git push origin feature` | `{}` を返す |

AC1.2 のセットアップでは、main で `skills/session-start/SKILL.md` と `skills/discover/SKILL.md` の両方を変更する。

**Key insight:** `origin/main...HEAD` (three-dot) は merge-base からの差分を返すため、main 側の SKILL.md 変更はブランチの diff に含まれない。`origin/main` (two-dot, 現行バグ) は main の HEAD との双方向 diff を返すため、main 側の変更も含まれてしまう。

### AC2: ブランチ導入の SKILL.md 変更は正しく検出

セットアップ: `create_branch_skill_change()` — ブランチ上で SKILL.md を変更。eval マーカーなし。

| テスト ID | テスト名 | stdin command | 期待結果 |
|----------|---------|---------------|---------|
| AC2.1 | ブランチの SKILL.md 変更を検出してブロック | `git push origin feature` | `permissionDecision: "deny"` |
| AC2.2 | ブロックメッセージにスキル名を含む | `git push origin feature` | reason に `"SKILL.md changes detected (session-start)"` |
| AC2.3 | 複数 SKILL.md 変更時に全スキル名をメッセージに含む | `git push origin feature` | reason に `"session-start"` と `"discover"` の両方 |

AC2.3 のセットアップでは、ブランチで `skills/session-start/SKILL.md` と `skills/discover/SKILL.md` の両方を変更する。

### AC3: コマンド引数中の "git push" 文字列で誤検知しない

セットアップ: `create_branch_skill_change()` — SKILL.md 変更あり（ブロック条件到達のため）。eval マーカーなし。

**重要:** SKILL.md 変更があることで、`git push` 検出の後段のブロックロジックに到達することを保証する。SKILL.md 変更がなければそもそもブロックしないため、テストが false positive（通るが意味がない）になる。

| テスト ID | テスト名 | stdin command | 期待結果 |
|----------|---------|---------------|---------|
| AC3.1 | commit メッセージ中の "git push" で誤検知しない | `git commit -m "fix: remember to git push"` | `{}` を返す |
| AC3.2 | echo 引数中の "git push" で誤検知しない | `echo "run git push later"` | `{}` を返す |
| AC3.3 | grep 引数中の "git push" で誤検知しない | `git log --oneline \| grep "git push"` | `{}` を返す |

### AC4: チェーンコマンド中の git push を正しく検出

セットアップ: `create_branch_skill_change()` — SKILL.md 変更あり、eval マーカーなし。

| テスト ID | テスト名 | stdin command | 期待結果 |
|----------|---------|---------------|---------|
| AC4.1 | && チェーンの git push を検出 | `git add . && git push origin feature` | `permissionDecision: "deny"` |
| AC4.2 | ; チェーンの git push を検出 | `git add . ; git push origin feature` | `permissionDecision: "deny"` |
| AC4.3 | \|\| チェーンの git push を検出 | `git add . \|\| git push origin feature` | `permissionDecision: "deny"` |
| AC4.4 | パイプ経由の git push を検出 | `echo foo \| git push origin feature` | `permissionDecision: "deny"` |

## 5. テストバリエーション（境界条件・エラーケース）

### BOUNDARY: 境界条件テスト

| テスト ID | テスト名 | 条件 | 期待結果 |
|----------|---------|------|---------|
| B1 | main ブランチ上の push はスキップ | `git checkout main` した状態 | `{}` を返す |
| B2 | detached HEAD の push はスキップ | `git checkout --detach` した状態 | `{}` を返す |
| B3 | eval マーカー存在時は push 許可 | SKILL.md 変更あり + `eval-ran-feature` マーカーファイル存在 | `{}` を返す |
| B4 | origin/main 不在時は push 許可（fail-open） | `git remote remove origin` した状態 | `{}` を返す |
| B5 | 不正 JSON 入力で push 許可（fail-open） | stdin に `invalid json` | `{}` を返す |
| B6 | 空 command で push 許可 | `{"command": ""}` | `{}` を返す |

### REGRESSION: 既存動作の維持確認

| テスト ID | テスト名 | 検証内容 |
|----------|---------|---------|
| REG.1 | eval-guard.sh が存在する | `[[ -f hooks/eval-guard.sh ]]` |
| REG.2 | eval-guard.sh が set -euo pipefail で始まる | `grep -q 'set -euo pipefail' hooks/eval-guard.sh` |
| REG.3 | 出力が有効な JSON | 全テストケースの出力が `jq -e .` でパース可能、または空文字列 `{}` |

## 6. カバレッジ戦略

### テスト数サマリー

| セクション | テスト数 |
|-----------|---------|
| AC1 (regression) | 2 |
| AC2 (正常ブロック) | 3 |
| AC3 (誤検知防止) | 3 |
| AC4 (チェーンコマンド) | 4 |
| BOUNDARY | 6 |
| REGRESSION | 3 |
| **合計** | **21** |

### リグレッションリスク分析

| 変更箇所 | リスク | テストカバレッジ |
|----------|-------|---------------|
| L34: `git diff --name-only origin/main` → `origin/main...HEAD` | **高** — diff の意味が根本的に変わる | AC1.1, AC1.2 が直接カバー。AC2.1-AC2.3 が逆方向を確認 |
| L20: `grep -q 'git push'` → regex 強化 | **高** — マッチ範囲が変わる | AC3.1-AC3.3 が false positive 排除。AC4.1-AC4.4 が true positive 確認 |
| それ以外の行 | **なし** — 変更なし | BOUNDARY + REGRESSION で既存動作を確認 |

### カバレッジギャップ（許容）

1. **L17 の sed JSON パース:** 脆弱だが Issue #22 scope 外。B5 (不正 JSON) で fail-open を確認するのみ。
2. **XDG_CACHE_HOME 未設定時の fallback:** L44 の `${XDG_CACHE_HOME:-$HOME/.cache}` — setup() で XDG_CACHE_HOME を設定するため fallback パスは未テスト。Priority 低。

## 7. JSON 出力の検証方法

sim-pool-guard テストの `jq -e` パターンを採用。

**ブロックしない場合:**
```bash
result=$(run_eval_guard "git commit -m 'test'")
[[ "$result" == '{}' ]]
```

**ブロックする場合:**
```bash
result=$(run_eval_guard "git push origin feature")
echo "$result" | jq -e '.hookSpecificOutput.permissionDecision == "deny"'
```

**メッセージ検証:**
```bash
reason=$(echo "$result" | jq -r '.hookSpecificOutput.permissionDecisionReason')
[[ "$reason" == *"SKILL.md changes detected (session-start)"* ]]
```

## 8. テスト実行

```bash
bats tests/test_eval_guard.bats
```

`jq` がテスト環境に必要（JSON パース用）。プロジェクトの既存テスト（sim-pool-guard）も `jq` を使用しているため、追加依存なし。
