#!/usr/bin/env bash
set -euo pipefail

# Start a Claude Code session.
#
# All arguments are passed through to claude.
#
# Usage:
#   scripts/start-session.sh [claude args...]

exec claude "$@"
