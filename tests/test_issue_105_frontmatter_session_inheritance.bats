#!/usr/bin/env bats
# @covers: agents/**
# Issue #105: Agent frontmatter model/effort removal — regression guard
# Agents must NOT have pinned model or effort; session-level settings inherit instead.
# Updated by #271: AC1/AC2 now use glob-based detection (no fixed 6-file list).
#
# 保護範囲の設計メモ（#271 レビュー所見 priority-3 対応）:
#   AC1/AC2 は agents/README.md を除くすべての *.md（将来のカスタム agent 定義ファイル）を対象とする。
#   現在 agents/ 配下に README.md 以外の定義ファイルが存在しないため、AC1/AC2 は trivially pass する。
#   これは意図的な設計であり、将来 agent 定義ファイルが追加された時点で自動的に実効性を持つ。
#
#   AC3（README.md pin）は AC1/AC2 と保護範囲が異なる:
#     - AC3: README.md そのものの table 構造を常にチェック（agent 定義ファイルの有無に依存しない）
#     - AC1/AC2: README.md を除く agent 定義ファイルの frontmatter フィールドをチェック（定義ファイルがない間は無効）
#
#   将来 agents/ に定義ファイルを追加する際の注意:
#     AC1/AC2 が実効性を持ちはじめるため、追加したファイルに model:/effort: フィールドを含めないこと。
#     README.md の table 構造変更は AC3 が継続して監視する。

@test "AC1: no pinned model field in any agent definition file under agents/" {
  # 対象: agents/README.md を除く *.md（将来のカスタム agent 定義ファイル）
  # 現在 README.md 以外の定義ファイルが存在しない場合、trivially pass する（意図的な設計）。
  # 将来 agent 定義ファイルが追加された時点でこのチェックが実効性を持つ。
  local found=0
  for f in agents/*.md; do
    [[ "$f" == "agents/README.md" ]] && continue
    [[ -f "$f" ]] || continue
    found=1
    ! grep -q '^model:' "$f" || {
      echo "FAIL: ${f} has pinned model field"
      return 1
    }
  done
  # 定義ファイルが存在しない場合は情報メッセージを出力（設計上の意図を明示）
  [[ "$found" -eq 1 ]] || echo "# info: no agent definition files found in agents/ (only README.md) — AC1 trivially passes by design"
}

@test "AC2: no pinned effort field in any agent definition file under agents/" {
  # 対象: agents/README.md を除く *.md（将来のカスタム agent 定義ファイル）
  # 現在 README.md 以外の定義ファイルが存在しない場合、trivially pass する（意図的な設計）。
  # 将来 agent 定義ファイルが追加された時点でこのチェックが実効性を持つ。
  local found=0
  for f in agents/*.md; do
    [[ "$f" == "agents/README.md" ]] && continue
    [[ -f "$f" ]] || continue
    found=1
    ! grep -q '^effort:' "$f" || {
      echo "FAIL: ${f} has pinned effort field"
      return 1
    }
  done
  # 定義ファイルが存在しない場合は情報メッセージを出力（設計上の意図を明示）
  [[ "$found" -eq 1 ]] || echo "# info: no agent definition files found in agents/ (only README.md) — AC2 trivially passes by design"
}

@test "AC3: agents/README.md has no Model or Effort column in Agent table" {
  # AC3 は AC1/AC2 と保護範囲が異なる: README.md の table 構造を常に pin する。
  # agent 定義ファイルの有無に依存せず、README.md が存在する限り常に実効性を持つ。
  ! grep -q '| Model |' agents/README.md
  ! grep -q '| Effort |' agents/README.md
}

@test "AC3: agents/README.md documents session-level inheritance" {
  # AC3 は AC1/AC2 と保護範囲が異なる: README.md の構造・内容を常に pin する。
  grep -qi 'session' agents/README.md
}
