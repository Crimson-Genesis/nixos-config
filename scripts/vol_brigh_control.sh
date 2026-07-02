#!/usr/bin/env bash

SEGMENTS=30

show_help() {
    cat <<EOF
volume-brightness

Usage:
    $(basename "$0") COMMAND [VALUE]

Volume:
    volup [STEP]            Increase volume by STEP (default: 5)
    voldown [STEP]          Decrease volume by STEP (default: 5)
    mute                    Toggle mute

    vol VALUE              Set volume to VALUE (0-100)
    vol --rofi             Select volume using a Rofi prompt

Brightness:
    brightup [STEP]         Increase brightness by STEP (default: 5)
    brightdown [STEP]       Decrease brightness by STEP (default: 5)

    bright VALUE           Set brightness to VALUE (0-100)
    bright --rofi          Select brightness using a Rofi prompt

Options:
    -h, --help             Show this help message

Examples:

    $(basename "$0") volup
    $(basename "$0") volup 10
    $(basename "$0") voldown
    $(basename "$0") voldown 15

    $(basename "$0") mute

    $(basename "$0") vol 20
    $(basename "$0") vol 75
    $(basename "$0") vol --rofi

    $(basename "$0") brightup
    $(basename "$0") brightup 20
    $(basename "$0") brightdown
    $(basename "$0") brightdown 10

    $(basename "$0") bright 30
    $(basename "$0") bright 90
    $(basename "$0") bright --rofi

Notes:

    • VALUE is automatically clamped to the range 0-100.
    • STEP must be a positive integer.
    • volup/voldown default to a step of 5 when omitted.
    • brightup/brightdown default to a step of 5 when omitted.
    • --rofi requires rofi to be installed.
    • If neither VALUE nor --rofi is provided for vol/bright,
      the command exits with an error.
    • Notifications are shown after every successful change.
EOF
}

check_dependencies() {
    local missing=()

    command -v pamixer >/dev/null 2>&1 || missing+=("pamixer")
    command -v brightnessctl >/dev/null 2>&1 || missing+=("brightnessctl")
    command -v notify-send >/dev/null 2>&1 || missing+=("notify-send")

    if ((${#missing[@]})); then
        printf 'Missing dependencies: %s\n' "${missing[*]}" >&2

        command -v notify-send >/dev/null 2>&1 &&
            notify-send "volume-brightness" \
                "Missing dependencies: ${missing[*]}"

        exit 1
    fi
}

bar() {
    local percent="$1"

    local filled=$((percent * SEGMENTS / 100))
    local empty=$((SEGMENTS - filled))

    for ((i = 0; i < filled; i++)); do
        printf '■'
    done

    for ((i = 0; i < empty; i++)); do
        printf '□'
    done
}

notify_volume() {
    local vol icon

    vol=$(pamixer --get-volume)

    if [ "$(pamixer --get-mute)" = "true" ]; then
        icon="󰝟"
    elif ((vol == 0)); then
        icon="󰝟"
    elif ((vol <= 30)); then
        icon="󰖀"
    else
        icon="󰕾"
    fi

    notify-send \
        -r 9991 \
        -h string:x-dunst-stack-tag:volume \
        "$(printf '%s %3d%%  %s' "$icon" "$vol" "$(bar "$vol")")"
}

notify_brightness() {
    local cur max percent icon

    cur=$(brightnessctl get)
    max=$(brightnessctl max)
    percent=$((cur * 100 / max))

    if ((percent <= 10)); then
        icon="󰃛"
    elif ((percent <= 25)); then
        icon="󰃞"
    elif ((percent <= 50)); then
        icon="󰃟"
    elif ((percent <= 75)); then
        icon="󰃝"
    elif ((percent <= 90)); then
        icon="󰃠"
    else
        icon="󰃚"
    fi

    notify-send \
        -r 9992 \
        -h string:x-dunst-stack-tag:brightness \
        "$(printf '%s %3d%%  %s' "$icon" "$percent" "$(bar "$percent")")"
}

set_bright() {
    local cur max percent

    max=$(brightnessctl max)
    cur=$(brightnessctl get)
    percent=$((cur * 100 / max))

    if [ "$2" = "--rofi" ]; then
        command -v rofi >/dev/null 2>&1 || {
            echo "Error" "rofi is not installed"
            notify-send -a error "Error" "rofi is not installed"
            exit 1
        }

        setbright=$(rofi -dmenu -p "󰃠 Brightness [$percent] (0-100):")
    else
        setbright="$2"
    fi

    [ -n "$setbright" ] || {
        echo "Usage: $(basename "$0") bright <0-100> | bright --rofi"
        notify-send -a error "Error" "Usage: $(basename "$0") bright <0-100> | bright --rofi"
        exit 1
    }

    [[ "$setbright" =~ ^[0-9]+$ ]] || {
        echo "Brightness must be a number"
        notify-send -a error "Error" "Brightness must be a number"
        exit 1
    }

    ((setbright < 0)) && setbright=0
    ((setbright > 100)) && setbright=100

    brightnessctl set "${setbright}%" >/dev/null
    notify_brightness
}

set_vol() {
    local vol

    vol=$(pamixer --get-volume)
    if [ "$2" = "--rofi" ]; then
        command -v rofi >/dev/null 2>&1 || {
            echo "Error" "rofi is not installed"
            notify-send -a error "Error" "rofi is not installed"
            exit 1
        }

        setvol=$(rofi -dmenu -p "󰕾 Volume [$vol] (0-100):")
    else
        setvol="$2"
    fi

    [ -n "$setvol" ] || {
        echo "Usage: $(basename "$0") vol <0-100> | vol --rofi"
        notify-send -a error "Usage: $(basename "$0") vol <0-100> | vol --rofi"
        exit 1
    }

    [[ "$setvol" =~ ^[0-9]+$ ]] || {
        echo "Volume must be a number"
        notify-send -a error "Volume must be a number"
        exit 1
    }

    ((setvol < 0)) && setvol=0
    ((setvol > 100)) && setvol=100

    pamixer --set-volume "$setvol"
    notify_volume

}

check_dependencies

case "$1" in
-h | --help)
    show_help
    ;;

volup)
    step="${2:-5}"

    [[ "$step" =~ ^[0-9]+$ ]] || {
        echo "volup requires a numeric value"
        notify-send -a error "volup requires a numeric value"
        exit 1
    }

    pamixer -i "$step"
    notify_volume
    ;;

voldown)
    step="${2:-5}"

    [[ "$step" =~ ^[0-9]+$ ]] || {
        echo "voldown requires a numeric value"
        notify-send -a error "voldown requires a numeric value"
        exit 1
    }

    pamixer -d "$step"
    notify_volume
    ;;

mute)
    pamixer -t
    notify_volume
    ;;

vol)
    set_vol "$@"
    ;;

brightup)
    step="${2:-5}"

    [[ "$step" =~ ^[0-9]+$ ]] || {
        echo "brightup requires a numeric value"
        notify-send -a error "brightup requires a numeric value"
        exit 1
    }

    brightnessctl set +"${step}%" >/dev/null
    notify_brightness
    ;;

brightdown)
    step="${2:-5}"

    [[ "$step" =~ ^[0-9]+$ ]] || {
        echo "brightdown requires a numeric value"
        notify-send -a error "brightdown requires a numeric value"
        exit 1
    }

    brightnessctl set "${step}%-" >/dev/null
    notify_brightness
    ;;

bright)
    set_bright "$@"
    ;;

*)
    echo "Unknown command: $1"
    echo "Use --help for usage."
    exit 1
    ;;
esac
