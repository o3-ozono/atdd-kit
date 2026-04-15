#!/usr/bin/env bash
# scripts/measure-token-reduction.sh
#
# Measure token reduction between before/after log files.
# Uses wc -c (byte count) as a proxy for token count.
# NOTE: This is a byte-count-based estimation, not actual tokenizer output.
#       Byte count correlates with token count but is not 1:1.
#
# Usage:
#   ./measure-token-reduction.sh <file>              -- show byte count of one file
#   ./measure-token-reduction.sh <before> <after>    -- show before/after and reduction rate
#   ./measure-token-reduction.sh <dir-before> <dir-after>  -- measure entire directories
#
# Output format (bytes estimation):
#   Single file: "<N> bytes (char-based estimation)"
#   Two files:   "Before: <N> bytes | After: <M> bytes | Reduction: <R>% (char-based estimation)"

set -euo pipefail

count_bytes() {
    local target="$1"
    if [ -d "$target" ]; then
        # Sum all files in directory
        find "$target" -type f -exec wc -c {} + 2>/dev/null | tail -1 | awk '{print $1}'
    elif [ -f "$target" ]; then
        wc -c < "$target" | tr -d ' '
    else
        echo "0"
    fi
}

if [ $# -eq 0 ]; then
    echo "Usage: $0 <before-file-or-dir> [<after-file-or-dir>]" >&2
    exit 1
elif [ $# -eq 1 ]; then
    # Single file: just print byte count
    target="$1"
    bytes=$(count_bytes "$target")
    echo "${bytes} bytes (char-based estimation)"
elif [ $# -ge 2 ]; then
    # Two files/dirs: compute reduction rate
    before_target="$1"
    after_target="$2"

    before_bytes=$(count_bytes "$before_target")
    after_bytes=$(count_bytes "$after_target")

    if [ "$before_bytes" -eq 0 ]; then
        echo "Before: 0 bytes | After: ${after_bytes} bytes | Reduction: N/A (before is empty) (char-based estimation)"
        exit 0
    fi

    # Calculate reduction percentage using bc or python3
    reduction=$(python3 -c "
before = $before_bytes
after = $after_bytes
if before == 0:
    print('N/A')
else:
    rate = (before - after) / before * 100
    print(f'{rate:.1f}')
" 2>/dev/null || echo "N/A")

    echo "Before: ${before_bytes} bytes | After: ${after_bytes} bytes | Reduction: ${reduction}% (char-based estimation)"
fi
