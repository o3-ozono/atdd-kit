#!/usr/bin/env bash
# run-tests.sh — 依存なし並列 BATS ランナー（影響度ベース × コア数シャーディング）
#
# Usage:
#   run-tests.sh --all [--jobs <n>] [--repo <path>]
#   run-tests.sh --impact --base <ref> [--jobs <n>] [--repo <path>]
#
# Options:
#   --all             全 BATS ファイルを対象にする
#   --impact          影響範囲のみ（impact_map.sh --layer BATS に委譲）
#   --base <ref>      --impact 時の git diff 基点（必須）
#   --jobs <n>        並列シャード数（省略時は CPU コア数を自動検出）
#   --repo <path>     リポジトリルートのパス（デフォルト: スクリプト親ディレクトリ）
#   --_source-only    関数定義のみ読み込み（テスト用、実行しない）
#
# 環境変数（テスト専用）:
#   _RUN_TESTS_IMPACT_MAP_OVERRIDE  impact_map.sh の代替スクリプトのパス
#
# 終了コード:
#   0 — 全シャード pass
#   非0 — いずれかのシャード fail、または使用法エラー
#
# 設計方針:
#   - GNU parallel 等の外部依存なし（pure bash + bats のみ）
#   - bats_runner.sh を置き換えない（温存）。対象集合の決定のみ impact_map.sh に委譲
#   - 影響選択ロジックの新規実装はしない（#323 は別 Issue）
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# ---------------------------------------------------------------------------
# コア数検出（nproc → sysctl -n hw.ncpu → getconf _NPROCESSORS_ONLN → 4）
# ---------------------------------------------------------------------------
detect_cpu_count() {
  local count
  if count=$(nproc 2>/dev/null) && [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -ge 1 ]]; then
    echo "$count"; return
  fi
  if count=$(sysctl -n hw.ncpu 2>/dev/null) && [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -ge 1 ]]; then
    echo "$count"; return
  fi
  if count=$(getconf _NPROCESSORS_ONLN 2>/dev/null) && [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -ge 1 ]]; then
    echo "$count"; return
  fi
  echo "4"  # フォールバック
}

# ---------------------------------------------------------------------------
# 重み均衡ファイルシャーディング
#   引数: <N_shards> <file1> [<file2> ...]
#   出力: N_shards 個のシャード定義を TAB 区切りで標準出力
#         シャードインデックス(0-indexed) TAB ファイルパス の行
# ---------------------------------------------------------------------------
compute_shards() {
  local n_shards="$1"
  shift
  local -a files=("$@")
  local n_files=${#files[@]}

  if [[ "$n_files" -eq 0 ]]; then
    return 0
  fi

  # 各ファイルの重み（@test 行数を近似コストとして使用）
  local -a weights=()
  local f
  for f in "${files[@]}"; do
    local w
    w=$(grep -c '^@test ' "$f" 2>/dev/null || echo "1")
    [[ "$w" -ge 1 ]] || w=1
    weights+=("$w")
  done

  # 実際のシャード数 = min(n_shards, n_files)
  local actual_shards="$n_shards"
  [[ "$n_files" -lt "$actual_shards" ]] && actual_shards="$n_files"

  # グリーディ N 分割: 各ファイルを現在最も軽いシャードへ割り当て
  local -a shard_weights=()
  local -a shard_files=()
  local i
  for (( i=0; i<actual_shards; i++ )); do
    shard_weights+=("0")
    shard_files+=("")
  done

  for (( i=0; i<n_files; i++ )); do
    # 最も軽いシャードを探す
    local min_idx=0
    local min_w="${shard_weights[0]}"
    local j
    for (( j=1; j<actual_shards; j++ )); do
      if [[ "${shard_weights[$j]}" -lt "$min_w" ]]; then
        min_w="${shard_weights[$j]}"
        min_idx="$j"
      fi
    done
    # このシャードにファイルを追加
    local prev="${shard_files[$min_idx]}"
    if [[ -z "$prev" ]]; then
      shard_files[$min_idx]="${files[$i]}"
    else
      shard_files[$min_idx]="${prev}"$'\t'"${files[$i]}"
    fi
    shard_weights[$min_idx]=$(( shard_weights[min_idx] + weights[i] ))
  done

  # 出力: シャードインデックス TAB ファイルパスリスト（TAB 区切り）
  for (( i=0; i<actual_shards; i++ )); do
    [[ -n "${shard_files[$i]}" ]] && echo "${i}"$'\t'"${shard_files[$i]}"
  done
}

# ---------------------------------------------------------------------------
# 全 BATS ファイル収集（bats_runner.sh の collect_all_bats と同等）
# ---------------------------------------------------------------------------
collect_all_bats() {
  local repo="$1"
  find "${repo}/tests" -maxdepth 1 -name "*.bats" 2>/dev/null | sort
  find "${repo}/addons" -path "*/tests/*.bats" 2>/dev/null | sort
}

# ---------------------------------------------------------------------------
# 並列実行
#   引数: <shard_file_list_tsv> （compute_shards の出力行）
#   各行の TAB 区切りファイルリストをシャードとして並列起動
# ---------------------------------------------------------------------------
run_shards_parallel() {
  local -a shard_lines=("$@")
  local -a pids=()
  local -a shard_logs=()
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  local shard_line
  local idx=0
  for shard_line in "${shard_lines[@]}"; do
    local shard_idx
    shard_idx="${shard_line%%$'\t'*}"
    local rest="${shard_line#*$'\t'}"
    # TAB 区切りでファイルリストを配列に変換
    local -a shard_files=()
    IFS=$'\t' read -r -a shard_files <<< "$rest"

    local log="${tmpdir}/shard_${shard_idx}.log"
    shard_logs+=("$log")

    # バックグラウンドでシャードを実行
    (
      echo "=== shard ${shard_idx}: ${#shard_files[@]} file(s) ==="
      bats "${shard_files[@]}"
    ) >"$log" 2>&1 &
    pids+=("$!")
    (( idx++ ))
  done

  # 全シャードの完了を待ち、終了コードを集約
  local overall_exit=0
  local i
  for (( i=0; i<${#pids[@]}; i++ )); do
    local pid="${pids[$i]}"
    local log="${shard_logs[$i]}"
    if ! wait "$pid"; then
      overall_exit=1
    fi
    cat "$log"
  done

  return "$overall_exit"
}

# --_source-only: 関数定義のみで終了（テスト用）
if [[ "${1:-}" == "--_source-only" ]]; then
  return 0 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 引数パース
# ---------------------------------------------------------------------------
OPT_ALL=0
OPT_IMPACT=0
OPT_BASE=""
OPT_JOBS=""
OPT_REPO="$DEFAULT_REPO_ROOT"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)    OPT_ALL=1;         shift   ;;
    --impact) OPT_IMPACT=1;      shift   ;;
    --base)   OPT_BASE="$2";     shift 2 ;;
    --jobs)   OPT_JOBS="$2";     shift 2 ;;
    --repo)   OPT_REPO="$2";     shift 2 ;;
    --_source-only) return 0 2>/dev/null || true ;;
    *)
      echo "ERROR: unknown option '$1'" >&2
      echo "Usage: run-tests.sh --all [--jobs <n>] [--repo <path>]" >&2
      echo "       run-tests.sh --impact --base <ref> [--jobs <n>] [--repo <path>]" >&2
      exit 1
      ;;
  esac
done

if [[ "$OPT_ALL" -eq 0 && "$OPT_IMPACT" -eq 0 ]]; then
  echo "ERROR: either --all or --impact is required" >&2
  echo "Usage: run-tests.sh --all [--jobs <n>] [--repo <path>]" >&2
  echo "       run-tests.sh --impact --base <ref> [--jobs <n>] [--repo <path>]" >&2
  exit 1
fi

if [[ "$OPT_IMPACT" -eq 1 && -z "$OPT_BASE" ]]; then
  echo "ERROR: --impact requires --base <ref>" >&2
  exit 1
fi

# コア数決定（--jobs 明示時はそれを優先）
if [[ -n "$OPT_JOBS" ]]; then
  N_JOBS="$OPT_JOBS"
else
  N_JOBS="$(detect_cpu_count)"
fi

# impact_map.sh: オーバーライドがあれば使用（テスト専用）
IMPACT_MAP="${_RUN_TESTS_IMPACT_MAP_OVERRIDE:-${SCRIPT_DIR}/impact_map.sh}"

# ---------------------------------------------------------------------------
# 対象ファイル集合の決定
# ---------------------------------------------------------------------------
target_files=()

if [[ "$OPT_ALL" -eq 1 ]]; then
  while IFS= read -r f; do
    [[ -n "$f" ]] && target_files+=("$f")
  done < <(collect_all_bats "$OPT_REPO")
else
  # --impact モード: impact_map.sh --layer BATS に委譲
  impact_stderr_file=$(mktemp)
  trap 'rm -f "$impact_stderr_file"' EXIT

  impact_output=""
  set +e
  impact_output=$(
    bash "$IMPACT_MAP" \
      --layer BATS \
      --base "$OPT_BASE" \
      --config "${OPT_REPO}/config/impact_rules.yml" \
      2>"$impact_stderr_file"
  )
  impact_exit=$?
  set -e

  if [[ "$impact_exit" -ne 0 ]]; then
    echo "ERROR: impact_map.sh failed (exit ${impact_exit})" >&2
    cat "$impact_stderr_file" >&2
    exit "$impact_exit"
  fi

  # FALLBACK の場合は全件
  if grep -q "^FALLBACK:" "$impact_stderr_file"; then
    echo "FALLBACK: unmatched changed files — running full BATS suite" >&2
    while IFS= read -r f; do
      [[ -n "$f" ]] && target_files+=("$f")
    done < <(collect_all_bats "$OPT_REPO")
  elif [[ -z "$impact_output" ]]; then
    echo "no affected BATS"
    exit 0
  else
    while IFS= read -r f; do
      [[ -n "$f" ]] && target_files+=("$f")
    done < <(printf '%s\n' "$impact_output" | sort -u)
  fi
fi

if [[ ${#target_files[@]} -eq 0 ]]; then
  echo "no BATS files to run"
  exit 0
fi

echo "run-tests.sh: ${#target_files[@]} file(s), ${N_JOBS} shard(s)"

# ---------------------------------------------------------------------------
# シャーディングと並列実行
# ---------------------------------------------------------------------------
shard_lines=()
while IFS= read -r line; do
  [[ -n "$line" ]] && shard_lines+=("$line")
done < <(compute_shards "$N_JOBS" "${target_files[@]}")

if [[ ${#shard_lines[@]} -eq 0 ]]; then
  echo "no shards to run"
  exit 0
fi

run_shards_parallel "${shard_lines[@]}"
