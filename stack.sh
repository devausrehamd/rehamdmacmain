#!/usr/bin/env bash
# stack.sh — start / stop / restart / status the whole QMS local stack.
#
# Owns all service processes as a group via a pid directory, so "stop" actually
# stops what "start" started - no orphaned terminals, no guessing ports.
#
# Layout assumed (siblings of this script):
#   ./rehamdmacflow   Agent       (:4000)  npm run api
#   ./idserver        ID Server   (:3001)  npm run dev
#   ./discovery       Discovery   (:3005)  npm run dev
#   ./gui             GUI         (:5173)  npm run dev
#
# Usage:
#   ./stack.sh start [service]     start all, or one of: agent|agent-debug|idserver|discovery|gui
#   ./stack.sh stop  [service]     stop all, or one
#   ./stack.sh restart [service]   stop then start
#   ./stack.sh status              what's running, on which port, which pid
#   ./stack.sh logs <service>      tail a service's log

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PIDDIR="$ROOT/.stack/pids"
LOGDIR="$ROOT/.stack/logs"
mkdir -p "$PIDDIR" "$LOGDIR"

# Job control ON. Without this, every `( ... ) &` below inherits THIS script's
# process group, so all services share one pgid - and stop_one, which kills the
# process group, would take down every service instead of the one named.
# `./stack.sh restart agent` used to kill the ID Server and Discovery too, and
# the symptom was misleading: the agent came back and returned 401 "No access to
# the engineering domain" (because the ID Server it asks was dead) rather than a
# connection error. With job control each background job leads its own group.
set -m

# service -> "dir|start-command|port"
#
# `agent` is the production instance. `agent-debug` is a second instance of the
# SAME codebase in debug mode: it may evaluate against uncommitted draft rubrics
# and its output can never be approved. Two instances, two ports - the mode is
# fixed per process, so you pick a mode by picking an agent in the GUI.
services() {
  echo "idserver|idserver|npm run dev|3001"
  echo "discovery|discovery|npm run dev|3005"
  echo "agent|rehamdmacflow|npm run api|4000"
  echo "agent-debug|rehamdmacflow|npm run api:debug|4001"
  echo "gui|gui|npm run dev|5173"
}

svc_field() { # $1=name $2=field-index(2=dir,3=cmd,4=port)
  services | awk -F'|' -v n="$1" -v f="$2" '$1==n{print $f}'
}

is_running() { # $1=name -> 0 if a live pid file matches
  local pf="$PIDDIR/$1.pid"
  [ -f "$pf" ] || return 1
  local pid; pid="$(cat "$pf")"
  kill -0 "$pid" 2>/dev/null
}

start_one() {
  local name="$1"
  local dir cmd port; dir="$(svc_field "$name" 2)"; cmd="$(svc_field "$name" 3)"; port="$(svc_field "$name" 4)"
  [ -z "$dir" ] && { echo "unknown service: $name"; return 1; }
  if is_running "$name"; then echo "  $name already running (pid $(cat "$PIDDIR/$name.pid"))"; return 0; fi
  if [ ! -d "$ROOT/$dir" ]; then echo "  $name: directory $dir not found - skipping"; return 0; fi
  echo "  starting $name ($dir: $cmd) -> :$port"
  ( cd "$ROOT/$dir" && exec $cmd ) >"$LOGDIR/$name.log" 2>&1 &
  echo $! > "$PIDDIR/$name.pid"
}

stop_one() {
  local name="$1"; local pf="$PIDDIR/$name.pid"
  if [ ! -f "$pf" ]; then echo "  $name not tracked (not started by this script)"; return 0; fi
  local pid; pid="$(cat "$pf")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "  stopping $name (pid $pid)"
    # kill the whole process group (npm spawns children like tsx/node)
    kill -TERM "-$(ps -o pgid= "$pid" | tr -d ' ')" 2>/dev/null || kill -TERM "$pid" 2>/dev/null
    sleep 1
    kill -0 "$pid" 2>/dev/null && { echo "    forcing"; kill -KILL "$pid" 2>/dev/null; }
  else
    echo "  $name already stopped (stale pid)"
  fi
  rm -f "$pf"
}

order() { echo "idserver discovery agent agent-debug gui"; }  # start order (deps first-ish)

cmd_start()   { for s in $(order); do [ -n "${1:-}" ] && [ "$1" != "$s" ] && continue; start_one "$s"; done; }
cmd_stop()    { for s in gui agent-debug agent discovery idserver; do [ -n "${1:-}" ] && [ "$1" != "$s" ] && continue; stop_one "$s"; done; }
cmd_restart() { cmd_stop "${1:-}"; sleep 1; cmd_start "${1:-}"; }

cmd_status() {
  printf "%-11s %-8s %-7s %s\n" "SERVICE" "STATE" "PORT" "PID"
  for s in idserver discovery agent agent-debug gui; do
    local port pid state; port="$(svc_field "$s" 4)"
    if is_running "$s"; then pid="$(cat "$PIDDIR/$s.pid")"; state="running"; else pid="-"; state="stopped"; fi
    # also probe the port so we notice a service running OUTSIDE this script
    local portpid; portpid="$(lsof -ti ":$port" 2>/dev/null | head -1)"
    [ -n "$portpid" ] && [ "$state" = "stopped" ] && { state="running*"; pid="$portpid"; }
    printf "%-11s %-8s %-7s %s\n" "$s" "$state" "$port" "$pid"
  done
  echo "  (* = something is on that port but not started by this script)"
}

cmd_logs() { local s="${1:?usage: stack.sh logs <service>}"; tail -f "$LOGDIR/$s.log"; }

case "${1:-}" in
  start)   shift; echo "Starting stack..."; cmd_start "${1:-}"; echo "Done. Use ./stack.sh status" ;;
  stop)    shift; echo "Stopping stack..."; cmd_stop  "${1:-}"; echo "Done." ;;
  restart) shift; echo "Restarting stack..."; cmd_restart "${1:-}"; echo "Done." ;;
  status)  cmd_status ;;
  logs)    shift; cmd_logs "${1:-}" ;;
  *) echo "usage: ./stack.sh {start|stop|restart|status|logs} [agent|agent-debug|idserver|discovery|gui]"; exit 2 ;;
esac