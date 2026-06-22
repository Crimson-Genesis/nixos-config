#!/usr/bin/env bash

if [[ "${ROFI_RETV:-0}" -eq 0 ]]; then
    find -L $(manpath | tr ':' ' ') \
        -type f \
        \( -name '*.[1-9]' -o -name '*.[1-9].gz' \) \
        2>/dev/null |
        sed 's|.*/||' |
        sed -E 's/\.gz$//' |
        sort -u
    exit 0
fi

setsid alacritty --class manpage -e man "$1" >/dev/null 2>&1 &
exit 0
