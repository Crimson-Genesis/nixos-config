#!/usr/bin/env bash
# ==============================================================================
# yt-dlq.sh - Robust interactive & CLI wrapper for yt-dlp
# ==============================================================================
set -euo pipefail

readonly SCRIPT_NAME="$(basename "$0")"
readonly SCRIPT_VERSION="2.0.0"

# ------------------------------------------------------------------------------
# Terminal & Color Utilities
# ------------------------------------------------------------------------------
# Disable colors if stdout is not a TTY or NO_COLOR is set
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    readonly CLR_RESET=$'\033[0m'
    readonly CLR_BOLD=$'\033[1m'
    readonly CLR_RED=$'\033[38;5;1m'
    readonly CLR_GREEN=$'\033[38;5;2m'
    readonly CLR_YELLOW=$'\033[38;5;3m'
    readonly CLR_BLUE=$'\033[38;5;4m'
    readonly CLR_CYAN=$'\033[38;5;6m'
    readonly CLR_GRAY=$'\033[38;5;8m'
else
    readonly CLR_RESET=""
    readonly CLR_BOLD=""
    readonly CLR_RED=""
    readonly CLR_GREEN=""
    readonly CLR_YELLOW=""
    readonly CLR_BLUE=""
    readonly CLR_CYAN=""
    readonly CLR_GRAY=""
fi

# Backward-compatible cecho function
cecho() {
    local color_code="$1"
    local message="$2"
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
        printf '\033[38;5;%sm%s\033[0m\n' "${color_code}" "${message}"
    else
        printf '%s\n' "${message}"
    fi
}

log_info() { printf '%s[INFO] %s%s\n' "${CLR_CYAN}" "$*" "${CLR_RESET}"; }
log_success() { printf '%s[OK] %s%s\n' "${CLR_GREEN}" "$*" "${CLR_RESET}"; }
log_warn() { printf '%s[WARN] %s%s\n' "${CLR_YELLOW}" "$*" "${CLR_RESET}" >&2; }
log_error() { printf '%s[ERROR] %s%s\n' "${CLR_RED}" "$*" "${CLR_RESET}" >&2; }

# ------------------------------------------------------------------------------
# Signal Handling
# ------------------------------------------------------------------------------
cleanup() {
    local exit_code=$?
    if [[ -t 1 ]]; then
        tput cnorm 2>/dev/null || true
    fi
    exit "$exit_code"
}
trap cleanup EXIT
trap 'log_warn "Process interrupted by user."; exit 130' INT TERM

# ------------------------------------------------------------------------------
# Dependency Verification
# ------------------------------------------------------------------------------
check_dependency() {
    local cmd="$1"
    local install_hint="$2"
    if ! command -v "$cmd" &>/dev/null; then
        log_error "Required dependency '$cmd' is not installed or not in PATH."
        if [[ -n "$install_hint" ]]; then
            printf '%sHint: %s%s\n' "${CLR_GRAY}" "$install_hint" "${CLR_RESET}" >&2
        fi
        return 1
    fi
    return 0
}

# ------------------------------------------------------------------------------
# Help / Usage Information
# ------------------------------------------------------------------------------
show_version() {
    printf '%s v%s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"
}

show_help() {
    cat <<EOF
${CLR_BOLD}${SCRIPT_NAME}${CLR_RESET} - Streamlined, robust YouTube & media downloader using yt-dlp

${CLR_BOLD}USAGE:${CLR_RESET}
  ${SCRIPT_NAME} <MODE> [URL] [OPTIONS]
  ${SCRIPT_NAME} [OPTIONS]

${CLR_BOLD}MODES:${CLR_RESET}
  ${CLR_GREEN}video${CLR_RESET}   | ${CLR_GREEN}v${CLR_RESET}         Download single video only (enforces --no-playlist)
  ${CLR_GREEN}list${CLR_RESET}    | ${CLR_GREEN}playlist${CLR_RESET} | ${CLR_GREEN}l${CLR_RESET} Download full playlist (organized by Uploader/Playlist/Index - Title)
  ${CLR_GREEN}channel${CLR_RESET} | ${CLR_GREEN}c${CLR_RESET}        Download full channel (organized by Uploader/Date - Title)

${CLR_BOLD}OPTIONS:${CLR_RESET}
  ${CLR_CYAN}-u, --url <url>${CLR_RESET}             Specify target URL directly
  ${CLR_CYAN}-c, --cookies <browser|file>${CLR_RESET} Use browser cookies (chrome, firefox, brave, edge) or cookies file
  ${CLR_CYAN}-q, --picker, --select${CLR_RESET}      Interactive format picker via fzf (samples 1st item for playlists)
  ${CLR_CYAN}-f, --format <fmt>${CLR_RESET}          Specify custom yt-dlp format (e.g., 'bestvideo+bestaudio')
  ${CLR_CYAN}-x, --audio-only${CLR_RESET}           Extract audio only (best quality mp3)
  ${CLR_CYAN}-i, --items <spec>${CLR_RESET}           Download specific playlist items/range (e.g., '1:10', '1,3,5', '5:')
  ${CLR_CYAN}-r, --reverse${CLR_RESET}               Download playlist in reverse order
  ${CLR_CYAN}-o, --output <template>${CLR_RESET}     Custom output template or path
  ${CLR_CYAN}-a, --archive <file>${CLR_RESET}        Custom download archive file (default: archive.txt)
  ${CLR_CYAN}--no-archive${CLR_RESET}                Disable download archive tracking
  ${CLR_CYAN}-h, --help${CLR_RESET}                  Show this help message and exit
  ${CLR_CYAN}-v, --version${CLR_RESET}               Show script version and exit

${CLR_BOLD}PLAYLIST FEATURES:${CLR_RESET}
  - Auto-organization: Saves to 'Uploader/Playlist_Title/01 - Video_Title.mp4'
  - Incremental Sync: Tracks progress in 'archive.txt' (skips already downloaded videos)
  - Fast Format Picker: Samples the 1st playlist video for rapid interactive format selection
  - Item Range Filtering: Download specific slices using --items (e.g., --items 1:5)
  - Single Video Safety: 'video' mode automatically prevents accidental whole-playlist downloads

${CLR_BOLD}EXAMPLES:${CLR_RESET}
  ${CLR_GRAY}# Interactive prompt for single video:${CLR_RESET}
  ${SCRIPT_NAME} video

  ${CLR_GRAY}# Fix 403 Forbidden by passing browser cookies:${CLR_RESET}
  ${SCRIPT_NAME} video "https://www.youtube.com/watch?v=..." --cookies chrome

  ${CLR_GRAY}# Download single video directly with interactive format picker (fzf):${CLR_RESET}
  ${SCRIPT_NAME} video "https://www.youtube.com/watch?v=dQw4w9WgXcQ" -q

  ${CLR_GRAY}# Download entire playlist:${CLR_RESET}
  ${SCRIPT_NAME} playlist "https://www.youtube.com/playlist?list=PL123..."

  ${CLR_GRAY}# Download only the first 10 items of a playlist:${CLR_RESET}
  ${SCRIPT_NAME} list "https://www.youtube.com/playlist?list=PL123..." --items 1:10

  ${CLR_GRAY}# Download playlist in reverse order as MP3 audio files:${CLR_RESET}
  ${SCRIPT_NAME} playlist "https://www.youtube.com/playlist?list=PL123..." --audio-only --reverse

${CLR_BOLD}DEPENDENCIES:${CLR_RESET}
  - yt-dlp (Required)
  - fzf    (Required when using -q / interactive format picker)
  - ffmpeg (Recommended for muxing video + audio and audio extraction)
EOF
}

# ------------------------------------------------------------------------------
# Interactive Format Selection (fzf)
# ------------------------------------------------------------------------------
select_format_interactive() {
    local url="$1"
    check_dependency "fzf" "Install fzf via your package manager (e.g., sudo apt install fzf / brew install fzf / pacman -S fzf)" || return 1

    log_info "Fetching available stream formats (sampling 1st item)..."
    local format_output
    # Use --playlist-items 1 so playlists don't query every single video when listing formats
    if ! format_output=$(yt-dlp --no-color --playlist-items 1 --list-formats "$url" 2>&1); then
        log_error "Failed to retrieve formats from URL. yt-dlp error output:"
        printf '%s\n' "$format_output" >&2
        return 1
    fi

    local formatted_table
    formatted_table=$(
        printf '%s\n' "$format_output" |
            sed -n '/Available formats for/,$p' |
            sed '1,2d' |
            sed 's/\x1b\[[0-9;]*m//g' |
            grep -E '^\s*(sb[0-9]+|[0-9]+(-[A-Za-z0-9]+)?)\b' || true
    )

    if [[ -z "$formatted_table" ]]; then
        formatted_table=$(printf '%s\n' "$format_output" | sed -n '/ID/,$p')
    fi

    if [[ -z "$formatted_table" ]]; then
        log_warn "No parsed format list available. Falling back to default format."
        printf '%s' "bestvideo+bestaudio"
        return 0
    fi

    local sel
    sel=$(
        printf '%s\n' "$formatted_table" |
            fzf --no-hscroll --ansi --reverse \
                --prompt="Select format (Enter=confirm, Esc=cancel) > " \
                --header="Format list for $url (sampled from 1st item)" \
                --preview='echo {}' \
                --preview-window=down:3:wrap || true
    )

    if [[ -z "$sel" ]]; then
        log_warn "Format selection cancelled by user."
        return 130
    fi

    local chosen_id
    chosen_id=$(printf '%s' "$sel" | awk '{print $1}')

    # If user selected a video-only stream, automatically pair with best audio if not already paired
    if printf '%s\n' "$sel" | grep -qi 'video only' && [[ "$chosen_id" != *"+"* ]]; then
        chosen_id="${chosen_id}+bestaudio"
        log_info "Selected video-only format. Auto-appending best audio: ${CLR_BOLD}${chosen_id}${CLR_RESET}"
    fi

    printf '%s' "$chosen_id"
    return 0
}

# ------------------------------------------------------------------------------
# Main Application Logic
# ------------------------------------------------------------------------------
main() {
    # Fast-path for top-level help / version flags or no arguments
    if [[ $# -eq 0 ]]; then
        show_help
        exit 0
    fi

    local mode=""
    local url=""
    local custom_format=""
    local custom_output=""
    local archive_file="archive.txt"
    local cookies_arg=""
    local playlist_items=""
    local playlist_reverse=0
    local use_picker=0
    local audio_only=0

    # First check for help/version anywhere in arguments
    for arg in "$@"; do
        case "$arg" in
        -h | --help | help)
            show_help
            exit 0
            ;;
        -v | --version)
            show_version
            exit 0
            ;;
        esac
    done

    # Parse mode if first positional arg is a mode name
    case "${1:-}" in
    video | v)
        mode="video"
        shift
        ;;
    list | playlist | l)
        mode="list"
        shift
        ;;
    channel | c)
        mode="channel"
        shift
        ;;
    -*)
        # Options passed without mode; default to video mode
        mode="video"
        ;;
    *)
        # Could be a direct URL or invalid mode
        if [[ "${1:-}" =~ ^https?:// ]] || [[ "${1:-}" =~ ^ytsearch: ]]; then
            mode="video"
            url="$1"
            shift
        else
            log_error "Unknown mode or command: '$1'"
            printf 'Run %s%s --help%s for usage information.\n' "${CLR_BOLD}" "$SCRIPT_NAME" "${CLR_RESET}" >&2
            exit 1
        fi
        ;;
    esac

    # Parse remaining flags and positional arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        -u | --url)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires a URL argument."
                exit 1
            }
            url="$2"
            shift 2
            ;;
        -c | --cookies | --cookies-from-browser)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires a browser name (e.g. chrome, firefox) or cookie file."
                exit 1
            }
            cookies_arg="$2"
            shift 2
            ;;
        -q | --picker | --select)
            use_picker=1
            shift
            ;;
        -f | --format)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires a format string."
                exit 1
            }
            custom_format="$2"
            shift 2
            ;;
        -i | --items | --playlist-items)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires a range specifier (e.g. 1:10, 1,3,5)."
                exit 1
            }
            playlist_items="$2"
            shift 2
            ;;
        -r | --reverse | --playlist-reverse)
            playlist_reverse=1
            shift
            ;;
        -o | --output)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires an output template."
                exit 1
            }
            custom_output="$2"
            shift 2
            ;;
        -a | --archive)
            [[ -z "${2:-}" ]] && {
                log_error "Option '$1' requires a filename argument."
                exit 1
            }
            archive_file="$2"
            shift 2
            ;;
        --no-archive)
            archive_file=""
            shift
            ;;
        -x | --audio-only)
            audio_only=1
            shift
            ;;
        *)
            if [[ -z "$url" ]] && [[ "$1" =~ ^https?:// || "$1" =~ ^ytsearch: || "$1" =~ ^[A-Za-z0-9_-]{11}$ ]]; then
                url="$1"
                shift
            else
                log_warn "Ignoring unrecognized argument: '$1'"
                shift
            fi
            ;;
        esac
    done

    # Verify yt-dlp is available
    check_dependency "yt-dlp" "Please install yt-dlp (https://github.com/yt-dlp/yt-dlp)" || exit 1

    # Interactive prompt for URL if not provided
    if [[ -z "$url" ]]; then
        if [[ -t 0 ]]; then
            printf '%sMode: %s%s%s\n' "${CLR_GRAY}" "${CLR_BOLD}" "$mode" "${CLR_RESET}"
            read -e -r -p "Enter YouTube/Media URL: " url
            # Trim whitespace
            url="$(echo "$url" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')"
        else
            log_error "No URL provided and input is not interactive."
            exit 1
        fi
    fi

    if [[ -z "$url" ]]; then
        log_error "No URL provided. Aborting."
        exit 1
    fi

    # Determine naming template based on mode or custom override
    local namer=""
    if [[ -n "$custom_output" ]]; then
        namer="$custom_output"
    else
        case "$mode" in
        video)
            namer='%(title)s.%(ext)s'
            ;;
        list)
            namer='%(uploader)s/%(playlist_title)s/%(playlist_index)s - %(title)s.%(ext)s'
            ;;
        channel)
            namer='%(uploader)s/%(upload_date>%Y-%m-%d)s - %(title)s.%(ext)s'
            ;;
        esac
    fi

    # Determine format
    local fmt="bestvideo+bestaudio/best"
    if [[ "$audio_only" -eq 1 ]]; then
        fmt="bestaudio/best"
    elif [[ -n "$custom_format" ]]; then
        fmt="$custom_format"
    elif [[ "$use_picker" -eq 1 ]]; then
        local picked_fmt
        if ! picked_fmt=$(select_format_interactive "$url"); then
            exit 1
        fi
        fmt="$picked_fmt"
    fi

    # Build base yt-dlp argument array
    local -a ytdl_args=(
        "--continue"
        "--ignore-errors"
        "--no-overwrites"
        "-o" "$namer"
    )

    # Cookie configuration
    if [[ -n "$cookies_arg" ]]; then
        if [[ -f "$cookies_arg" ]]; then
            ytdl_args+=("--cookies" "$cookies_arg")
            log_info "Using cookies file: ${cookies_arg}"
        else
            ytdl_args+=("--cookies-from-browser" "$cookies_arg")
            log_info "Extracting cookies from browser: ${cookies_arg}"
        fi
    fi

    # Enforce playlist handling per mode
    if [[ "$mode" == "video" ]]; then
        ytdl_args+=("--no-playlist")
    else
        ytdl_args+=("--yes-playlist")
    fi

    # Playlist item range filtering
    if [[ -n "$playlist_items" ]]; then
        ytdl_args+=("--playlist-items" "$playlist_items")
    fi

    # Playlist reverse order
    if [[ "$playlist_reverse" -eq 1 ]]; then
        ytdl_args+=("--playlist-reverse")
    fi

    if [[ -n "$archive_file" ]]; then
        ytdl_args+=("--download-archive" "$archive_file")
    fi

    if [[ "$audio_only" -eq 1 ]]; then
        ytdl_args+=(
            "-f" "$fmt"
            "-x"
            "--audio-format" "mp3"
            "--audio-quality" "0"
        )
        log_info "Downloading audio [mp3] -> Output: ${namer}"
    else
        ytdl_args+=(
            "-f" "$fmt"
            "--merge-output-format" "mp4"
        )
        log_info "Downloading [${mode}] -> Format: ${fmt} -> Output: ${namer}"
    fi

    # Execute yt-dlp with anti-403 retry mechanism
    if yt-dlp "${ytdl_args[@]}" "$url"; then
        log_success "Download completed successfully."
        return 0
    fi

    local first_status=$?
    log_warn "Primary download attempt encountered an error (exit code ${first_status})."
    log_info "Retrying with anti-throttling / alternative player clients..."

    # Fallback attempt with Android/Web player client and resilient format
    local -a fallback_args=("${ytdl_args[@]}")
    fallback_args+=(
        "--extractor-args" "youtube:player_client=android,web"
        "--retry-sleep" "fragment:exp=1:10"
        "--fragment-retries" "10"
    )

    if yt-dlp "${fallback_args[@]}" "$url"; then
        log_success "Download completed successfully with fallback player client."
        return 0
    fi

    local final_status=$?
    log_error "yt-dlp download failed with error code ${final_status}."
    printf '\n%sRecommended Fixes for YouTube HTTP 403 / Throttling:%s\n' "${CLR_BOLD}" "${CLR_RESET}" >&2
    printf '  1. %sPass browser cookies%s:       %s%s video "%s" --cookies chrome%s\n' \
        "${CLR_CYAN}" "${CLR_RESET}" "${CLR_BOLD}" "$SCRIPT_NAME" "$url" "${CLR_RESET}" >&2
    printf '  2. %sChoose a specific format%s:   %s%s video "%s" -q%s (e.g. choose format 137+140)\n' \
        "${CLR_CYAN}" "${CLR_RESET}" "${CLR_BOLD}" "$SCRIPT_NAME" "$url" "${CLR_RESET}" >&2
    printf '  3. %sUpdate yt-dlp to latest%s:     %syt-dlp -U%s (or via your system package manager)\n\n' \
        "${CLR_CYAN}" "${CLR_RESET}" "${CLR_BOLD}" "${CLR_RESET}" >&2

    exit "$final_status"
}

main "$@"
