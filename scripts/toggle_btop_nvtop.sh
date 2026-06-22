#!/usr/bin/env bash

if xdotool search --class btop_ >/dev/null 2>&1; then
    xdotool search --class btop_ windowkill
    xdotool search --class _nvtop windowkill
else
    alacritty --class btop_ -e btop &
    alacritty --class _nvtop -e nvtop &
fi
