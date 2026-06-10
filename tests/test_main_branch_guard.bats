#!/usr/bin/env bats
# @covers: hooks/main-branch-guard.sh hooks/main_branch_guard.py
# =============================================================================
# main-branch-guard.sh -- PreToolUse hook tests
# Issue #38: Enforce Issue-driven workflow via PreToolUse hook (Tier 1)
# Issue #181: Allow-list for repo-external paths + skill-agnostic deny message
# Issue #251: 判定をプロジェクトリポジトリ × 対象 worktree ブランチ基準に修正
#
# 判定フロー（#251）: 対象ファイルを canonicalize →
#   (a) フック cwd の git-common-dir が解決不能 → fail-safe allow
#   (b) 対象ファイルの common-dir が解決不能 or cwd 側と不一致（プロジェクト
#       リポジトリ外）→ allow
#   (c) 一致するが対象側 worktree のブランチが main/master 以外 → allow
#   (d) main/master → 既存 allow-list 照合 → 不一致なら deny
#
# 設置場所の大前提（P0）: $BATS_TMPDIR は macOS で /private/var/folders/...、
# Linux で /tmp に解決され、いずれも ALLOW_PREFIXES_STATIC に含まれる。
# そこに置いたリポジトリ内パスは段階 (d) で必ず allow になり deny 系テストが
# 成立しない。テストリポジトリ・負例リポジトリ・worktree はすべて
# allow-list 外（$HOME 直下の mktemp ベース $MBG_BASE 配下）に置く。
#
# NOTE on AC4(b): The matcher "Edit|Write|MultiEdit|NotebookEdit" is evaluated
# by the Claude Code runtime, not by the script itself. Therefore AC4(b)
# ("hook does not run for non-target tools like Bash") cannot be verified by
# BATS alone. It is verified via manual runtime testing after implementation
# (results recorded in PR description).
# =============================================================================

GUARD_SCRIPT="hooks/main-branch-guard.sh"

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  GUARD="$ROOT/$GUARD_SCRIPT"

  # allow-list 外のベースディレクトリ（$HOME 直下。home 由来 allow-list は
  # ~/.claude / ~/.config のみなので衝突しない）
  MBG_BASE="$(mktemp -d "$HOME/.mbg-test-XXXXXX")"

  # テストリポジトリ（プロジェクトリポジトリ相当、main ブランチ）
  WORK="$MBG_BASE/work"
  git init -b main "$WORK" 2>/dev/null
  cd "$WORK"
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "initial" > README.md
  echo "content" > file.md
  echo "{}" > notebook.ipynb
  git add README.md file.md notebook.ipynb
  git commit -m "initial" -q
}

teardown() {
  # worktree 未作成のテストでも非ゼロ終了しないよう、無条件の
  # `git worktree remove` は行わない。MBG_BASE ごと削除すれば
  # main worktree（$WORK/.git ごと）も linked worktree も消える。
  rm -rf "$MBG_BASE"
}

# Helper: run main-branch-guard with a given tool name, on current branch.
# Default file_path はテストリポジトリ内の実在ファイル（allow-list 外）なので
# main 上では deny の真陽性になる。
run_guard() {
  local tool="${1:-Edit}"
  local file_path="${2:-$WORK/file.md}"
  local json
  json=$(printf '{"tool_name":"%s","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$tool" "$file_path" "$WORK")
  cd "$WORK"
  echo "$json" | bash "$GUARD"
}

# Helper: run guard for NotebookEdit (uses notebook_path key)
run_guard_nb() {
  local file_path="${1:-$WORK/notebook.ipynb}"
  local json
  json=$(printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s"},"cwd":"%s"}' "$file_path" "$WORK")
  cd "$WORK"
  echo "$json" | bash "$GUARD"
}

# Helper: run guard with raw stdin (for malformed JSON tests)
run_guard_raw() {
  local raw="$1"
  cd "$WORK"
  printf '%s' "$raw" | bash "$GUARD"
}

# Helper: 空ディレクトリベースの stub PATH を作る。
# 引数に挙げたコマンドだけを実体への symlink として配置する。
# PATH=/usr/bin:/bin 方式は macOS では python3/git を隠せないため、
# 「必要コマンドのみ存在する PATH」でコマンド不在を再現する。
make_stub_path() {
  STUB_BIN="$MBG_BASE/stub-bin"
  mkdir -p "$STUB_BIN"
  local cmd src
  for cmd in "$@"; do
    src="$(command -v "$cmd")"
    ln -s "$src" "$STUB_BIN/$cmd"
  done
}

# ---------------------------------------------------------------------------
# AT-001 (US-1): プロジェクトリポジトリ外の編集は deny されない（偽陽性モード 1）
# allow-list 外の別リポジトリに置くことが必須 — $BATS_TMPDIR 配下では旧実装でも
# allow-list 照合で {} になり「修正前でも green の空虚な負例」になる。
# ---------------------------------------------------------------------------

@test "AT-001: Edit in another git repo (outside allow-list) on main cwd returns {}" {
  OTHER="$MBG_BASE/other-repo"
  git init -b main "$OTHER" 2>/dev/null
  git -C "$OTHER" config user.email "test@example.com"
  git -C "$OTHER" config user.name "Test"
  echo "dotfile" > "$OTHER/dot_zshrc"
  git -C "$OTHER" add dot_zshrc
  git -C "$OTHER" commit -m "initial" -q
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "$OTHER/dot_zshrc")
  [ "$result" = "{}" ]
}

@test "AT-001: Write new file in another git repo on main cwd returns {}" {
  OTHER="$MBG_BASE/other-repo"
  git init -b main "$OTHER" 2>/dev/null
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write" "$OTHER/new/deep/file.md")
  [ "$result" = "{}" ]
}

@test "AT-001: Edit non-repo file (outside allow-list) on main cwd returns {}" {
  mkdir -p "$MBG_BASE/plain-dir"
  echo "x" > "$MBG_BASE/plain-dir/note.md"
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "$MBG_BASE/plain-dir/note.md")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AT-002 (US-2): feature ブランチ worktree 配下の編集は allow される
# （偽陽性モード 2）。worktree も allow-list 外に置くことが必須。
# ---------------------------------------------------------------------------

@test "AT-002: Write into feature worktree while cwd is main returns {}" {
  cd "$WORK"
  git checkout main -q
  git worktree add "$MBG_BASE/mbg-wt" -b feat/test -q
  result=$(run_guard "Write" "$MBG_BASE/mbg-wt/file.md")
  [ "$result" = "{}" ]
}

@test "AT-002: Edit new file in feature worktree while cwd is main returns {}" {
  cd "$WORK"
  git checkout main -q
  git worktree add "$MBG_BASE/mbg-wt" -b feat/test -q
  result=$(run_guard "Edit" "$MBG_BASE/mbg-wt/docs/new-doc.md")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AT-003a (US-3): main/master 上の直接編集は引き続き deny される（真陽性維持）
# ---------------------------------------------------------------------------

@test "AT-003a: Edit repo file on main worktree is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "$WORK/file.md")
  echo "$result" | grep -q '"permissionDecision"'
  echo "$result" | grep -q "deny"
}

@test "AT-003a: Edit repo file on master worktree is denied" {
  cd "$WORK"
  git checkout -b master -q
  result=$(run_guard "Edit" "$WORK/file.md")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AT-003b (US-3): リポジトリ内パスでも allow-list（段階 (d)）は従来どおり機能する
# 新判定フローではリポジトリ外パスは段階 (b) で allow されるため、allow-list
# 照合 (d) を検証するにはリポジトリ内に解決される allow-list パスが必要。
# HOME override で ~/.claude / ~/.config を $WORK 配下に解決させる
# （既存 AC2(#181) と同方式）。
# ---------------------------------------------------------------------------

@test "AT-003b: repo-internal ~/.claude path on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.claude"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.claude/config.yml"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AT-003b: repo-internal ~/.config path on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.config"
  local json
  json=$(printf '{"tool_name":"Write","tool_input":{"file_path":"%s/.config/foo.toml"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AT-004 (US-4): 判定は cwd ブランチではなく対象ファイル側 worktree の
# ブランチに基づく。cwd が feature worktree でも main worktree 内ファイルへの
# 編集は deny される（旧実装は sh の早期 return で素通りしていた）。
# ---------------------------------------------------------------------------

@test "AT-004: Edit main-worktree file while cwd is feature worktree is denied" {
  cd "$WORK"
  git checkout main -q
  git worktree add "$MBG_BASE/mbg-wt4" -b feat/at004 -q
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/file.md"},"cwd":"%s"}' "$WORK" "$MBG_BASE/mbg-wt4")
  result=$(cd "$MBG_BASE/mbg-wt4" && echo "$json" | bash "$GUARD")
  echo "$result" | grep -q "deny"
}

@test "AT-004: main-branch-guard.sh no longer detects branch itself (structure)" {
  # ブランチ判定は py 側に集約されている — sh に早期 return が残っていない
  ! grep -q 'branch --show-current' "$GUARD"
}

# ---------------------------------------------------------------------------
# AT-006 (CS-1): fail-safe -- 判定不能時はすべて {} allow
# ---------------------------------------------------------------------------

@test "AT-006/AC6: non-git cwd returns {} (fail-safe stage a)" {
  NON_GIT="$MBG_BASE/non-git"
  mkdir -p "$NON_GIT"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/file.md"},"cwd":"%s"}' "$WORK" "$NON_GIT")
  result=$(cd "$NON_GIT" && echo "$json" | bash "$GUARD")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: git not in PATH returns {} (stub PATH without git)" {
  # 空ディレクトリ + 必要コマンドのみの stub PATH。PATH=/usr/bin:/bin 方式は
  # macOS では git/python3 を隠せないため使わない。
  make_stub_path cat dirname python3
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/file.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env PATH="$STUB_BIN" /bin/bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: python3 not in PATH returns {} (stub PATH without python3)" {
  make_stub_path cat dirname git
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/file.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env PATH="$STUB_BIN" /bin/bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: broken git (always exits 127) returns {} (fail-safe)" {
  FAKE_BIN="$MBG_BASE/fake-bin"
  mkdir -p "$FAKE_BIN"
  printf '#!/usr/bin/env bash\nexit 127\n' > "$FAKE_BIN/git"
  chmod +x "$FAKE_BIN/git"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/file.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && PATH="$FAKE_BIN:$PATH" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: detached HEAD cwd returns {} with exit 0" {
  cd "$WORK"
  git checkout --detach -q
  run bash -c 'cd '"$WORK"' && printf '"'"'{"tool_name":"Edit","tool_input":{"file_path":"'"$WORK"'/file.md"},"cwd":"'"$WORK"'"}'"'"' | bash '"$GUARD"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "AT-006: detached HEAD on target-side worktree returns {}" {
  cd "$WORK"
  git checkout main -q
  git worktree add --detach "$MBG_BASE/mbg-detached" -q
  result=$(run_guard "Edit" "$MBG_BASE/mbg-detached/file.md")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: malformed JSON on main branch returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_raw "not-json")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: empty stdin on main branch returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_raw "")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: malformed JSON on non-main branch returns {}" {
  cd "$WORK"
  git checkout -b feature/malformed-json-test -q
  result=$(run_guard_raw "not-json")
  [ "$result" = "{}" ]
}

@test "AT-006/AC6: empty stdin on non-main branch returns {}" {
  cd "$WORK"
  git checkout -b feature/empty-stdin-test -q
  result=$(run_guard_raw "")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC1 (Issue #38): Edit on main branch with repo file is denied
# ---------------------------------------------------------------------------

@test "AC1: Edit on main branch returns permissionDecision deny" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "permissionDecision"
  echo "$result" | grep -q "deny"
}

@test "AC1: Edit on main branch exits with status 0" {
  cd "$WORK"
  git checkout main -q
  run bash -c 'cd '"$WORK"' && printf '"'"'{"tool_name":"Edit","tool_input":{"file_path":"'"$WORK"'/file.md"},"cwd":"'"$WORK"'"}'"'"' | bash '"$GUARD"
  [ "$status" -eq 0 ]
}

@test "AC1: Edit on main branch includes hookEventName PreToolUse" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "PreToolUse"
}

@test "AC1: Edit on main branch includes hookSpecificOutput key" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "hookSpecificOutput"
}

@test "AC1: Edit on main branch is denied for repo-internal new path (nearest existing dir)" {
  cd "$WORK"
  git checkout main -q
  # 未存在の深いパスでも最近接の既存祖先ディレクトリ（$WORK）でリポジトリ判定される
  result=$(run_guard "Edit" "$WORK/some/arbitrary/path/file.sh")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC3 (Issue #38): master branch is denied same as main
# ---------------------------------------------------------------------------

@test "AC3: Edit on master branch returns deny" {
  cd "$WORK"
  git checkout -b master -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "deny"
}

@test "AC3: Edit on master branch includes hookEventName PreToolUse" {
  cd "$WORK"
  git checkout -b master -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "PreToolUse"
}

# ---------------------------------------------------------------------------
# AC4 (Issue #181): deny message is skill-name-agnostic
# ---------------------------------------------------------------------------

@test "AC4: deny message contains branch explanation mentioning main" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "main"
}

@test "AC4: deny message does NOT contain /atdd-kit:issue" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  if echo "$result" | grep -q "atdd-kit:issue"; then
    echo "FAIL: deny message contains atdd-kit:issue skill name"
    return 1
  fi
}

@test "AC4: deny message does NOT contain /atdd-kit:autopilot" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  if echo "$result" | grep -q "atdd-kit:autopilot"; then
    echo "FAIL: deny message contains atdd-kit:autopilot skill name"
    return 1
  fi
}

@test "AC4: deny message mentions Issue-driven workflow" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit")
  echo "$result" | grep -q "Issue-driven"
}

# ---------------------------------------------------------------------------
# AC2 (Issue #38): feature and other non-main branches pass through
# ---------------------------------------------------------------------------

@test "AC2: Edit on feature branch returns {}" {
  cd "$WORK"
  git checkout -b feature/my-feature -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on develop branch returns {}" {
  cd "$WORK"
  git checkout -b develop -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on worktree-autopilot-38 branch returns {}" {
  cd "$WORK"
  git checkout -b worktree-autopilot-38 -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on Main (capital M) is not denied -- case-sensitive match" {
  # On macOS (case-insensitive filesystem), creating a branch named 'Main'
  # when 'main' already exists fails. We use 'Mainbranch' as a substitute
  # to test that non-exact matches are not denied.
  cd "$WORK"
  git checkout -b Mainbranch -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

@test "AC2: Edit on MASTER (uppercase) is not denied -- case-sensitive match" {
  cd "$WORK"
  git checkout -b MASTER -q
  result=$(run_guard "Edit")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC4(a) (Issue #38): all 4 target tools are denied on main for repo files
# ---------------------------------------------------------------------------

@test "AC4(a): Write on main branch is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write")
  echo "$result" | grep -q "deny"
}

@test "AC4(a): MultiEdit on main branch is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "MultiEdit")
  echo "$result" | grep -q "deny"
}

@test "AC4(a): NotebookEdit on main branch is denied (file_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "NotebookEdit")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC4(b) boundary: py helper checks tool_name; only Edit/Write/MultiEdit/
# NotebookEdit trigger the guard logic; other tools are immediately allowed.
# The actual AC4(b) ("hook does not start for Bash tool") is enforced by
# Claude Code's matcher, not by this script.
# ---------------------------------------------------------------------------

@test "AC4(b)-boundary: Bash tool_name on main returns {} (script allows non-target tools)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Bash")
  [ "$result" = "{}" ]
}

@test "AC4(b)-boundary: Bash tool_name on feature branch returns {}" {
  cd "$WORK"
  git checkout -b feature/test -q
  result=$(run_guard "Bash")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC1 (Issue #181): Allow-list passes throwaway temp paths on main
# （新判定フローではリポジトリ外パスとして段階 (b) で allow される。
#   観測結果 {} は従来と不変）
# ---------------------------------------------------------------------------

@test "AC1(#181): Edit /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Write /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): MultiEdit /tmp/foo.md on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "MultiEdit" "/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): NotebookEdit /tmp/nb.ipynb on main returns {} (file_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "NotebookEdit" "/tmp/nb.ipynb")
  [ "$result" = "{}" ]
}

@test "AC1(#181): NotebookEdit /tmp/nb.ipynb on main returns {} (notebook_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_nb "/tmp/nb.ipynb")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit /private/tmp/foo.md on main returns {} (macOS realpath)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/private/tmp/foo.md")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit /dev/null on main returns {}" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "/dev/null")
  [ "$result" = "{}" ]
}

@test "AC1(#181): Edit BATS_TMPDIR path on main returns {} (under /var/folders or /private/var/folders)" {
  cd "$WORK"
  git checkout main -q
  # BATS_TMPDIR is typically /var/folders/... on macOS or /tmp on Linux
  local tmpfile
  tmpfile=$(mktemp)
  result=$(run_guard "Edit" "$tmpfile")
  rm -f "$tmpfile"
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC2 (Issue #181): Allow-list passes user config dirs on main
# （HOME override で ~/.claude / ~/.config をリポジトリ内に解決させ、
#   段階 (d) の allow-list 照合を実際に通す）
# ---------------------------------------------------------------------------

@test "AC2(#181): Edit ~/.claude/config.yml on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  # Use WORK as fake HOME so ~/.claude resolves to $WORK/.claude/
  local fake_home="$WORK"
  mkdir -p "$fake_home/.claude"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.claude/config.yml"},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC2(#181): Edit ~/.config/foo on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  local fake_home="$WORK"
  mkdir -p "$fake_home/.config"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"~/.config/foo"},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC2(#181): Edit absolute ~/.claude path on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  local fake_home="$WORK"
  mkdir -p "$fake_home/.claude"
  local dotclaude_path
  dotclaude_path="$fake_home/.claude/settings.json"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$dotclaude_path" "$WORK")
  result=$(cd "$WORK" && env HOME="$fake_home" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC3 (Issue #181): Repo-managed file edit on main is still denied
# ---------------------------------------------------------------------------

@test "AC3(#181): Edit repo README.md on main is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Edit" "$WORK/README.md")
  echo "$result" | grep -q "deny"
}

@test "AC3(#181): Write to repo-internal new path on main is denied" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard "Write" "$WORK/sub/dir/new-file.sh")
  echo "$result" | grep -q "deny"
}

@test "AC3(#181): NotebookEdit repo notebook on main is denied (notebook_path key)" {
  cd "$WORK"
  git checkout main -q
  result=$(run_guard_nb "$WORK/notebook.ipynb")
  echo "$result" | grep -q "deny"
}

# ---------------------------------------------------------------------------
# AC5 (Issue #181): Boundary cases -- prefix trap and traversal
# 新判定フローではリポジトリ外パスは段階 (b) で allow されるため、
# prefix trap / traversal の deny 検証はリポジトリ内に解決される
# HOME override 方式で行い、絶対パス系 trap は is_allowed の単体検証で固定する。
# ---------------------------------------------------------------------------

@test "AC5(#181): repo-internal ~/.claudefoo on main is denied (prefix trap, HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.claudefoo"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.claudefoo/x.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): repo-internal ~/.configfoo on main is denied (prefix trap, HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.configfoo"
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.configfoo/x.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): traversal escaping ~/.claude on main is denied (HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.claude"
  # realpath resolves $WORK/.claude/../file.md -> $WORK/file.md (allow-list 外)
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.claude/../file.md"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  echo "$result" | grep -q "deny"
}

@test "AC5(#181): traversal staying in ~/.claude on main returns {} (HOME override)" {
  cd "$WORK"
  git checkout main -q
  mkdir -p "$WORK/.claude"
  # realpath resolves $WORK/.claude/../.claude/foo -> $WORK/.claude/foo (allow-list 内)
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":"%s/.claude/../.claude/foo"},"cwd":"%s"}' "$WORK" "$WORK")
  result=$(cd "$WORK" && env HOME="$WORK" bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC5(#181): is_allowed rejects absolute prefix traps (unit)" {
  # /tmpfoo, /var/foldersx, /tmp/../etc/passwd は allow-list に誤マッチしない
  run python3 -c "
import sys
sys.path.insert(0, '$ROOT/hooks')
import main_branch_guard as m
print(m.is_allowed('/tmpfoo'), m.is_allowed('/var/foldersx/foo'), m.is_allowed(m.canonicalize('/tmp/../etc/passwd', '')))
"
  [ "$status" -eq 0 ]
  [ "$output" = "False False False" ]
}

@test "AC5(#181): symlink in repo pointing to /tmp/ on main returns {} (intentional per Issue Note)" {
  cd "$WORK"
  git checkout main -q
  ln -s /tmp "$WORK/tmp-link"
  result=$(run_guard "Edit" "$WORK/tmp-link/foo.md")
  [ "$result" = "{}" ]
}

# ---------------------------------------------------------------------------
# AC6 extension: tool_input key missing / empty cases → fail-safe {} (DoD)
# ---------------------------------------------------------------------------

@test "AC6: tool_input key missing on main returns {} (fail-safe per DoD)" {
  cd "$WORK"
  git checkout main -q
  local json
  json=$(printf '{"tool_name":"Edit","cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC6: empty tool_input on main returns {} (fail-safe per DoD)" {
  cd "$WORK"
  git checkout main -q
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}

@test "AC6: empty file_path in tool_input on main returns {} (fail-safe per DoD)" {
  cd "$WORK"
  git checkout main -q
  local json
  json=$(printf '{"tool_name":"Edit","tool_input":{"file_path":""},"cwd":"%s"}' "$WORK")
  result=$(cd "$WORK" && bash "$GUARD" <<< "$json")
  [ "$result" = "{}" ]
}
