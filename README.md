# QMS Stack — master repo

One repo that pulls the four QMS services together, installs them, and runs them
from VS Code. The services themselves are **git submodules** — each is its own
repo; this one wires them into a single workspace with shared setup / start /
stop scripts.

| # | Submodule | Service | Port | Start command |
|---|-----------|---------|------|---------------|
| 1 | [`rehamdmacflow`](rehamdmacflow) | Agent (drafting, rubrics, custody) | 4000 / 4001 debug | `npm run api` |
| 2 | [`idserver`](idserver) | ID Server (identity, JWT) | 3001 | `npm run dev` |
| 3 | [`discovery`](discovery) | Discovery (agent registry) | 3005 | `npm run dev` |
| 4 | [`gui`](gui) | GUI (thin web client) | 5173 | `npm run dev` |

Full technical documentation is in [`docs/`](docs/README.md) — start with
[`docs/00-philosophy.md`](docs/00-philosophy.md).

---

## Quick start

```bash
# 1. Clone WITH submodules (the four service repos)
git clone --recursive <this-repo-url> qms
cd qms
#    (already cloned without --recursive? run: git submodule update --init --recursive)

# 2. Install everything — infra, DB, models, deps. Idempotent; ~minutes first run.
./setup.sh

# 3. Run the whole stack
./stack.sh start
./stack.sh status

# 4. Open the GUI
open http://localhost:5173
```

Then open **`qms-stack.code-workspace`** in VS Code for the four services as named
folders plus one-click Stack tasks (Terminal → Run Task).

---

## What `setup.sh` does

Idempotent and safe to re-run. It:

1. Pulls the four submodules.
2. Runs the Agent's own `rehamdmacflow/setup.sh` — the heavy lift: Homebrew
   packages, Redis / Ollama / Postgres / Colima + Qdrant, pulls the Ollama
   models, creates the database, applies migrations, `npm install`, seeds `.env`.
3. Installs the three lighter repos (`idserver`, `discovery`, `gui`): seeds each
   `.env` from `.env.example`, then `npm install`.

Prerequisites it expects already present: **macOS**, **Homebrew**, and **Node 22
LTS** (see `rehamdmacflow/.nvmrc`). Everything else it installs for you.

---

## Running the stack

`./stack.sh` owns all service processes as a group (via a pid dir), so `stop`
stops exactly what `start` started — no orphaned terminals.

```bash
./stack.sh start [service]     # all, or one of: agent agent-debug idserver discovery gui
./stack.sh stop  [service]
./stack.sh restart [service]   # e.g. restart agent — the one you change most
./stack.sh status              # what's running, on which port, which pid
./stack.sh logs <service>      # tail one service's log (in .stack/logs/)
```

`agent` is the production instance; `agent-debug` is the same codebase in debug
mode on :4001 (it may evaluate uncommitted draft rubrics and its output can never
be approved). You pick a mode by picking an agent in the GUI.

Tear down:

```bash
./teardown.sh                  # stop the four services (leave infra + data)
./teardown.sh --purge          # ALSO stop/remove Postgres, Redis, Ollama,
                               # Colima+Qdrant and DELETE all data (destructive)
```

---

## Working with submodules

Each service is a normal git repo checked out under its folder. Commit and push
inside the submodule, then record the new pointer in this master repo:

```bash
cd gui && git add -A && git commit -m "…" && git push   # work in the submodule
cd ..  && git add gui && git commit -m "bump gui"         # record the pointer here
```

Pull everyone else's submodule updates with:

```bash
git pull && git submodule update --init --recursive
```

Remotes (all under `github.com/devausrehamd`): `rehamdmacflow`, `idserver`,
`discovery`, `rehamdgui` (the `gui` submodule).
