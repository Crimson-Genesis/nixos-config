#!/usr/bin/env bash

SELECTED_THEME="$(tmux show-option -gv @crimson-tmux_theme)"

case $SELECTED_THEME in
"storm")
    declare -A THEME=(
        ["background"]="#24283b"
        ["foreground"]="#a9b1d6"
        ["black"]="#414868"
        ["blue"]="#7aa2f7"
        ["cyan"]="#7dcfff"
        ["green"]="#73daca"
        ["magenta"]="#bb9af7"
        ["red"]="#f7768e"
        ["white"]="#a9b1d6"
        ["yellow"]="#e0af68"

        ["bblack"]="#414868"
        ["bblue"]="#7aa2f7"
        ["bcyan"]="#7dcfff"
        ["bgreen"]="#41a6b5"
        ["bmagenta"]="#bb9af7"
        ["bred"]="#f7768e"
        ["bwhite"]="#787c99"
        ["byellow"]="#e0af68"
    )
    ;;

"day")
    declare -A THEME=(
        ["background"]="#d5d6db"
        ["foreground"]="#343b58"
        ["black"]="#0f0f14"
        ["blue"]="#34548a"
        ["cyan"]="#0f4b6e"
        ["green"]="#33635c"
        ["magenta"]="#5a4a78"
        ["red"]="#8c4351"
        ["white"]="#343b58"
        ["yellow"]="#8f5e15"

        ["bblack"]="#9699a3"
        ["bblue"]="#34548a"
        ["bcyan"]="#0f4b6e"
        ["bgreen"]="#33635c"
        ["bmagenta"]="#5a4a78"
        ["bred"]="#8c4351"
        ["bwhite"]="#343b58"
        ["byellow"]="#8f5815"
    )
    ;;

"black")
    declare -A THEME=(
        ["background"]="#000000"
        ["foreground"]="#b0b0b0"

        ["black"]="#101010"
        ["white"]="#ffffff"

        ["bblack"]="#2a2a2a"
        ["bwhite"]="#d0d0d0"

        ["blue"]="#303030"
        ["cyan"]="#404040"
        ["green"]="#505050"
        ["magenta"]="#606060"
        ["red"]="#707070"
        ["yellow"]="#808080"

        ["bblue"]="#404040"
        ["bcyan"]="#505050"
        ["bgreen"]="#606060"
        ["bmagenta"]="#707070"
        ["bred"]="#808080"
        ["byellow"]="#909090"
    )
    ;;

*)
    declare -A THEME=(
        ["background"]="#000000"
        ["foreground"]="#afafaf"

        ["black"]="#202020"
        ["blue"]="#7aa2f7"
        ["cyan"]="#4abaaf"
        ["green"]="#9ece6a"
        ["magenta"]="#9a7ecc"
        ["red"]="#49010e"
        ["white"]="#c9c9c9"
        ["yellow"]="#e0af68"

        ["bblack"]="#202020"
        ["bblue"]="#7aa2f7"
        ["bcyan"]="#4abaaf"
        ["bgreen"]="#9ece6a"
        ["bmagenta"]="#9a7ecc"
        ["bred"]="#49010e"
        ["bwhite"]="#afafaf"
        ["byellow"]="#e0af68"
    )
    ;;
esac

THEME['ghgreen']="#505050"
THEME['ghmagenta']="#707070"
THEME['ghred']="#606060"
THEME['ghyellow']="#909090"

RESET="#[fg=${THEME[foreground]},bg=${THEME[background]},nobold,noitalics,nounderscore,nodim]"
