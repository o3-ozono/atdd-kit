#!/usr/bin/env python3
"""analyze-token-usage.py -- Parse a claude -p jsonl transcript and report per-agent token/cost breakdown.

Usage:
    python3 tests/claude-code/analyze-token-usage.py <transcript.jsonl>

Exit codes:
    0 -- success (including empty file, malformed lines skipped with stderr warning)
    3 -- file not found or unreadable

Model price map (update here when pricing changes):
    See docs/testing-skills.md §(b) for update procedure.
    Prices are per 1M tokens in USD.
"""

import json
import sys
from collections import defaultdict

# Model price map: model_id -> (input_per_1m, output_per_1m, cache_read_per_1m, cache_create_per_1m)
# Update this dict when pricing changes. See docs/testing-skills.md §(b).
MODEL_PRICES = {
    "claude-opus-4-5":        (15.00,  75.00,  1.50,  18.75),
    "claude-opus-4-7":        (15.00,  75.00,  1.50,  18.75),
    "claude-sonnet-4-5":       (3.00,  15.00,  0.30,   3.75),
    "claude-sonnet-4-6":       (3.00,  15.00,  0.30,   3.75),
    "claude-haiku-4-5":        (0.80,   4.00,  0.08,   1.00),
    "claude-haiku-4-5-20251001":(0.80,  4.00,  0.08,   1.00),
    "claude-opus-4-0":        (15.00,  75.00,  1.50,  18.75),
    "claude-sonnet-4-0":       (3.00,  15.00,  0.30,   3.75),
}


def compute_cost(model, usage):
    if model not in MODEL_PRICES:
        return None
    inp, out, cr, cc = MODEL_PRICES[model]
    cost = (
        usage.get("input_tokens", 0) * inp / 1_000_000
        + usage.get("output_tokens", 0) * out / 1_000_000
        + usage.get("cache_read_input_tokens", 0) * cr / 1_000_000
        + usage.get("cache_creation_input_tokens", 0) * cc / 1_000_000
    )
    return cost


def parse_transcript(path):
    try:
        f = open(path, "rb")
    except FileNotFoundError:
        print(f"Error: file not found: {path}", file=sys.stderr)
        sys.exit(3)
    except OSError as e:
        print(f"Error: cannot open {path}: {e}", file=sys.stderr)
        sys.exit(3)

    # Per-agent stats: session_id -> {msgs, input, output, cache_read, cache_create, cost_usd, models}
    agents = defaultdict(lambda: {
        "msgs": 0,
        "input": 0,
        "output": 0,
        "cache_read": 0,
        "cache_create": 0,
        "cost_usd": 0.0,
        "unknown_model": False,
    })

    with f:
        for lineno, raw in enumerate(f, 1):
            try:
                line = raw.decode("utf-8", errors="strict")
            except UnicodeDecodeError:
                print(f"Warning: line {lineno}: non-UTF-8 bytes, skipping", file=sys.stderr)
                continue

            line = line.strip()
            if not line:
                continue

            try:
                obj = json.loads(line)
            except json.JSONDecodeError:
                print(f"Warning: line {lineno}: invalid JSON, skipping", file=sys.stderr)
                continue

            if obj.get("type") != "assistant":
                continue

            usage = obj.get("usage")
            if not usage:
                continue

            session_id = obj.get("session_id") or "(unknown)"
            model = obj.get("model", "")
            agent = agents[session_id]
            agent["msgs"] += 1
            agent["input"] += usage.get("input_tokens", 0)
            agent["output"] += usage.get("output_tokens", 0)
            agent["cache_read"] += usage.get("cache_read_input_tokens", 0)
            agent["cache_create"] += usage.get("cache_creation_input_tokens", 0)

            cost = compute_cost(model, usage)
            if cost is None:
                agent["unknown_model"] = True
            else:
                agent["cost_usd"] += cost

    return agents


def print_table(agents):
    # Column widths
    col_agent = max(20, max((len(k) for k in agents), default=5))
    header = (
        f"{'agent':<{col_agent}}  {'msgs':>5}  {'input':>8}  {'output':>7}  "
        f"{'cache_read':>10}  {'cache_create':>12}  {'cost_usd':>10}"
    )
    sep = "-" * len(header)
    print(header)
    print(sep)

    total_msgs = total_input = total_output = total_cr = total_cc = 0
    total_cost = 0.0
    any_unknown = False

    for agent_id, s in sorted(agents.items()):
        total_msgs += s["msgs"]
        total_input += s["input"]
        total_output += s["output"]
        total_cr += s["cache_read"]
        total_cc += s["cache_create"]
        if s["unknown_model"]:
            any_unknown = True
            cost_str = "N/A (unknown model)"
        else:
            total_cost += s["cost_usd"]
            cost_str = f"${s['cost_usd']:.6f}"
        print(
            f"{agent_id:<{col_agent}}  {s['msgs']:>5}  {s['input']:>8}  {s['output']:>7}  "
            f"{s['cache_read']:>10}  {s['cache_create']:>12}  {cost_str:>10}"
        )

    print(sep)
    total_cost_str = "N/A" if any_unknown else f"${total_cost:.6f}"
    print(
        f"{'total':<{col_agent}}  {total_msgs:>5}  {total_input:>8}  {total_output:>7}  "
        f"{total_cr:>10}  {total_cc:>12}  {total_cost_str:>10}"
    )


def main():
    if len(sys.argv) != 2:
        print("Usage: analyze-token-usage.py <transcript.jsonl>", file=sys.stderr)
        sys.exit(3)

    path = sys.argv[1]
    agents = parse_transcript(path)
    print_table(agents)


if __name__ == "__main__":
    main()
