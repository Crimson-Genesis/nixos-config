#!/usr/bin/env bash

set -euo pipefail

# ==========================================
# Configuration
# ==========================================

PROGRAM="${0##*/}"

# ==========================================
# Utilities
# ==========================================

error() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

usage() {
    cat <<EOF
Usage:
    $PROGRAM [OPTION] [ARGUMENTS]

Options:
    --file-name <search> <replacement>
        Replace text in filenames in the current directory.

    --help
        Display this help message.

Examples:
    $PROGRAM --file-name "old" "new"
    $PROGRAM --file-name ".1080p.WEB-DL." "."
EOF
}

# ==========================================
# Operations
# ==========================================

replace_file_name() {
    local search="$1"
    local replacement="$2"

    [[ -n "$search" ]] || error "Search term cannot be empty."

    local file
    local new_name
    local count=0

    shopt -s nullglob dotglob

    for file in *; do
        [[ -f "$file" ]] || continue
        [[ "$file" == *"$search"* ]] || continue

        new_name="${file//"$search"/"$replacement"}"

        [[ "$file" == "$new_name" ]] && continue

        if [[ -e "$new_name" ]]; then
            info "Skipped: '$new_name' already exists."
            continue
        fi

        mv -- "$file" "$new_name"

        info "Renamed: '$file' -> '$new_name'"
        ((count += 1))
    done

    info "Completed: $count file(s) renamed."
}

# ==========================================
# Argument Parser
# ==========================================

main() {
    [[ $# -gt 0 ]] || {
        usage
        exit 1
    }

    while [[ $# -gt 0 ]]; do
        case "$1" in

        --file-name)
            [[ $# -ge 3 ]] || error \
                "--file-name requires <search> <replacement>"

            replace_file_name "$2" "$3"
            shift 3
            ;;

        --help | -h)
            usage
            exit 0
            ;;

        *)
            error "Unknown option: $1. Use --help."
            ;;

        esac
    done
}

# ==========================================
# Entry Point
# ==========================================

main "$@"
