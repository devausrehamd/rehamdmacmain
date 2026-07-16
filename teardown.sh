#!/usr/bin/env bash
# teardown.sh — stop the whole stack, and optionally tear down the infra.
#
#   ./teardown.sh           # stop the four services (keep infra + data)
#   ./teardown.sh --purge   # ALSO stop/remove Redis, Ollama, Postgres,
#                           # Colima+Qdrant and DELETE all data (destructive)
#
# Service processes are owned by ./stack.sh; infrastructure is owned by the
# Agent's own teardown.sh (rehamdmacflow/teardown.sh). This script drives both.

set -uo pipefail
BLUE='\033[0;34m'; GREEN='\033[0;32m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

step "Stopping service processes (stack.sh)"
[[ -f stack.sh ]] && ./stack.sh stop || true

if [[ "${1:-}" == "--purge" ]]; then
    step "Purging infrastructure and data (rehamdmacflow/teardown.sh --purge)"
    if [[ -f rehamdmacflow/teardown.sh ]]; then
        ( cd rehamdmacflow && bash teardown.sh --purge )
    fi
else
    echo -e "\n  Services stopped. Infrastructure (Postgres, Redis, Ollama, Qdrant) left running."
    echo "  Run './teardown.sh --purge' to stop infra and delete all data."
fi
