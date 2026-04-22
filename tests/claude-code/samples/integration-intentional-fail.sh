#!/usr/bin/env bash
# integration-intentional-fail.sh -- AC5 integration FAIL (negative) sample
# Intentionally exits 1 to prove that the integration runner correctly
# propagates assertion failures from sample scripts.
# Purpose: proves that the test framework correctly detects integration failures.

exit 1
