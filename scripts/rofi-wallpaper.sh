#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# CONFIG
# ============================================================
STATIC_DIR="${STATIC_DIR:-/mnt/data/wallpaper}"
VIDEO_DIR="${VIDEO_DIR:-/mnt/data/video_wallpaper}"

ROFI_CMD="${ROFI_CMD:-rofi -dmenu -i}"
STATIC_SETTER="${STATIC_SETTER:-feh --bg-fill}"

# xwinwrap + mpv wallpaper command
VIDEO_CMD_TEMPLATE=(
    xwinwrap
    -fs -ni -s -st -sp -b -nf -ov
    --
    mpv
    -wid WID
    --no-config
    --no-audio
    --loop-file=inf
    --profile=fast
    --hwdec=auto-safe
    --vd-lavc-threads=1
    --framedrop=vo
    --no-osc
    --no-osd-bar
    --no-input-default-bindings
)

# what to kill when switching video wallpapers
XWINWRAP_MATCH='xwinwrap -fs -ni -s -st -sp -b -nf -ov'
MPV_WALLPAPER_MATCH='mpv -wid'

# cache / state
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-wallpaper"
STATE_FILE="$CACHE_DIR/state"
mkdir -p "$CACHE_DIR"

STATIC_EXTS=(jpg jpeg png webp bmp jfif avif)
VIDEO_EXTS=(mp4 mkv webm mov avi m4v)

# ============================================================
# HELPERS
# ============================================================
notify() {
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send "Wallpaper" "$1" >/dev/null 2>&1 || true
}

die() {
    notify "$1"
    echo "$1" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

usage() {
    cat <<EOF
Usage:
  rofi-wallpaper static random
  rofi-wallpaper static pick
  rofi-wallpaper video random
  rofi-wallpaper video pick
  rofi-wallpaper stop-video
  rofi-wallpaper restart-video
  rofi-wallpaper toggle-video-random
  rofi-wallpaper status
  rofi-wallpaper help

Commands:
  static random         Set random static wallpaper from STATIC_DIR
  static pick           Pick static wallpaper from STATIC_DIR using rofi
  video random          Set random video wallpaper from VIDEO_DIR
  video pick            Pick video wallpaper from VIDEO_DIR using rofi
  stop-video            Kill current video wallpaper
  restart-video         Restart the last chosen video wallpaper
  toggle-video-random   Toggle random video wallpaper on/off
  status                Show current saved wallpaper state
  help                  Show this help

Environment overrides:
  STATIC_DIR        Default: $STATIC_DIR
  VIDEO_DIR         Default: $VIDEO_DIR
  ROFI_CMD          Default: $ROFI_CMD
  STATIC_SETTER     Default: $STATIC_SETTER

Examples:
  rofi-wallpaper static random
  rofi-wallpaper static pick
  rofi-wallpaper video random
  rofi-wallpaper video pick
  rofi-wallpaper toggle-video-random
EOF
}

save_state() {
    local mode="$1"
    local file="$2"
    {
        printf 'MODE=%q\n' "$mode"
        printf 'FILE=%q\n' "$file"
    } >"$STATE_FILE"
}

load_state() {
    [[ -f "$STATE_FILE" ]] || return 1
    # shellcheck disable=SC1090
    source "$STATE_FILE"
}

build_find_expr() {
    local ext
    local first=1
    for ext in "$@"; do
        if ((first)); then
            printf -- '-iname *.%q' "$ext"
            first=0
        else
            printf -- ' -o -iname *.%q' "$ext"
        fi
    done
}

collect_files() {
    local dir="$1"
    shift
    local -a exts=("$@")

    [[ -d "$dir" ]] || die "Directory not found: $dir"

    local -a cmd=(find "$dir" -type f '(')
    local first=1 ext
    for ext in "${exts[@]}"; do
        if ((first)); then
            cmd+=(-iname "*.$ext")
            first=0
        else
            cmd+=(-o -iname "*.$ext")
        fi
    done
    cmd+=(')')

    "${cmd[@]}"
}

random_file() {
    local dir="$1"
    shift
    local -a exts=("$@")
    local -a files=()

    mapfile -t files < <(collect_files "$dir" "${exts[@]}" | sort)

    ((${#files[@]} > 0)) || die "No matching files in $dir"

    printf '%s\n' "${files[RANDOM % ${#files[@]}]}"
}

pick_file() {
    local prompt="$1"
    local dir="$2"
    shift 2
    local -a exts=("$@")
    local -a files=()

    mapfile -t files < <(collect_files "$dir" "${exts[@]}" | sort)
    ((${#files[@]} > 0)) || die "No matching files in $dir"

    local choice line
    choice="$(
        for line in "${files[@]}"; do
            printf '%s\n' "$(basename "$line")"
        done | eval "$ROFI_CMD -p \"$prompt\""
    )"

    [[ -n "${choice:-}" ]] || return 1

    for line in "${files[@]}"; do
        if [[ "$(basename "$line")" == "$choice" ]]; then
            printf '%s\n' "$line"
            return 0
        fi
    done

    return 1
}

kill_video_wallpaper() {
    pkill -f "$XWINWRAP_MATCH" >/dev/null 2>&1 || true
    pkill -f "$MPV_WALLPAPER_MATCH" >/dev/null 2>&1 || true
}

set_static() {
    local file="$1"
    [[ -f "$file" ]] || die "Static wallpaper not found: $file"

    kill_video_wallpaper

    # shellcheck disable=SC2086
    eval "$STATIC_SETTER \"\$file\""

    save_state "static" "$file"
    notify "Static: $(basename "$file")"
}

set_video() {
    local file="$1"
    local silent="${2:-0}"

    [[ -f "$file" ]] || die "Video wallpaper not found: $file"
    have xwinwrap || die "xwinwrap is required"
    have mpv || die "mpv is required"

    kill_video_wallpaper
    sleep 0.2

    nohup "${VIDEO_CMD_TEMPLATE[@]}" "$file" >/dev/null 2>&1 &
    disown || true

    save_state "video" "$file"

    [[ "$silent" == "1" ]] || notify "Video: $(basename "$file")"
}

toggle_video_random() {
    if pgrep -f "$XWINWRAP_MATCH" >/dev/null 2>&1 || pgrep -f "$MPV_WALLPAPER_MATCH" >/dev/null 2>&1; then
        kill_video_wallpaper
        notify "Video wallpaper stopped"
    else
        local file
        file="$(random_file "$VIDEO_DIR" "${VIDEO_EXTS[@]}")"
        set_video "$file"
    fi
}

show_status() {
    if ! load_state; then
        echo "No saved wallpaper state"
        exit 1
    fi

    cat <<EOF
Mode : ${MODE:-unknown}
File : ${FILE:-unknown}

Static dir: $STATIC_DIR
Video dir : $VIDEO_DIR
EOF
}

restart_video() {
    if ! load_state; then
        notify "No saved wallpaper state"
        return 1
    fi

    if [[ "${MODE:-}" != "video" ]]; then
        notify "Last saved wallpaper is not a video wallpaper"
        return 1
    fi

    if [[ ! -f "${FILE:-}" ]]; then
        notify "Saved video file does not exist: ${FILE:-}"
        return 1
    fi

    if pgrep -f "$XWINWRAP_MATCH" >/dev/null 2>&1 || pgrep -f "$MPV_WALLPAPER_MATCH" >/dev/null 2>&1; then
        set_video "$FILE"
        notify "Video wallpaper restarted: $(basename "$FILE")"
    else
        set_video "$FILE"
        notify "Video wallpaper started: $(basename "$FILE")"
    fi
}

# ============================================================
# MAIN
# ============================================================
case "${1:-}" in
"" | -h | --help | help)
    usage
    exit 0
    ;;
esac

mode="${1:-}"
action="${2:-}"

case "$mode:$action" in
static:random)
    file="$(random_file "$STATIC_DIR" "${STATIC_EXTS[@]}")"
    set_static "$file"
    ;;

static:pick)
    have rofi || die "rofi is required"
    file="$(pick_file "Static-wallpaper:" "$STATIC_DIR" "${STATIC_EXTS[@]}")"
    [[ -n "${file:-}" ]] || exit 0
    set_static "$file"
    ;;

video:random)
    file="$(random_file "$VIDEO_DIR" "${VIDEO_EXTS[@]}")"
    set_video "$file"
    ;;

video:pick)
    have rofi || die "rofi is required"
    file="$(pick_file "Video-wallpaper:" "$VIDEO_DIR" "${VIDEO_EXTS[@]}")"
    [[ -n "${file:-}" ]] || exit 0
    set_video "$file"
    ;;

stop-video:)
    if pgrep -f "$XWINWRAP_MATCH" >/dev/null 2>&1 || pgrep -f "$MPV_WALLPAPER_MATCH" >/dev/null 2>&1; then
        kill_video_wallpaper
        notify "Video wallpaper stopped"
    else
        notify "No video wallpaper is running"
    fi
    ;;

restart-video:)
    restart_video
    ;;

toggle-video-random:)
    toggle_video_random
    ;;

status:)
    show_status
    ;;

*)
    usage
    exit 1
    ;;
esac
