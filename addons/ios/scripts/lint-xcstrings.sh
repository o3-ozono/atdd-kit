#!/usr/bin/env bash
# lint-xcstrings.sh — .xcstrings の翻訳カバレッジリント
#
# 検出項目:
#   エラー: 日本語訳なし（除外リスト外）、日本語キー（非 ASCII）
#   ワーニング: stale エントリ
#
# 終了コード: エラー >= 1 → exit 1、ワーニングのみ → exit 0
set -euo pipefail

XCSTRINGS="${1:?Usage: lint-xcstrings.sh <path-to-xcstrings> [ignore-file]}"
IGNORE_FILE="${2:-.xcstrings-lint-ignore}"

if [ ! -f "$XCSTRINGS" ]; then
  echo "::error::File not found: $XCSTRINGS"
  exit 1
fi

if ! command -v jq &>/dev/null; then
  echo "::error::jq is required but not installed"
  exit 1
fi

# Load ignore list (skip comments and empty lines)
IGNORE_KEYS=()
if [ -f "$IGNORE_FILE" ]; then
  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    IGNORE_KEYS+=("$line")
  done < "$IGNORE_FILE"
fi

ERRORS=0
WARNINGS=0

# Use jq to perform all checks in a single pass for performance and portability
LINT_OUTPUT=$(jq -r --argjson ignoreList "$(printf '%s\n' ${IGNORE_KEYS[@]+"${IGNORE_KEYS[@]}"} | jq -R . | jq -s .)" '
  .strings | to_entries[] |
  .key as $key |
  .value as $val |
  ($ignoreList | index($key)) as $is_ignored |

  # Check: non-ASCII key (Japanese key)
  if ($key | explode | any(. > 127)) then
    if $is_ignored == null then
      "ERROR\tJapanese key found: \"\($key)\" — keys must be in English"
    else
      empty
    end
  else
    # Check: stale entry
    (if ($val.extractionState // "") == "stale" then
      "WARNING\tStale entry: \"\($key)\" — no longer referenced in code"
    else
      empty
    end),
    # Check: missing Japanese translation
    if $is_ignored != null then
      empty
    elif ($val.localizations.ja // null) == null then
      "ERROR\tMissing Japanese translation: \"\($key)\""
    else
      empty
    end
  end
' "$XCSTRINGS")

while IFS=$'\t' read -r level message; do
  [ -z "$level" ] && continue
  if [ "$level" = "ERROR" ]; then
    echo "::error::$message"
    ERRORS=$((ERRORS + 1))
  elif [ "$level" = "WARNING" ]; then
    echo "::warning::$message"
    WARNINGS=$((WARNINGS + 1))
  fi
done <<< "$LINT_OUTPUT"

echo ""
echo "=== xcstrings lint summary ==="
echo "Errors:   $ERRORS"
echo "Warnings: $WARNINGS"

if [ "$ERRORS" -gt 0 ]; then
  exit 1
fi

echo "All checks passed."
exit 0
