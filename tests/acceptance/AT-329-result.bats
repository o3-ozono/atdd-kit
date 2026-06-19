#!/usr/bin/env bats
# @covers: lib/full-autopilot-run.sh commands/setup-github.md skills/autopilot/SKILL.md
# =============================================================================
# AT-329-result: merge-ready が GitHub ラベルで二重確認される（US-3 / 真因3）
# AT-329-3a: (consume) ラベル不在なら failed に倒れる
# AT-329-3b: (consume) 自己申告＋ラベル両立で merge-ready
# AT-329-3c: (produce) システムが merge-ready ラベルを実際に生成する
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)"
  RUN_PATH="$ROOT/lib/full-autopilot-run.sh"
  STORE="$(mktemp -d)"
  CC="$(mktemp -d)"; mkdir -p "$CC/active"
  : > "$CC/samples"; : > "$CC/launched"; : > "$CC/merged"
  RUNDIR="$CC/run"; mkdir -p "$RUNDIR"
  # Create fake out.json with is_error:false (self-report: success)
  ISSUE="801"
  printf '{"is_error":false,"result":"ok"}\n' > "$RUNDIR/$ISSUE.out.json"
}

teardown() { rm -rf "$STORE" "$CC"; }

# Helper: source __default_result from the script in a subshell where `gh` is stubbed
call_default_result() {
  local issue="$1" gh_labels="$2"
  # Create a stub `gh` that returns the specified labels
  local bin="$STORE/stubbin"
  mkdir -p "$bin"
  cat > "$bin/gh" <<STUBEOF
#!/usr/bin/env bash
# stub: gh issue view <issue> --json labels --jq '.labels[].name'
echo "$gh_labels"
STUBEOF
  chmod +x "$bin/gh"
  # Source __default_result via a minimal wrapper (extract the function from the script)
  PATH="$bin:$PATH" \
  FA_RUNDIR="$RUNDIR" \
    bash -c "
      . '$RUN_PATH' 2>/dev/null; __default_result '$issue'
    " 2>/dev/null
}

# AT-329-3a: is_error:false だが merge-ready ラベルが不在なら failed
@test "AT-329-3a: is_error:false with no merge-ready label returns failed" {
  result=$(call_default_result "$ISSUE" "in-progress")
  [ "$result" = "failed" ]
}

# AT-329-3a: ラベルが全く無い場合も failed
@test "AT-329-3a: is_error:false with no labels at all returns failed" {
  result=$(call_default_result "$ISSUE" "")
  [ "$result" = "failed" ]
}

# AT-329-3b: is_error:false かつ merge-ready ラベル存在で merge-ready
@test "AT-329-3b: is_error:false with merge-ready label returns merge-ready" {
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "merge-ready" ]
}

# AT-329-3b: merge-ready は他ラベルと混在していても検出される
@test "AT-329-3b: merge-ready label detected alongside other labels" {
  result=$(call_default_result "$ISSUE" "$(printf 'in-progress\nmerge-ready\ntype:development')")
  [ "$result" = "merge-ready" ]
}

# AT-329-3a: is_error:true のときは merge-ready ラベルがあっても failed（自己申告失敗を尊重）
@test "AT-329-3a: is_error:true with merge-ready label still returns failed" {
  # Override with an is_error:true JSON
  printf '{"is_error":true,"result":"err"}\n' > "$RUNDIR/$ISSUE.out.json"
  result=$(call_default_result "$ISSUE" "merge-ready")
  [ "$result" = "failed" ]
}

# AT-329-3c (produce): commands/setup-github.md のラベル定義に merge-ready が含まれる
@test "AT-329-3c(produce): setup-github.md defines the merge-ready label" {
  grep -q 'merge-ready' "$ROOT/commands/setup-github.md"
  grep -q '"merge-ready"' "$ROOT/commands/setup-github.md"
}

# AT-329-3c (produce): Summary のラベル件数が定義数と一致（16）
@test "AT-329-3c(produce): setup-github.md label count in Summary matches 16" {
  grep -q 'Labels: 16 created' "$ROOT/commands/setup-github.md"
}

# AT-329-3c (produce): autopilot SKILL.md に hand-off 成功時 merge-ready ラベル付与が記述される
@test "AT-329-3c(produce): autopilot SKILL.md documents merge-ready label on hand-off success" {
  AP="$ROOT/skills/autopilot/SKILL.md"
  # hand-off success + merge-ready label assignment
  grep -q 'merge-ready.*GitHub.*ラベル\|gh issue edit.*add-label merge-ready\|add-label merge-ready' "$AP"
}

# AT-329-3c (produce): 通常起動（FA_HANDOFF=1 なし）ではラベル付与経路を起動しない
@test "AT-329-3c(produce): autopilot SKILL.md restricts label add to FA_HANDOFF=1 runs only" {
  AP="$ROOT/skills/autopilot/SKILL.md"
  grep -q 'FA_HANDOFF=1.*マーカー\|FA_HANDOFF=1.*のみ\|通常.*起動.*ラベル.*しない\|通常起動.*AL-1.*ではラベル付与経路を起動しない' "$AP"
}
