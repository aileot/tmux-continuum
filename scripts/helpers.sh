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

get_tmux_option_for_socket() {
	local socket_path="$1"
	local option="$2"
	local default_value="$3"
	local option_value
	option_value=$(tmux -S "$socket_path" show-option -gqv "$option" 2>/dev/null)
	if [ -z "$option_value" ]; then
		echo "$default_value"
	else
		echo "$option_value"
	fi
}

# multiple tmux server detection helpers

current_tmux_server_pid() {
	echo "$TMUX" |
		cut -f2 -d","
}

current_tmux_socket_path() {
	echo "$TMUX" |
		cut -f1 -d","
}

all_tmux_processes() {
	# ignores `tmux source-file .tmux.conf` command used to reload tmux.conf
	local user_id=$(id -u)
	ps -u $user_id -o "command pid" |
		\grep "^tmux" |
		\grep -v "^tmux source"
}

number_tmux_processes_except_current_server() {
	all_tmux_processes |
		\grep -v " $(current_tmux_server_pid)$" |
		wc -l |
		sed "s/ //g"
}

number_current_server_client_processes() {
	tmux list-clients |
		wc -l |
		sed "s/ //g"
}

default_tmux_socket_path() {
	echo "/tmp/tmux-$(id -u)/default"
}

socket_path_from_tmux_command() {
	local command="$1"
	local socket_name=""
	local socket_path=""

	set -- $command
	while [ "$#" -gt 0 ]; do
		case "$1" in
			-L)
				shift
				socket_name="$1"
				;;
			-L*)
				socket_name="${1#-L}"
				;;
			-S)
				shift
				socket_path="$1"
				;;
			-S*)
				socket_path="${1#-S}"
				;;
		esac
		shift
	done

	if [ -n "$socket_path" ]; then
		echo "$socket_path"
	elif [ -n "$socket_name" ]; then
		echo "/tmp/tmux-$(id -u)/$socket_name"
	else
		default_tmux_socket_path
	fi
}

other_tmux_socket_paths() {
	local current_socket_path="$(current_tmux_socket_path)"
	all_tmux_processes |
		sed 's/[[:space:]]\+[0-9]\+$//' |
		while IFS= read -r command; do
			local socket_path="$(socket_path_from_tmux_command "$command")"
			if [ "$socket_path" != "$current_socket_path" ]; then
				echo "$socket_path"
			fi
		done |
		sort -u
}

current_server_has_unique_resurrect_dir() {
	local current_resurrect_dir="$(get_tmux_option "$resurrect_dir_option" "")"
	local socket_path=""
	local other_resurrect_dir=""

	while IFS= read -r socket_path; do
		if tmux -S "$socket_path" has-session 2>/dev/null; then
			other_resurrect_dir="$(get_tmux_option_for_socket "$socket_path" "$resurrect_dir_option" "")"
			if [ "$other_resurrect_dir" = "$current_resurrect_dir" ]; then
				return 1
			fi
		fi
	done <<EOF
$(other_tmux_socket_paths)
EOF

	return 0
}

another_tmux_server_running_on_startup() {
	# there are 2 tmux processes (current tmux server + 1) on tmux startup
	[ "$(number_tmux_processes_except_current_server)" -gt 1 ]
}
