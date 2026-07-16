#!/usr/bin/env bash
# setup.sh — one-command bootstrap for the whole QMS stack.
#
# This is the MASTER repo. The four services live here as git submodules:
#   rehamdmacflow  Agent      (:4000 / :4001 debug)
#   idserver       ID Server  (:3001)
#   discovery      Discovery  (:3005)
#   gui            GUI        (:5173)
#
# What this script does, idempotently (safe to re-run):
#   1. Pull the submodules (clone/update all four repos).
#   2. Run the Agent's own setup.sh — the heavy lift: Homebrew packages,
#      Redis / Ollama / Postgres / Colima+Qdrant, models, DB + migrations,
#      npm install, .env. (rehamdmacflow/setup.sh owns all infra.)
#   3. Install the three lighter repos (idserver, discovery, gui): seed each
#      .env from .env.example if missing, then npm install.
#
# After it completes: `./stack.sh start` runs everything, then open
# qms-stack.code-workspace in VS Code.

set -uo pipefail

BLUE='\033[0;34m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
step() { echo -e "\n${BLUE}==>${NC} ${GREEN}$1${NC}"; }
info() { echo -e "    $1"; }
warn() { echo -e "${YELLOW}WARN:${NC} $1"; }
fail() { echo -e "${RED}FAIL:${NC} $1" >&2; exit 1; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

# --- 1. Submodules -----------------------------------------------------------
step "Fetching submodules (the four service repos)"
if [[ -f .gitmodules ]]; then
    git submodule update --init --recursive || fail "git submodule update failed"
    info "Submodules present:"
    git submodule status | sed 's/^/      /'
else
    warn ".gitmodules not found — assuming the four repos are already checked out as plain folders."
fi

# --- 2. The Agent: full infra + app setup ------------------------------------
step "Setting up the Agent (rehamdmacflow) — infra, DB, models, deps"
if [[ -x rehamdmacflow/setup.sh ]]; then
    ( cd rehamdmacflow && ./setup.sh ) || fail "rehamdmacflow/setup.sh failed — fix the reported step and re-run."
elif [[ -f rehamdmacflow/setup.sh ]]; then
    ( cd rehamdmacflow && bash setup.sh ) || fail "rehamdmacflow/setup.sh failed — fix the reported step and re-run."
else
    fail "rehamdmacflow/setup.sh not found. Did the submodule check out? Re-run: git submodule update --init"
fi

# --- 3. The three lighter repos: .env + npm install --------------------------
install_light() { # $1 = repo dir
    local d="$1"
    step "Installing $d"
    [[ -d "$d" ]] || { warn "$d not found — skipping (submodule not checked out?)"; return 0; }
    if [[ ! -f "$d/.env" && -f "$d/.env.example" ]]; then
        cp "$d/.env.example" "$d/.env"
        info ".env created from .env.example"
    else
        info ".env already present (or no example) — leaving it"
    fi
    if [[ -f "$d/package.json" ]]; then
        ( cd "$d" && npm install ) || fail "npm install failed in $d"
        info "npm install complete"
    else
        warn "$d has no package.json — skipping npm install"
    fi
}

install_light idserver
install_light discovery
install_light gui

# --- Done --------------------------------------------------------------------
step "Setup complete"
cat <<EOF

  The whole stack is installed. To run it:

    ./stack.sh start        # ID Server, Discovery, Agent (+debug)
    cd gui && npm run dev    # GUI on http://localhost:5173

  Or open ${GREEN}qms-stack.code-workspace${NC} in VS Code and run the
  "▶️  Stack: START all" task (Terminal → Run Task).

  Status / logs / stop:
    ./stack.sh status
    ./stack.sh logs agent
    ./stack.sh stop

  Docs live in ./docs (start with docs/README.md).
EOF
