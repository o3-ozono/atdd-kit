#!/usr/bin/env bash
# helpers/changelog.bash — changelog ヘルパー関数
# Issue #300: インライン抽出の重複を解消し、単一のヘルパーに集約する

# changelog_latest_release <changelog_path>
#
# CHANGELOG.md から最新のリリース見出し（## [X.Y.Z] 形式）を抽出し X.Y.Z を echo する。
# ## [Unreleased] 見出しは数値 X.Y.Z パターンに一致しないため自然にスキップされる。
# 引数: changelog_path — CHANGELOG.md への絶対パスまたは相対パス（CWD 基準）
changelog_latest_release() {
  local changelog_path="${1:?changelog_latest_release: changelog_path が必要です}"
  grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$changelog_path" | head -1 | tr -d '#[] '
}
