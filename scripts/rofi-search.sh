#!/usr/bin/env bash

ENGINE="ddg"
BROWSER="zen"

HISTORY_FILE="$HOME/.cache/rofi/rofi-search.history"
MAX_HISTORY=1000

mkdir -p "$(dirname "$HISTORY_FILE")"
touch "$HISTORY_FILE"

show_help() {
    cat <<EOF
rofi-search

Usage:
    rofi-search [OPTIONS]

Options:
    -e, --engine ENGINE
        Search engine to use.

    -b, --browser BROWSER
        Browser executable to use.

    -h, --help
        Show this help message.

    --history
        Print search history.

    --clear-history
        Clear search history.

Search Engines:
    ddg         DuckDuckGo (default)
    duckduckgo  DuckDuckGo
    brave       Brave Search
    google      Google Search
    startpage   Startpage

Examples:

    rofi-search
    rofi-search -e google
    rofi-search -e brave
    rofi-search -b firefox
    rofi-search -e google -b firefox
    rofi-search -e ddg -b chromium

Supported Input:

    Search Queries
        nixos flakes
        xmonad workspace docs

    Domains
        google.com
        github.com/user/repo

    URLs
        https://example.com
        http://example.com

    Localhost
        localhost
        localhost:3000

    IP Addresses
        192.168.1.1
        192.168.1.1:8080

    Files
        ~/Downloads/file.pdf
        ./README.md

    Directories
        ~/Downloads
        ../project

Special:

    Append * to bypass history matches.

        tube.com*
        nixos flakes*

Behavior:

    • Files open with xdg-open.
    • Directories open with xdg-open.
    • URLs open in the selected browser.
    • Search queries use the selected search engine.
    • History is shown in rofi.
    • Duplicate history entries are moved to the top.
    • History is limited to ${MAX_HISTORY} entries.

EOF
}

save_history() {
    local entry="$1"

    [ -z "$entry" ] && return

    grep -Fxv "$entry" "$HISTORY_FILE" >"${HISTORY_FILE}.tmp" 2>/dev/null

    printf '%s\n' "$entry" >>"${HISTORY_FILE}.tmp"

    tail -n "$MAX_HISTORY" "${HISTORY_FILE}.tmp" >"${HISTORY_FILE}.new"

    mv "${HISTORY_FILE}.new" "$HISTORY_FILE"
    rm -f "${HISTORY_FILE}.tmp"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
    -e | --engine)
        ENGINE="$2"
        shift 2
        ;;

    -b | --browser)
        BROWSER="$2"
        shift 2
        ;;

    -h | --help)
        show_help
        exit 0
        ;;

    --history)
        cat "$HISTORY_FILE"
        exit 0
        ;;

    --clear-history)
        : >"$HISTORY_FILE"
        echo "History cleared."
        exit 0
        ;;

    *)
        echo "Unknown option: $1"
        echo "Use --help for usage."
        exit 1
        ;;
    esac
done

case "$ENGINE" in
duckduckgo | ddg)
    SEARCH_ENGINE="https://duckduckgo.com/?q="
    ;;
google)
    SEARCH_ENGINE="https://www.google.com/search?q="
    ;;
startpage)
    SEARCH_ENGINE="https://www.startpage.com/search?q="
    ;;
brave)
    SEARCH_ENGINE="https://search.brave.com/search?q="
    ;;
*)
    echo "Unknown search engine: $ENGINE"
    exit 1
    ;;
esac

query=$(
    tac "$HISTORY_FILE" 2>/dev/null |
        rofi -dmenu \
            -i \
            -matching fuzzy \
            -sort \
            -p "󰍉 Search:"
)

query="$(printf '%s' "$query" | xargs)"

[ -z "$query" ] && exit 0

# Remove trailing * if present
if [[ "$query" == *\* ]]; then
    query="${query%\*}"
    query="$(printf '%s' "$query" | xargs)"
fi

[ -z "$query" ] && exit 0

save_history "$query"

# Expand ~

if [[ "$query" == "~"* ]]; then
    query="${query/#\~/$HOME}"
fi

# Existing file or directory

if [ -e "$query" ]; then
    xdg-open "$query" >/dev/null 2>&1 &
    exit 0
fi

case "$query" in

http://* | https://*)
    url="$query"
    ;;

localhost | localhost:* | localhost/* | localhost:*/*)
    url="http://$query"
    ;;

[0-9]*.[0-9]*.[0-9]*.[0-9]*)
    url="http://$query"
    ;;

*)
    if [[ "$query" =~ ^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(:[0-9]+)?(/.*)?$ ]]; then
        url="https://$query"
    else
        encoded=$(printf '%s' "$query" | sed 's/ /+/g')
        url="${SEARCH_ENGINE}${encoded}"
    fi
    ;;
esac

if pgrep -af zen >/dev/null; then
    wmctrl -xa zen
fi

"$BROWSER" --new-tab "$url" >/dev/null 2>&1 &
