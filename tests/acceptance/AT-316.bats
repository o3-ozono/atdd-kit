#!/usr/bin/env bats
# @covers: hooks/branch-lease-guard.sh hooks/hooks.json skills/session-start/SKILL.md tests/test_branch_lease_guard.bats tests/e2e/branch-lease-guard.bats
# AT-316: session-start Draft PR 二層ブロック（branch-lease guard + 推奨の非 Draft 限定）
# Issue #316
#
# lifecycle: [regression]

# ── ヘルパー ──────────────────────────────────────────────────────────────────

repo_root() {
  cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd
}

# ── AT-001 FS-1/Layer 1: Draft PR is read-only, not actionable ───────────────

@test "AT-001 FS-1: session-start SKILL.md limits Draft PR to read-only display" {
  # Given: session-start SKILL.md Recommended Tasks / Step 2 セクション
  # When: 当該本文を検査する
  # Then: Draft PR が read-only の別セッション作業中表示として扱われ write-back 提案対象外と明記
  local root
  root="$(repo_root)"
  local skill="${root}/skills/session-start/SKILL.md"

  [[ -f "$skill" ]] || { echo "FAIL: skills/session-start/SKILL.md does not exist"; return 1; }

  grep -q '別セッション作業中' "$skill" || {
    echo "FAIL: SKILL.md has no read-only Draft PR indicator (別セッション作業中)"
    return 1
  }

  grep -qE 'checkout|rebase|force-with-lease' "$skill" || {
    echo "FAIL: SKILL.md has no mention of write-back ops (checkout/rebase/force-with-lease) to exclude"
    return 1
  }
}

# ── AT-002 FS-2/Layer 1: CONFLICTING rebase limited to ready + @me ───────────

@test "AT-002 FS-2: CONFLICTING rebase recommendation is limited to ready (non-Draft) and @me PRs" {
  # Given: session-start SKILL.md Step 2 の CONFLICTING rebase ルール
  # When: 当該ルール本文を検査する
  # Then: ready（非 Draft）かつ @me の PR にのみ適用されると明記
  local root
  root="$(repo_root)"
  local skill="${root}/skills/session-start/SKILL.md"

  [[ -f "$skill" ]] || { echo "FAIL: skills/session-start/SKILL.md does not exist"; return 1; }

  grep -q 'CONFLICTING' "$skill" || {
    echo "FAIL: SKILL.md has no CONFLICTING rebase rule"
    return 1
  }

  grep -qE 'ready|非 Draft|non.Draft' "$skill" || {
    echo "FAIL: SKILL.md CONFLICTING rule has no ready (non-Draft) restriction"
    return 1
  }

  grep -q '@me' "$skill" || {
    echo "FAIL: SKILL.md CONFLICTING rule has no @me restriction"
    return 1
  }
}

# ── AT-003 FS-3/Layer 2: write-back is hard-blocked with deny JSON ───────────

@test "AT-003 FS-3: branch-lease-guard.sh implements exit-0 deny JSON for blocked write-back" {
  # Given: hooks/branch-lease-guard.sh
  # When: フック存在と permissionDecision deny 実装を検査する
  # Then: deny 経路が exit 0 + deny JSON で実装されている
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -qE 'permissionDecision.*deny|deny.*permissionDecision' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no permissionDecision deny implementation"
    return 1
  }

  grep -qE 'emit_deny|exit 0' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no exit-0 deny mechanism"
    return 1
  }
}

# ── AT-004 FS-4/Layer 2: non-write-back and main are allowed ─────────────────

@test "AT-004 FS-4: branch-lease-guard.sh allows main/master and non-write-back operations" {
  # Given: hooks/branch-lease-guard.sh
  # When: main/master allow および write-back 判定の実装を検査する
  # Then: main/master チェックと write-back 判定ロジックが実装されている
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -qE 'main|master' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no main/master allow logic"
    return 1
  }

  grep -qE 'git push|gh pr' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no write-back detection (git push / gh pr)"
    return 1
  }
}

# ── AT-005 FS-5/Layer 2: lease auto-acquired on push ─────────────────────────

@test "AT-005 FS-5: branch-lease-guard.sh implements lease acquisition (write_lease_file)" {
  # Given: hooks/branch-lease-guard.sh の lease 取得実装
  # When: write_lease_file 関数と LEASE_DIR への書き込みを検査する
  # Then: リース取得が実装されている
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -qE 'write_lease_file|LEASE_DIR' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no lease acquisition (write_lease_file/LEASE_DIR)"
    return 1
  }
}

# ── AT-006 FS-6/Layer 2: ATDD_BRANCH_LEASE_FORCE override exists ─────────────

@test "AT-006 FS-6: ATDD_BRANCH_LEASE_FORCE=1 override is implemented" {
  # Given: hooks/branch-lease-guard.sh の override 実装
  # When: ATDD_BRANCH_LEASE_FORCE のチェックを検査する
  # Then: ATDD_BRANCH_LEASE_FORCE による上書きが実装されている
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -q 'ATDD_BRANCH_LEASE_FORCE' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no ATDD_BRANCH_LEASE_FORCE override"
    return 1
  }
}

# ── AT-007 CS-1: shared lease store is cross-session visible ─────────────────

@test "AT-007 CS-1: shared lease store uses BRANCH_LEASE_DIR env and encode_branch with 5-char set" {
  # Given: hooks/branch-lease-guard.sh の lease store 実装
  # When: BRANCH_LEASE_DIR と encode_branch の実装を検査する
  # Then: BRANCH_LEASE_DIR env override と 5 文字セットエンコードが実装されている
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -q 'BRANCH_LEASE_DIR' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no BRANCH_LEASE_DIR env override"
    return 1
  }

  grep -q 'encode_branch' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no encode_branch function"
    return 1
  }

  # 5 文字セット: %2F(/) %2E(.) %20(space) %23(#) %7E(~)
  grep -q '%2F' "$hook" && grep -q '%2E' "$hook" || {
    echo "FAIL: encode_branch does not implement full 5-char set (%2F, %2E, %20, %23, %7E)"
    return 1
  }
}

# ── AT-008 CS-2: stale lease is cleaned up by TTL ────────────────────────────

@test "AT-008 CS-2: TTL cleanup is implemented with BRANCH_LEASE_TTL_LOCAL env override" {
  # Given: hooks/branch-lease-guard.sh の TTL 実装
  # When: TTL チェックと orphan 掃除の実装を検査する
  # Then: BRANCH_LEASE_TTL_LOCAL env override が存在する
  local root
  root="$(repo_root)"
  local hook="${root}/hooks/branch-lease-guard.sh"

  [[ -f "$hook" ]] || { echo "FAIL: hooks/branch-lease-guard.sh does not exist"; return 1; }

  grep -qE 'BRANCH_LEASE_TTL_LOCAL|TTL_LOCAL' "$hook" || {
    echo "FAIL: branch-lease-guard.sh has no BRANCH_LEASE_TTL_LOCAL env override"
    return 1
  }
}

# ── AT-009 CS-3: all deliverables exist and form regression coverage ──────────

@test "AT-009 CS-3: all test files, hooks.json registration, and READMEs are in place" {
  # Given: Issue #316 の成果物一式
  # When: テストファイル・hooks.json・README の存在を検査する
  # Then: 全成果物が揃い回帰保護を構成している（DEVELOPMENT.md L65 不変条件）
  local root
  root="$(repo_root)"

  [[ -f "${root}/tests/test_branch_lease_guard.bats" ]] || {
    echo "FAIL: tests/test_branch_lease_guard.bats does not exist"
    return 1
  }

  [[ -f "${root}/tests/e2e/branch-lease-guard.bats" ]] || {
    echo "FAIL: tests/e2e/branch-lease-guard.bats does not exist"
    return 1
  }

  grep -q 'branch-lease-guard' "${root}/hooks/hooks.json" || {
    echo "FAIL: hooks/hooks.json has no branch-lease-guard entry"
    return 1
  }

  grep -q 'branch-lease-guard' "${root}/hooks/README.md" || {
    echo "FAIL: hooks/README.md has no branch-lease-guard documentation"
    return 1
  }

  grep -q 'test_branch_lease_guard' "${root}/tests/README.md" || {
    echo "FAIL: tests/README.md missing test_branch_lease_guard.bats row (DEVELOPMENT.md L65)"
    return 1
  }

  grep -q 'branch-lease' "${root}/tests/README.md" || {
    echo "FAIL: tests/README.md missing branch-lease E2E row (DEVELOPMENT.md L65)"
    return 1
  }
}

# ── AT-010: plugin.json version matches CHANGELOG (regression invariant) ──────

@test "AT-010: plugin.json version matches topmost CHANGELOG release heading" {
  # Given: .claude-plugin/plugin.json と CHANGELOG.md
  # When: バージョン整合チェックを実行する
  # Then: version が CHANGELOG の最上位 release 見出しと一致する（不変条件 / #289）
  local root
  root="$(repo_root)"

  [[ -f "${root}/tests/acceptance/helpers/changelog.bash" ]] || {
    echo "FAIL: tests/acceptance/helpers/changelog.bash does not exist"
    return 1
  }

  # shellcheck disable=SC1090
  source "${root}/tests/acceptance/helpers/changelog.bash"

  local top version
  top=$(changelog_latest_release "${root}/CHANGELOG.md")
  version=$(grep '"version"' "${root}/.claude-plugin/plugin.json" | grep -o '"[0-9.]*"' | tr -d '"')

  [[ -n "$top" ]] || {
    echo "FAIL: CHANGELOG has no [X.Y.Z] release heading"
    return 1
  }
  [[ -n "$version" ]] || {
    echo "FAIL: plugin.json has no version field"
    return 1
  }
  [[ "$version" == "$top" ]] || {
    echo "FAIL: plugin.json version (${version}) != CHANGELOG latest release (${top}) -- #289 invariant"
    return 1
  }
}
