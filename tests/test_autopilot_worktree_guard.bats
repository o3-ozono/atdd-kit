#!/usr/bin/env bats
# @covers: hooks/autopilot-worktree-guard.sh
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

# ============================================================
# Group G: AC1-AC5 cwd-detection regression (Issue #116)
# ============================================================
# Helper: build JSON payloads with explicit cwd argument

json_edit_cwd() {
  # $1 = file_path, $2 = cwd
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"Edit","tool_input":{"file_path":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$2"
}

json_write_cwd() {
  # $1 = file_path, $2 = cwd
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"Write","tool_input":{"file_path":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$2"
}

json_bash_cwd() {
  # $1 = command, $2 = cwd
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"Bash","tool_input":{"command":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$2"
}

json_multiedit_cwd() {
  # $1 = file_path, $2 = cwd
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"MultiEdit","tool_input":{"file_path":sys.argv[1],"edits":[]},"cwd":sys.argv[2]}))
' "$1" "$2"
}

json_notebookedit_cwd() {
  # $1 = notebook_path, $2 = cwd
  python3 -c '
import json, sys
print(json.dumps({"tool_name":"NotebookEdit","tool_input":{"notebook_path":sys.argv[1]},"cwd":sys.argv[2]}))
' "$1" "$2"
}

# worktree_cwd: fake cwd under .claude/worktrees/<name>/ rooted at HOME-based path.
# Uses $HOME to avoid macOS TMPDIR being under /private/var/folders which is in
# ALLOW_PREFIXES — that would cause hook to allow writes that should be blocked.
make_worktree_cwd() {
  # $1 = worktree name (e.g. autopilot-116)
  echo "${HOME}/.claude/worktrees/$1"
}

# ---- AC1: Regression — env unset + cwd-detection blocks outside writes ----

@test "G-AC1-1: env unset + cwd-detect mode: Edit outside worktree -> block (exit 2)" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_edit_cwd /etc/passwd "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC1-2: env unset + cwd-detect mode: Write outside worktree -> block (exit 2)" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_write_cwd "$HOME/escaped.txt" "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC1-3: env unset + cwd-detect mode: Bash redirect outside -> block (exit 2)" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_bash_cwd 'echo x > /etc/badfile' "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC1-4: env unset + cwd-detect mode: MultiEdit outside worktree -> block" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_multiedit_cwd /etc/passwd "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC1-5: env unset + cwd-detect mode: NotebookEdit outside worktree -> block" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_notebookedit_cwd /etc/evil.ipynb "$wt_cwd")"
  [ "$status" -eq 2 ]
}

# ---- AC2: cwd-detection auto-detection variations ----

@test "G-AC2-1: cwd directly under .claude/worktrees/<name>/ -> detect and block outside" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_write_cwd "$HOME/outside.txt" "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC2-2: cwd nested under worktree subdir -> detect worktree root and block outside" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)/hooks/subdir"
  run invoke_hook "$(json_write_cwd "$HOME/outside.txt" "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC2-3: cwd-detect mode: Write inside detected worktree -> allow" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  local wt_root
  wt_root="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt_cwd")"
  run invoke_hook "$(json_write_cwd "${wt_root}/inside.txt" "$wt_cwd")"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC2-4: cwd-detect mode: Edit inside detected worktree -> allow" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  local wt_root
  wt_root="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt_cwd")"
  run invoke_hook "$(json_edit_cwd "${wt_root}/src/foo.py" "$wt_cwd")"
  [ "$status" -eq 0 ]
}

@test "G-AC2-5: cwd-detect mode: write to /tmp -> allow (allow-list)" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_write_cwd /tmp/scratch.log "$wt_cwd")"
  [ "$status" -eq 0 ]
}

# ---- AC3: env-var override precedence ----

@test "G-AC3-1: env=W_env, cwd=W_cwd (different) -> env wins (block target outside W_env)" {
  local wt_env
  wt_env="$(make_worktree_cwd autopilot-env)"
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-cwd)"
  export ATDD_AUTOPILOT_WORKTREE="$wt_env"
  # Use $HOME-based path as target: definitely outside W_env and not in allow-list
  run invoke_hook "$(json_write_cwd "$HOME/outside-w-env.txt" "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC3-2: env=W_env, cwd=W_cwd -> env wins (allow target inside W_env)" {
  local wt_env
  wt_env="$(make_worktree_cwd autopilot-env)"
  local wt_env_real
  wt_env_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt_env")"
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-cwd)"
  export ATDD_AUTOPILOT_WORKTREE="$wt_env"
  run invoke_hook "$(json_write_cwd "${wt_env_real}/allowed.txt" "$wt_cwd")"
  [ "$status" -eq 0 ]
}

@test "G-AC3-3: env set + cwd unrelated -> env mode, unrelated cwd ignored" {
  local wt_env
  wt_env="$(make_worktree_cwd autopilot-env)"
  export ATDD_AUTOPILOT_WORKTREE="$wt_env"
  run invoke_hook "$(json_write_cwd "$HOME/outside.txt" "/tmp/unrelated")"
  [ "$status" -eq 2 ]
}

# ---- AC4: non-autopilot session no-op ----

@test "G-AC4-1: env unset, cwd key missing from JSON -> no-op (exit 0)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook '{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"}}'
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC4-2: env unset, cwd empty string -> no-op (exit 0)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook '{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"},"cwd":""}'
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC4-3: env unset, cwd null -> no-op (exit 0)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook '{"tool_name":"Write","tool_input":{"file_path":"/etc/passwd"},"cwd":null}'
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC4-4: env unset, cwd=.claude/worktrees without name segment -> no-op" {
  unset ATDD_AUTOPILOT_WORKTREE
  local base
  base="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "${TMPDIR:-/tmp}")"
  run invoke_hook "$(json_write_cwd /etc/passwd "${base}/.claude/worktrees")"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC4-5: env unset, cwd unrelated path -> no-op (exit 0)" {
  unset ATDD_AUTOPILOT_WORKTREE
  run invoke_hook "$(json_write_cwd /etc/passwd /tmp/normal-session)"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}

@test "G-AC4-6: env='', cwd under worktree -> cwd-detection activates and blocks outside" {
  export ATDD_AUTOPILOT_WORKTREE=""
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_write_cwd "$HOME/outside.txt" "$wt_cwd")"
  [ "$status" -eq 2 ]
}

# ---- AC5: parallel session isolation ----

@test "G-AC5-1: session A writes in A's worktree -> allow" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_a_cwd
  wt_a_cwd="$(make_worktree_cwd autopilot-A)"
  local wt_a_real
  wt_a_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt_a_cwd")"
  run invoke_hook "$(json_write_cwd "${wt_a_real}/file.txt" "$wt_a_cwd")"
  [ "$status" -eq 0 ]
}

@test "G-AC5-2: session B attempts cross-boundary write into A's worktree -> block" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_a_cwd
  wt_a_cwd="$(make_worktree_cwd autopilot-A)"
  local wt_a_real
  wt_a_real="$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$wt_a_cwd")"
  local wt_b_cwd
  wt_b_cwd="$(make_worktree_cwd autopilot-B)"
  # B writes into A's worktree -> should block
  run invoke_hook "$(json_write_cwd "${wt_a_real}/file.txt" "$wt_b_cwd")"
  [ "$status" -eq 2 ]
}

# ---- AC6-ext: additional coverage ----

@test "G-AC6-ext-1: MultiEdit env-set mode outside -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_multiedit_cwd /etc/passwd "$W")"
  [ "$status" -eq 2 ]
}

@test "G-AC6-ext-2: MultiEdit env-set mode inside -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_multiedit_cwd "$W/src/foo.py" "$W")"
  [ "$status" -eq 0 ]
}

@test "G-AC6-ext-3: NotebookEdit env-set mode outside -> block" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_notebookedit_cwd /etc/evil.ipynb "$W")"
  [ "$status" -eq 2 ]
}

@test "G-AC6-ext-4: NotebookEdit env-set mode inside -> allow" {
  export ATDD_AUTOPILOT_WORKTREE="$W"
  run invoke_hook "$(json_notebookedit_cwd "$W/notebook.ipynb" "$W")"
  [ "$status" -eq 0 ]
}

@test "G-AC6-ext-5: MultiEdit cwd-detect mode outside -> block" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_multiedit_cwd /etc/passwd "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC6-ext-6: NotebookEdit cwd-detect mode outside -> block" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_notebookedit_cwd /etc/evil.ipynb "$wt_cwd")"
  [ "$status" -eq 2 ]
}

@test "G-AC6-ext-7: git bypass in cwd-detect mode -> allow" {
  unset ATDD_AUTOPILOT_WORKTREE
  local wt_cwd
  wt_cwd="$(make_worktree_cwd autopilot-116)"
  run invoke_hook "$(json_bash_cwd 'git push origin main' "$wt_cwd")"
  [ "$status" -eq 0 ]
  [ "$output" = "{}" ]
}
