get_tmux_option() {
	local option="$1"
	local default_value="$2"
	local option_value=$(tmux show-option -gqv "$option")
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

set_tmux_option() {
	local option="$1"
	local value="$2"
	tmux set-option -gq "$option" "$value"
}

# multiple tmux server detection helpers

current_tmux_server_pid() {
	echo "$TMUX" |
		cut -f2 -d","
}

# A tmux *server* daemonizes on startup and is reparented to init (ppid 1).
# tmux *client* commands (`tmux new`, `tmux attach`, ...) keep their launching
# shell/terminal as parent. Counting only ppid-1 tmux processes distinguishes
# real servers from the many clients that may (re)attach at once. The old
# command-name count treated every attaching client as a server, which wrongly
# disabled autosave/autorestore whenever several sessions reattached during
# startup (e.g. mosh + iTerm + multiple `tmux new -As`).
tmux_server_pids() {
	local user_id
	user_id="$(id -u)"
	# columns: ppid pid command...  $4 is the first arg after `tmux`; skip the
	# transient `tmux source-file` reload process.
	ps -u "$user_id" -o "ppid=,pid=,command=" |
		awk '$1 == 1 && $3 ~ /^tmux/ && $4 !~ /^source/ { print $2 }'
}

number_other_tmux_servers() {
	tmux_server_pids |
		\grep -v "^$(current_tmux_server_pid)$" |
		wc -l |
		sed "s/ //g"
}

another_tmux_server_running_on_startup() {
	[ "$(number_other_tmux_servers)" -gt 0 ]
}
