#!/usr/bin/env bats
# @covers: lib/fa-merge-steps.sh lib/full-autopilot-run.sh
# =============================================================================
# 本番 merge 経路の統合テスト（#318 review #2/#3）
# throwaway git repo で実 rebase+merge を検証し、__default_merge が **実コマンドを配線して
# 実際に merge する**（no-op success でない）ことを pin する。gh 非依存・main 非接触。
#
#   FM-1: fa-merge-steps の rebase+merge が feature ブランチを実際に main へ統合する
#   FM-2: __default_merge が実ステップを走らせ main を前進させる（本番経路が no-op でない）
#   FM-3: __default_merge は merge-lease busy が retry 上限超で exit 3（false merge-failed でない）
# =============================================================================

setup() {
  ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  REPO="$(mktemp -d)"
  git -C "$REPO" init -q
  git -C "$REPO" config user.email t@t; git -C "$REPO" config user.name t
  git -C "$REPO" checkout -q -b main
  printf 'base\n' > "$REPO/f.txt"; git -C "$REPO" add .; git -C "$REPO" commit -qm base
  git -C "$REPO" checkout -q -b 318-feat
  printf 'feat\n' > "$REPO/feat.txt"; git -C "$REPO" add .; git -C "$REPO" commit -qm "feat work"
  git -C "$REPO" checkout -q main
  STORE="$(mktemp -d)"
}

teardown() { rm -rf "$REPO" "$STORE"; }

@test "FM-1: fa-merge-steps rebase+merge integrates a feature branch into main (real git)" {
  FA_REPO="$REPO" FA_MERGE_BASE=main bash "$ROOT/lib/fa-merge-steps.sh" rebase 318-feat
  FA_REPO="$REPO" FA_MERGE_BASE=main bash "$ROOT/lib/fa-merge-steps.sh" merge 318-feat
  git -C "$REPO" checkout -q main
  [ -f "$REPO/feat.txt" ]                              # main now has the feature file
  git -C "$REPO" log --oneline main | grep -q "feat work"
}

# FA_MERGE_CMD を **注入しない**ことで本番経路 __default_merge を実走させる（#3: 本番経路を実際にテスト）。
@test "FM-2: production merge path (__default_merge) actually advances main (not a no-op)" {
  printf '318\n' > "$STORE/queue"
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fmtest \
    FA_REPO="$REPO" FA_BRANCH=318-feat FA_MERGE_BASE=main \
    FA_GATE_CMD=true FA_REGRESSION_CMD=true \
    FA_RUNDIR="$STORE/run" FA_LOG="$STORE/log" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $STORE/queue" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-ok.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    bash "$ROOT/lib/full-autopilot-run.sh" 1
  grep -q 'merged issue=318' "$STORE/log"
  git -C "$REPO" checkout -q main
  [ -f "$REPO/feat.txt" ]                       # 本番経路が実際に main を前進させた
}

# merge-lease busy（retry 上限超）は exit 3 → false merge-failed でなく escalate に振られる（#6）。
@test "FM-3: merge-lease busy routes to escalate (not silent merge-failed)" {
  printf '318\n' > "$STORE/queue"
  NL="$STORE/nl"; : > "$NL"
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= bash "$ROOT/lib/lease-store.sh" acquire merge main-merge other
  LEASE_STORE_DIR="$STORE" GITHUB_ACTIONS= FA_SESSION=fmtest \
    FA_REPO="$REPO" FA_BRANCH=318-feat FA_MERGE_BASE=main \
    FA_GATE_CMD=true FA_REGRESSION_CMD=true FA_MERGE_LEASE_RETRIES=1 FA_MERGE_LEASE_WAIT=0 \
    FA_RUNDIR="$STORE/run" FA_LOG="$STORE/log" FA_POLL_INTERVAL=0.05 \
    FA_QUEUE_CMD="cat $STORE/queue" \
    FA_LAUNCH_CMD="bash $ROOT/tests/fixtures/fa-mock-ok.sh" \
    FA_RESULT_CMD="bash $ROOT/tests/fixtures/fa-mock-result.sh" \
    FA_NOTIFY_CMD="bash $ROOT/tests/fixtures/fa-mock-notify.sh" NOTIFY_LOG="$NL" \
    bash "$ROOT/lib/full-autopilot-run.sh" 1
  grep -q 'merge-deferred issue=318' "$STORE/log"
  grep -q '^escalate 318$' "$NL"
}
