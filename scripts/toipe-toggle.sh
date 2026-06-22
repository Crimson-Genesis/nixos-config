#!/usr/bin/env bash

show_help() {
    cat <<EOF
toipe-launcher

Usage:
    $(basename "$0") MODE

Modes:
    easy        Start toipe with normal words
    medium      Start toipe with punctuation enabled (-p)
    hard        Start toipe with punctuation and commonly-misspelled words

Behavior:
    • If the selected mode is already running, toipe is closed.
    • If another mode is running, it is stopped and the new mode is started.
    • Only one toipe instance can run at a time.

Examples:
    $(basename "$0") easy
    $(basename "$0") medium
    $(basename "$0") hard

Options:
    -h, --help  Show this help message
EOF
}

case "$1" in
-h | --help)
    show_help
    exit 0
    ;;
esac

mode="$1"

case "$mode" in
easy | medium | hard)
    ;;
*)
    echo "Usage: $(basename "$0") {easy|medium|hard}"
    echo "Use --help for more information."
    exit 1
    ;;
esac

get_current_mode() {
    pgrep -af "^toipe " | grep -q -- "-w commonly-misspelled" && {
        echo hard
        return
    }

    pgrep -af "^toipe " | grep -q -- "-p" && {
        echo medium
        return
    }

    pgrep -af "^toipe " >/dev/null && {
        echo easy
        return
    }

    echo none
}

current="$(get_current_mode)"

if [[ "$current" == "$mode" ]]; then
    pkill -x toipe
    exit 0
fi

pkill -x toipe 2>/dev/null

sleep 0.1

case "$mode" in
easy)
    setsid alacritty --class toipe \
        -e toipe -n 60 \
        >/dev/null 2>&1 &
    ;;
medium)
    setsid alacritty --class toipe \
        -e toipe -n 60 -p \
        >/dev/null 2>&1 &
    ;;
hard)
    setsid alacritty --class toipe \
        -e toipe -n 60 -p -w commonly-misspelled \
        >/dev/null 2>&1 &
    ;;
esac
