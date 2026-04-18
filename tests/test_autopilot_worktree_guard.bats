#!/usr/bin/env bats

# Issue #111: autopilot-worktree-guard.sh boundary enforcement
#
# AC1: env export (covered by commands/autopilot.md assertion)
# AC2: Edit/Write/MultiEdit/NotebookEdit file_path outside W -> block
# AC3: Bash mutating target outside W -> block (shell-aware tokenization)
# AC4: allow-list (/tmp, /var/folders, /private/var/folders, /dev/null, <W>/.git) -> allow
# AC5: first token git|gh -> bypass
# AC6: env unset -> no-op

HOOK="${BATS_TEST_DIRNAME}/../hooks/autopilot-worktree-guard.sh"

setup() {
  # Defense in depth: always unset env to avoid leak across tests
  unset ATDD_AUTOPILOT_WORKTREE

  # Per-test worktree directory
  W="$(mktemp -d)"
  # Canonicalize (macOS /var -> /private/var)
  W="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$W")"
  mkdir -p "$W/.git"
  export W
}

teardown() {
  [ -n "${W:-}" ] && [ -d "$W" ] && rm -rf "$W"
  unset ATDD_AUTOPILOT_WORKTREE
}

# --- helpers ---
invoke_hook() {
  local json="$1"
  # Run hook with stdin; capture stdout/stderr/exit
  printf '%s' "$json" | bash "$HOOK"
}

json_edit() {
  # $1 = file_path
  printf '{"tool_name":"Edit","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "${W}"
}

json_write() {
  printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"cwd":"%s"}' "$1" "${W}"
}

json_bash() {
  # $1 = command
  # use python3 for JSON-safe escaping
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "${W}"
}

# ============================================================
# Group E: AC6 env unset -> complete no-op
# ============================================================

@test "AC6: hook exits 0 with {} when ATDD_AUTOPILOT_WORKTREE is unset (Edit)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook "$(json_edit /etc/passwd)"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "AC6: hook exits 0 with {} when env unset (Write to arbitrary path)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook "$(json_write /tmp/foo)"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "AC6: hook exits 0 with {} when env unset (Bash with mutating target)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook "$(json_bash 'rm -rf /tmp/x')"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

# ============================================================
# Group A: AC2/AC4 in-bounds write -> allow
# ============================================================

@test "AC2: Edit inside worktree -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_edit "$W/src/foo.ts")"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "AC2: Write inside worktree subdir -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write "$W/deep/nested/file.txt")"
  [ "$status" -eq 0 ]
}

@test "AC4: Write to /tmp -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write /tmp/autopilot-scratch.log)"
  [ "$status" -eq 0 ]
}

@test "AC4: Write to /dev/null -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write /dev/null)"
  [ "$status" -eq 0 ]
}

@test "AC4: Write to <W>/.git/config -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write "$W/.git/config")"
  [ "$status" -eq 0 ]
}

# ============================================================
# Group B: AC2 out-of-bounds -> block
# ============================================================

@test "AC2: Edit to /etc/passwd -> block (exit 2)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_edit /etc/passwd)"
  [ "$status" -eq 2 ]
  # stderr must contain worktree= and violating= (path may be canonicalized, e.g. /etc -> /private/etc on macOS)
  [[ "$stderr" == *"worktree=$W"* ]] || [[ "$output" == *"worktree=$W"* ]]
  [[ "$stderr" == *"violating="*"/etc/passwd"* ]] || [[ "$output" == *"violating="*"/etc/passwd"* ]]
}

@test "AC2: Write to main repo (outside W) -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  local target="/tmp/outside-$$"
  # Use a non-W, non-allowed path
  local outside="$HOME/some-other-repo/file.md"
  run invoke_hook "$(json_write "$outside")"
  [ "$status" -eq 2 ]
}

@test "AC2: Write to .claire/ typo path -> block (regression from #104 cleanup)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # .claire/ is a typo of .claude/ -- must be detected.
  # Use $HOME as a known non-allow-listed parent so this reliably falls outside
  # the worktree and outside allow-list prefixes.
  run invoke_hook "$(json_write "$HOME/.claire/worktrees/autopilot-76/junk.md")"
  [ "$status" -eq 2 ]
}

@test "AC2: Write to outside worktree (non-allow-list parent) -> block (path traversal)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # $HOME is not in the allow-list and not inside W; must be blocked.
  run invoke_hook "$(json_write "$HOME/escaped.txt")"
  [ "$status" -eq 2 ]
}

# ============================================================
# Group C: AC4 allow-list edge
# ============================================================

@test "AC4: Write to /var/folders (macOS mktemp) -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write /var/folders/xx/yy/T/scratch)"
  [ "$status" -eq 0 ]
}

@test "AC4: Write to /private/var/folders -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_write /private/var/folders/xx/yy/T/scratch)"
  [ "$status" -eq 0 ]
}

# ============================================================
# Group D: AC5 git/gh bypass
# ============================================================

@test "AC5: git push -> allow (no target check)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'git push origin feat/111')"
  [ "$status" -eq 0 ]
}

@test "AC5: git pull -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'git pull')"
  [ "$status" -eq 0 ]
}

@test "AC5: gh issue edit -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'gh issue edit 111 --remove-label foo')"
  [ "$status" -eq 0 ]
}

@test "AC5: gh pr create -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'gh pr create --draft')"
  [ "$status" -eq 0 ]
}

@test "AC5: git commit -m -> allow (even with message containing >)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'git commit -m "fix: a > b"')"
  [ "$status" -eq 0 ]
}

@test "AC5: git clone /etc/x -> allow (bypass per AC5 literal)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'git clone /etc/x')"
  [ "$status" -eq 0 ]
}

# ============================================================
# Group B': AC3 Bash mutating target -> block
# ============================================================

@test "AC3: Bash redirect > outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo hello > /etc/passwd')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash redirect >> outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo line >> /etc/hosts')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash cp to outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'cp foo.txt /etc/newfoo')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash rm -rf outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'rm -rf /etc/something')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash mv to outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'mv foo.txt /etc/movedfoo')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash mkdir outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'mkdir -p /etc/autopilot-evil')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash touch outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'touch /etc/foo')"
  [ "$status" -eq 2 ]
}

@test "AC3: Bash tee -a outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo x | tee -a /etc/log')"
  [ "$status" -eq 2 ]
}

# ============================================================
# Group F: Bash parsing edge cases (>=8 cases per Plan)
# ============================================================

@test "AC3-F1: quoted literal >  -> NOT treated as redirect" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo "a > b"')"
  [ "$status" -eq 0 ]
}

@test "AC3-F2: single-quoted literal > -> NOT treated as redirect" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash "echo 'a > b'")"
  [ "$status" -eq 0 ]
}

@test "AC3-F3: 2>&1 -> NOT treated as mutating redirect" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'ls /etc 2>&1')"
  [ "$status" -eq 0 ]
}

@test "AC3-F4: 2> /tmp/err -> allow (/tmp allow-listed)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'ls /etc 2> /tmp/err')"
  [ "$status" -eq 0 ]
}

@test "AC3-F5: redirect to inside W -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash "echo hello > $W/out.txt")"
  [ "$status" -eq 0 ]
}

@test "AC3-F6: chain && with outside redirect -> block (second cmd violates)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash "cd $W && echo x > /etc/badfile")"
  [ "$status" -eq 2 ]
}

@test "AC3-F7: pipe | with outside redirect -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'cat foo | tee /etc/dst')"
  [ "$status" -eq 2 ]
}

@test "AC3-F8: relative path resolved against cwd W -> allow when inside" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # cwd is W; relative path inside W -> allow
  run invoke_hook "$(json_bash 'echo hello > relative.txt')"
  [ "$status" -eq 0 ]
}

@test "AC3-F9: /dev/null redirect -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'noisy_cmd > /dev/null 2>&1')"
  [ "$status" -eq 0 ]
}

@test "AC3-F10: >| (noclobber override) outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo x >| /etc/out')"
  [ "$status" -eq 2 ]
}

@test "AC3-F11: &> (all streams) outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo hi &> /etc/out')"
  [ "$status" -eq 2 ]
}

@test "AC3-F12: &>> (append all streams) outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'echo log &>> /etc/log')"
  [ "$status" -eq 2 ]
}

@test "AC3-F13: ; separator with outside redirect -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_bash 'ls ; echo x > /etc/a')"
  [ "$status" -eq 2 ]
}

@test "AC3-F14: heredoc with outer redirect outside W -> block (outer > detected)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # heredoc body extraction is a Known Limitation, but the outer
  # "> /etc/badfile" redirect should still be detected by shlex tokenization.
  run invoke_hook "$(json_bash $'cat <<EOF > /etc/badfile\ncontent\nEOF')"
  [ "$status" -eq 2 ]
}

@test "AC3-F15: \$() subshell outer redirect outside W -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # shlex treats \$(date) as a literal token; the outer "> /etc/out" is a
  # separate redirect that MUST block. Inner-subshell content detection is
  # an intentional Known Limitation.
  run invoke_hook "$(json_bash 'echo $(date) > /etc/out')"
  [ "$status" -eq 2 ]
}

@test "AC3-F16: ~ expansion to outside W -> block (python os.path.expanduser)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # Literal "~/..." is expanded by canonicalize() via os.path.expanduser,
  # landing outside W (and outside allow-list).
  run invoke_hook "$(json_bash 'echo x > ~/evil.txt')"
  [ "$status" -eq 2 ]
}

# --- Group C': AC4 symlink canonicalization (prevents silent false negative) ---

@test "AC4-C-symlink: ln -s /etc <W>/link; write via link -> block (canonicalize)" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  # Create a symlink inside W that escapes to /etc; write via the link must
  # resolve to /etc/foo and be blocked. Guards against Plan Risk #3
  # (symlink-based silent false negative).
  ln -s /etc "$W/link"
  run invoke_hook "$(json_write "$W/link/escape-me")"
  [ "$status" -eq 2 ]
}

# ============================================================
# AC1 covered separately via docs assertion
# ============================================================

@test "AC1: commands/autopilot.md Phase 0.9 documents ATDD_AUTOPILOT_WORKTREE export" {
  grep -q "ATDD_AUTOPILOT_WORKTREE" "${BATS_TEST_DIRNAME}/../commands/autopilot.md"
}
