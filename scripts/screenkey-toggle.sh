#!/usr/bin/env bash

if pgrep -af ".screenkey-wrapped" >/dev/null; then
    pkill -f ".screenkey-wrapped"
else
    screenkey \
        --no-systray \
        -p fixed \
        -g '30%x8%+69%+90%' \
        -f "JetBrainsMono Nerd Font Mono Bold" &
fi
