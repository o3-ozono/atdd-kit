#!/usr/bin/env bash
# changelog.bash — CHANGELOG 解析の共有ヘルパー関数
#
# 使い方:
#   load "$(dirname "$BATS_TEST_FILENAME")/helpers/changelog"
#   または絶対パスで
#   load "/path/to/tests/acceptance/helpers/changelog"
#
# 提供関数:
#   changelog_latest_release <changelog_path>
#     CHANGELOG.md の ## [Unreleased] を除いた先頭の ## [X.Y.Z] から
#     X.Y.Z を標準出力に返す。

# CHANGELOG から最新リリース見出しのバージョン文字列を抽出する。
# 引数: $1 — CHANGELOG.md のパス
# 出力: X.Y.Z 形式のバージョン文字列（標準出力）
changelog_latest_release() {
  local changelog_path="$1"
  grep -m1 '^## \[[0-9]' "$changelog_path" | grep -o '\[[0-9][^]]*\]' | tr -d '[]'
}
