#!/usr/bin/env bash

set -Eeuo pipefail

SESSION="main"
CLASS="gns3-console"
TERMINAL="alacritty"
CONSOLE="telnet"
SESSION_SET=0
ATTACH=0
KILL=0
LIST=0

NAME=""
HOST=""
PORT=""
GNS3_DISPLAY=""
PROJECT=""
PROJECT_ID=""
URL=""
LOG_DIR="${XDG_CACHE_HOME:-$HOME/.cache}"
LOG="$LOG_DIR/gns3-console.log"

exec 3>&1 4>&2
mkdir -p "$LOG_DIR" 2>/dev/null || {
    LOG="/tmp/gns3-console.log"
}
exec >>"$LOG" 2>&1

die() {
    echo "$*" >&2
    echo "$*" >&4
    exit 1
}

usage() {
    cat >&3 <<EOF
Usage:
  gns3-console --name NAME --host HOST --port PORT [OPTIONS]
  gns3-console --attach [OPTIONS]
  gns3-console --kill [OPTIONS]
  gns3-console --list [OPTIONS]

Options:
  -n, --name NAME           Console name
  -H, --host HOST           Host/IP
  -p, --port PORT           Port

Optional:
  -D, --display DISPLAY     GNS3 display value
  -P, --project PROJECT     GNS3 project name
  -i, --project-id ID       GNS3 project ID
  -c, --url URL             GNS3 console URL
  -x, --console CMD         Console command (default: telnet)
  -s, --session NAME        tmux session (default: main)
  -C, --class CLASS         Alacritty WM_CLASS (default: gns3-console)
  -t, --terminal CMD        Terminal (default: alacritty)
  -a, --attach              Open terminal and attach to session
  -k, --kill                Kill tmux session and close matching terminal windows
  -l, --list                Print session, windows, and clients
  -h, --help                Show this help
EOF
}

ARGS=$(getopt \
    -o n:H:p:D:P:i:c:x:s:C:t:aklh \
    --long name:,host:,port:,display:,project:,project-id:,url:,console:,session:,class:,terminal:,attach,kill,list,help \
    -n "gns3-console" \
    -- "$@" 2>&4) || {
    usage >&2
    exit 1
}

eval set -- "$ARGS"

while true; do
    case "$1" in
    -n | --name)
        NAME="$2"
        shift 2
        ;;
    -H | --host)
        HOST="$2"
        shift 2
        ;;
    -p | --port)
        PORT="$2"
        shift 2
        ;;
    -D | --display)
        GNS3_DISPLAY="$2"
        shift 2
        ;;
    -P | --project)
        PROJECT="$2"
        shift 2
        ;;
    -i | --project-id)
        PROJECT_ID="$2"
        shift 2
        ;;
    -c | --url)
        URL="$2"
        shift 2
        ;;
    -x | --console)
        CONSOLE="$2"
        shift 2
        ;;
    -s | --session)
        SESSION="$2"
        SESSION_SET=1
        shift 2
        ;;
    -C | --class)
        CLASS="$2"
        shift 2
        ;;
    -t | --terminal)
        TERMINAL="$2"
        shift 2
        ;;
    -a | --attach)
        ATTACH=1
        shift
        ;;
    -k | --kill)
        KILL=1
        shift
        ;;
    -l | --list)
        LIST=1
        shift
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    --)
        shift
        break
        ;;
    *)
        die "Internal argument parser error: $1"
        ;;
    esac
done

[[ $# -eq 0 ]] || die "Unexpected arguments: $*"

if [[ "$SESSION_SET" -eq 0 ]]; then
    SESSION="${PROJECT:-main}"
fi

command -v tmux >/dev/null || die "tmux not found"

tmux_session_exists() {
    tmux has-session -t "$SESSION" 2>/dev/null
}

terminal_window_exists() {
    command -v wmctrl >/dev/null || return 1
    wmctrl -lx 2>/dev/null | grep -qi -- "$CLASS"
}

tmux_session_has_client() {
    local clients

    tmux_session_exists || return 1
    clients="$(tmux list-clients -t "$SESSION" 2>/dev/null || true)"
    [[ -n "$clients" ]]
}

open_terminal_attached() {
    local title="${NAME:-$SESSION}"

    command -v "$TERMINAL" >/dev/null || die "$TERMINAL not found"

    "$TERMINAL" \
        --class "$CLASS" \
        --title "$title" \
        -e tmux attach-session -t "$SESSION" &
}

kill_terminal_windows() {
    command -v wmctrl >/dev/null || return 0

    {
        wmctrl -lx 2>/dev/null |
            grep -i -- "$CLASS" |
            awk '{print $1}' |
            while read -r id; do
                wmctrl -ic "$id"
            done
    } || true
}

list_state() {
    echo "Session:" >&3
    if tmux_session_exists; then
        echo "  $SESSION" >&3
    else
        echo "  $SESSION (missing)" >&3
    fi

    echo >&3
    echo "Windows:" >&3
    tmux list-windows -t "$SESSION" -F "  #{window_index}: #{window_name}" 2>/dev/null >&3 || true

    echo >&3
    echo "Clients:" >&3
    tmux list-clients -t "$SESSION" -F "  #{client_tty} #{client_name}" 2>/dev/null >&3 || true
}

case "$((ATTACH + KILL + LIST))" in
0 | 1) ;;
*) die "Use only one of --attach, --kill, or --list" ;;
esac

if [[ "$KILL" -eq 1 ]]; then
    tmux kill-session -t "$SESSION" 2>/dev/null || true
    kill_terminal_windows
    exit 0
fi

if [[ "$LIST" -eq 1 ]]; then
    list_state
    exit 0
fi

if [[ "$ATTACH" -eq 1 ]]; then
    tmux_session_exists || die "tmux session not found: $SESSION"
    open_terminal_attached
    exit 0
fi

[[ -n "$NAME" ]] || die "--name missing"
[[ -n "$HOST" ]] || die "--host missing"
[[ -n "$PORT" ]] || die "--port missing"
command -v "$CONSOLE" >/dev/null || die "$CONSOLE not found"

printf -v CMD "%q %q %q; echo; echo 'Connection closed. Press Enter to exit.'; read -r _" "$CONSOLE" "$HOST" "$PORT"

if tmux_session_exists; then
    tmux new-window -t "$SESSION:" -n "$NAME" "$CMD"

    if ! terminal_window_exists; then
        open_terminal_attached
    fi

    exit 0
fi

tmux new-session -d -s "$SESSION" -n "$NAME" "$CMD"
open_terminal_attached
