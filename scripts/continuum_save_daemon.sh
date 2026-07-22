#!/usr/bin/env bash
#
# continuum_save_daemon.sh
#
# Periodically drives tmux-continuum saves WITHOUT hooking into `status-right`.
#
# Historically continuum injected `#(continuum_save.sh)` into status-right and
# relied on tmux re-evaluating the status line every `status-interval`. That
# coupled saving to the status line, which caused two recurring failures:
#   1. tmux-powerline rewrites status-right, so it could drop the continuum
#      interpolation and silently stop ALL saves.
#   2. A session restore triggers a storm of status refreshes, firing saves
#      into the middle of the restore (partial/corrupt state, lost saves).
#
# This daemon is started once per tmux server by continuum.tmux and simply
# wakes on a fixed cadence to run continuum_save.sh, which still performs all
# of the interval/lock gating. It exits when its tmux server dies.
#
# Usage: continuum_save_daemon.sh <tmux-server-pid>

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

server_pid="$1"
tick_seconds=60

# Without a server pid we have nothing to bind our lifetime to.
[ -n "$server_pid" ] || exit 0

# Only one daemon per tmux server. Key the pidfile on the server pid so a new
# server (new pid) always gets its own daemon, and config reloads don't stack
# up duplicate daemons.
pidfile="/tmp/tmux-continuum-${server_pid}-daemon.pid"
if [ -f "$pidfile" ]; then
	existing="$(cat "$pidfile" 2>/dev/null)"
	if [ -n "$existing" ] && kill -0 "$existing" 2>/dev/null; then
		exit 0  # a live daemon already owns this server
	fi
fi
echo "$$" >"$pidfile"
# Only clear the pidfile on exit if it still names us (avoid deleting a
# newer daemon's pidfile if one raced us into existence).
trap '[ "$(cat "$pidfile" 2>/dev/null)" = "$$" ] && rm -f "$pidfile"' EXIT

while true; do
	sleep "$tick_seconds"
	# Stop as soon as the tmux server we belong to is gone.
	kill -0 "$server_pid" 2>/dev/null || break
	"$CURRENT_DIR/continuum_save.sh" >/dev/null 2>&1
done
