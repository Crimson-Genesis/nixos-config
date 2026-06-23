#!/usr/bin/env bash

CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_PATH="$CURRENT_DIR/src"

source "$SCRIPTS_PATH/themes.sh"

# ------------------------------------------------------------------------------
# Status Bar
# ------------------------------------------------------------------------------

tmux set -g status-left-length 80
tmux set -g status-right-length 150

tmux set -g status-style "fg=${THEME[foreground]},bg=${THEME[background]}"

# ------------------------------------------------------------------------------
# Copy Mode / Messages
# ------------------------------------------------------------------------------

tmux set -g mode-style "fg=${THEME[white]},bg=${THEME[bblack]}"

tmux set -g message-style "fg=${THEME[white]},bg=${THEME[bblack]}"

tmux set -g message-command-style "fg=${THEME[white]},bg=${THEME[bblack]}"

# ------------------------------------------------------------------------------
# Pane Borders
# ------------------------------------------------------------------------------

tmux set -g pane-border-style "fg=${THEME[black]}"

tmux set -g pane-active-border-style "fg=${THEME[bwhite]}"

tmux set -g pane-border-status off

# ------------------------------------------------------------------------------
# Widgets
# ------------------------------------------------------------------------------

netspeed="#($SCRIPTS_PATH/netspeed.sh)"
cmus_status="#($SCRIPTS_PATH/music-tmux-statusbar.sh)"
git_status="#($SCRIPTS_PATH/git-status.sh #{pane_current_path})"
wb_git_status="#($SCRIPTS_PATH/wb-git-status.sh #{pane_current_path} &)"
current_path="#($SCRIPTS_PATH/path-widget.sh #{pane_current_path})"
battery_status="#($SCRIPTS_PATH/battery-widget.sh)"
date_and_time="#($SCRIPTS_PATH/datetime-widget.sh)"

# ------------------------------------------------------------------------------
# Left
# ------------------------------------------------------------------------------

tmux set -g status-left "#[fg=${THEME[white]},bold] #S "

# ------------------------------------------------------------------------------
# Windows
# ------------------------------------------------------------------------------

tmux set -g window-status-format \
    "#[fg=colour240]#I#[fg=${THEME[foreground]}]:#W "

tmux set -g window-status-current-format \
    "#[fg=${THEME[background]},bg=${THEME[bwhite]},bold]#I:#W "

tmux set -g window-status-separator " "

# ------------------------------------------------------------------------------
# Right
# ------------------------------------------------------------------------------

tmux set -g status-right \
    "$battery_status$current_path$cmus_status$netspeed$git_status$wb_git_status$date_and_time"
