#!/usr/bin/env bash
# pr-screenshot-table.sh — Before/After スクリーンショット比較テーブルを PR description に追加
#
# Usage: scripts/pr-screenshot-table.sh <PR_NUMBER> <SNAPSHOT_DIR>
#
# 前提:
#   - gh CLI がインストール済み・認証済み
#   - ~/.playwright-github-session/state.json が存在する（GitHub 認証済み）
#     初回セットアップ:
#       npx @playwright/cli -s=github open --headed "https://github.com/login"
#       (ブラウザでログイン後)
#       npx @playwright/cli -s=github state-save ~/.playwright-github-session/state.json

set -euo pipefail

#──────────────────────────────────────────────
# 引数チェック
#──────────────────────────────────────────────
if [ $# -lt 2 ]; then
  echo "Usage: $0 <PR_NUMBER> <SNAPSHOT_DIR>" >&2
  exit 1
fi

PR_NUMBER="$1"
if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: PR_NUMBER must be a positive integer, got: '$PR_NUMBER'" >&2
  exit 1
fi
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner)"

#──────────────────────────────────────────────
# PR 情報取得
#──────────────────────────────────────────────
BRANCH="$(gh pr view "$PR_NUMBER" --json headRefName -q .headRefName)"
echo "PR #${PR_NUMBER} — branch: ${BRANCH}"

#──────────────────────────────────────────────
# 変更スナップショット検出
#──────────────────────────────────────────────
SNAPSHOT_DIR="$2"

git fetch origin main "$BRANCH" --quiet

TMPDIR_BASE="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

CHANGED_LIST="${TMPDIR_BASE}/changed.txt"
git diff -z --name-only "origin/main...origin/${BRANCH}" -- "${SNAPSHOT_DIR}" 2>/dev/null \
  | tr '\0' '\n' \
  | grep '\.png$' \
  > "$CHANGED_LIST" || true

if [ ! -s "$CHANGED_LIST" ]; then
  echo "スナップショット画像の変更はありません。スキップします。"
  exit 0
fi

echo "変更されたスナップショット:"
cat "$CHANGED_LIST"

#──────────────────────────────────────────────
# View 名でグループ化（bash 3.2 互換）
#──────────────────────────────────────────────
GROUPS_DIR="${TMPDIR_BASE}/groups"
mkdir -p "$GROUPS_DIR"

while IFS= read -r png_path; do
  [ -z "$png_path" ] && continue

  dir_part="$(dirname "$png_path")"
  test_class="$(basename "$dir_part")"
  test_file="$(basename "$png_path")"
  test_name="${test_file%.1.png}"

  case "$test_name" in
    *_dark)
      base_name="${test_name%_dark}"
      mode="dark"
      ;;
    *)
      base_name="$test_name"
      mode="light"
      ;;
  esac

  group_id="$(echo "${test_class}/${base_name}" | md5 -q)"
  group_file="${GROUPS_DIR}/${group_id}"

  if [ ! -f "$group_file" ]; then
    echo "CLASS=${test_class}" >> "$group_file"
    echo "NAME=${base_name}" >> "$group_file"
  fi
  echo "${mode}=${png_path}" >> "$group_file"

done < "$CHANGED_LIST"

#──────────────────────────────────────────────
# Before/After 画像を一時ディレクトリに抽出
#──────────────────────────────────────────────
BEFORE_DIR="${TMPDIR_BASE}/before"
AFTER_DIR="${TMPDIR_BASE}/after"
mkdir -p "$BEFORE_DIR" "$AFTER_DIR"

extract_image() {
  ref="$1"
  path="$2"
  dest_dir="$3"
  safe_name="$(echo "$path" | sed 's|/|__|g')"
  dest="${dest_dir}/${safe_name}"

  if git show "${ref}:${path}" > "$dest" 2>/dev/null; then
    sips --resampleWidth 300 "$dest" --out "$dest" > /dev/null 2>&1
    echo "$dest"
  else
    echo ""
  fi
}

#──────────────────────────────────────────────
# 全画像を抽出し、アップロード用リストを構築
#──────────────────────────────────────────────
UPLOAD_LIST="${TMPDIR_BASE}/upload_images.txt"
> "$UPLOAD_LIST"

# 各グループから画像を抽出
for group_file in "${GROUPS_DIR}"/*; do
  [ -f "$group_file" ] || continue

  light_path=""
  dark_path=""

  while IFS='=' read -r key value; do
    case "$key" in
      light) light_path="$value" ;;
      dark)  dark_path="$value" ;;
    esac
  done < "$group_file"

  group_id="$(basename "$group_file")"

  # Light Before
  if [ -n "$light_path" ]; then
    before_file="$(extract_image "origin/main" "$light_path" "$BEFORE_DIR")"
    if [ -n "$before_file" ]; then
      echo "${group_id}_light_before=${before_file}" >> "$UPLOAD_LIST"
    fi
    after_file="$(extract_image "origin/${BRANCH}" "$light_path" "$AFTER_DIR")"
    if [ -n "$after_file" ]; then
      echo "${group_id}_light_after=${after_file}" >> "$UPLOAD_LIST"
    fi
  fi

  # Dark Before/After
  if [ -n "$dark_path" ]; then
    before_file="$(extract_image "origin/main" "$dark_path" "$BEFORE_DIR")"
    if [ -n "$before_file" ]; then
      echo "${group_id}_dark_before=${before_file}" >> "$UPLOAD_LIST"
    fi
    after_file="$(extract_image "origin/${BRANCH}" "$dark_path" "$AFTER_DIR")"
    if [ -n "$after_file" ]; then
      echo "${group_id}_dark_after=${after_file}" >> "$UPLOAD_LIST"
    fi
  fi
done

if [ ! -s "$UPLOAD_LIST" ]; then
  echo "アップロードする画像がありませんでした。"
  exit 0
fi

#──────────────────────────────────────────────
# 一括アップロード
#──────────────────────────────────────────────
PR_URL="https://github.com/${REPO}/pull/${PR_NUMBER}"
UPLOAD_RESULT="${TMPDIR_BASE}/upload_result.txt"

# 画像パスだけを抽出してアップロードスクリプトに渡す
image_paths=""
while IFS='=' read -r key path; do
  image_paths="${image_paths} ${path}"
done < "$UPLOAD_LIST"

echo ""
echo "画像をアップロード中..."
# shellcheck disable=SC2086
node "${SCRIPT_DIR}/upload-image-to-github.mjs" "$PR_URL" $image_paths > "$UPLOAD_RESULT" 2>/dev/null || true

# 結果をキーにマッピング
UPLOAD_MAP="${TMPDIR_BASE}/upload_map.txt"
> "$UPLOAD_MAP"
line_num=0
while IFS='=' read -r key path; do
  line_num=$((line_num + 1))
  url="$(sed -n "${line_num}p" "$UPLOAD_RESULT")"
  if [ -n "$url" ] && [ "$url" != "UPLOAD_FAILED" ]; then
    echo "${key}=${url}" >> "$UPLOAD_MAP"
  fi
done < "$UPLOAD_LIST"

get_url() {
  key="$1"
  result="$(grep "^${key}=" "$UPLOAD_MAP" 2>/dev/null | head -1 | cut -d= -f2-)" || true
  echo "$result"
}

echo "アップロード完了（$(wc -l < "$UPLOAD_RESULT" | tr -d ' ') 画像）"

#──────────────────────────────────────────────
# テーブル構築
#──────────────────────────────────────────────
SCREENSHOT_SECTION=""

for group_file in "${GROUPS_DIR}"/*; do
  [ -f "$group_file" ] || continue

  test_class=""
  test_name=""
  light_path=""
  dark_path=""

  while IFS='=' read -r key value; do
    case "$key" in
      CLASS) test_class="$value" ;;
      NAME)  test_name="$value" ;;
      light) light_path="$value" ;;
      dark)  dark_path="$value" ;;
    esac
  done < "$group_file"

  display_class="${test_class%SnapshotTests}"
  display_title="${display_class} — ${test_name}"
  group_id="$(basename "$group_file")"

  echo "  ${display_title}"

  has_light=false
  has_dark=false
  light_before_url="—"
  light_after_url="—"
  dark_before_url="—"
  dark_after_url="—"

  if [ -n "$light_path" ]; then
    has_light=true
    url="$(get_url "${group_id}_light_before")"
    if [ -n "$url" ]; then
      light_before_url="<img src=\"${url}\" width=\"300\">"
    fi
    url="$(get_url "${group_id}_light_after")"
    if [ -n "$url" ]; then
      light_after_url="<img src=\"${url}\" width=\"300\">"
    fi
  fi

  if [ -n "$dark_path" ]; then
    has_dark=true
    url="$(get_url "${group_id}_dark_before")"
    if [ -n "$url" ]; then
      dark_before_url="<img src=\"${url}\" width=\"300\">"
    fi
    url="$(get_url "${group_id}_dark_after")"
    if [ -n "$url" ]; then
      dark_after_url="<img src=\"${url}\" width=\"300\">"
    fi
  fi

  TABLE="### ${display_title}
| | Before | After |
|---|---|---|"

  if $has_light; then
    TABLE="${TABLE}
| Light | ${light_before_url} | ${light_after_url} |"
  fi
  if $has_dark; then
    TABLE="${TABLE}
| Dark | ${dark_before_url} | ${dark_after_url} |"
  fi

  SCREENSHOT_SECTION="${SCREENSHOT_SECTION}
${TABLE}
"
done

#──────────────────────────────────────────────
# PR description を更新
#──────────────────────────────────────────────
FULL_SECTION="## Screenshots
${SCREENSHOT_SECTION}"

CURRENT_BODY="$(gh pr view "$PR_NUMBER" --json body -q .body)"

if echo "$CURRENT_BODY" | grep -q "^## Screenshots"; then
  SECTION_FILE="${TMPDIR_BASE}/section.txt"
  echo "$FULL_SECTION" > "$SECTION_FILE"
  NEW_BODY="$(echo "$CURRENT_BODY" | awk -v section_file="$SECTION_FILE" '
    /^## Screenshots/ { skip=1; while ((getline line < section_file) > 0) print line; next }
    /^## / && skip { skip=0 }
    !skip { print }
  ')"
else
  NEW_BODY="${CURRENT_BODY}

${FULL_SECTION}"
fi

gh pr edit "$PR_NUMBER" --body "$NEW_BODY"

echo ""
echo "PR #${PR_NUMBER} の description にスクリーンショットテーブルを追加しました。"
