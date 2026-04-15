# Token Reduction Results — Issue #85

## Measurement Methodology

- **Tool:** `scripts/measure-token-reduction.sh`
- **Unit:** Byte count (`wc -c`) as token-count proxy
- **Note:** Byte-count-based estimation, not actual tokenizer output. Correlates with token count but is not 1:1.
- **Fixtures:** `fixtures/token-reduction/baseline/` and `fixtures/token-reduction/after/`
- **Reproducibility:** 100% — fixed mock logs eliminate LLM non-determinism

## Results

| Technique | Before (bytes) | After (bytes) | Reduction | Target | Status |
|-----------|---------------|---------------|-----------|--------|--------|
| AC1: gh --json field minimization | 600 | 445 | 25.8% | ≥ 25% | PASS |
| AC2: Agent spawn context dedup | 1528 | 377 | 75.3% | ≥ 40% | PASS |
| AC3: Bash output normalization | 452 | 344 | 23.9% | ≥ 15% | PASS |

All three techniques exceed their respective baseline targets.

## Fixture Files

| Fixture | Description |
|---------|-------------|
| `baseline/session-start-pr-view.json` | `gh pr view` output with `mergeStateStatus` (AC1 before) |
| `after/session-start-pr-view.json` | `gh pr view` output without `mergeStateStatus`, minified (AC1 after) |
| `baseline/autopilot-phase2-sendmessage.md` | Phase 2 SendMessage with full AC set injected (AC2 before) |
| `after/autopilot-phase2-sendmessage.md` | Phase 2 SendMessage with reference-only context (AC2 after) |
| `baseline/bash-output-sample.txt` | Bash tool output with pretty-printed JSON and blank lines (AC3 before) |
| `after/bash-output-sample.txt` | Normalized Bash output: minified JSON, collapsed blank lines (AC3 after) |

## How to Reproduce

```bash
# Single technique
scripts/measure-token-reduction.sh \
  fixtures/token-reduction/baseline/session-start-pr-view.json \
  fixtures/token-reduction/after/session-start-pr-view.json

# All techniques
for name in session-start-pr-view.json autopilot-phase2-sendmessage.md bash-output-sample.txt; do
  echo "=== $name ==="
  scripts/measure-token-reduction.sh \
    "fixtures/token-reduction/baseline/$name" \
    "fixtures/token-reduction/after/$name"
done
```
