#!/usr/bin/env bash

set -euo pipefail

################################################################################
# Configuration
################################################################################

APP_NAME="rofi-tmux"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rofi-tmux"
PROJECT_DB="${DATA_DIR}/database.json"
BACKUP_DIR="${DATA_DIR}/backups"

ALACRITTY_CLASS_PREFIX="tmux"

RUNTIME_DB="${XDG_RUNTIME_DIR:-/tmp}/rofi-tmux-apps.json"

DEPENDENCIES=(
    jq
    tmux
    rofi
    uuidgen
    alacritty
    systemd-run
    systemctl
    notify-send
)

################################################################################
# Help Text
################################################################################

readonly BOLD=$'\e[1m'
readonly BLUE=$'\e[34m'
readonly GREEN=$'\e[32m'
readonly CYAN=$'\e[36m'
readonly YELLOW=$'\e[33m'
readonly RED=$'\e[31m'
readonly RESET=$'\e[0m'

readonly HELP_TEXT="
${BLUE}${BOLD}rofi-tmux${RESET}
Project and Template Based tmux Manager

${CYAN}${BOLD}USAGE${RESET}

rofi-tmux <command>

${GREEN}${BOLD}PROJECT COMMANDS${RESET}

add
    Add the current directory as a project.

    Stores:
        • Path
        • Optional flake
        • Prefix commands

edit
    Edit existing projects/templates.

delete
    Remove projects/templates
    from the database.

cleanup
    Remove projects whose
    directories no longer exist.

list
    Print all projects/templates.

${GREEN}${BOLD}TEMPLATE COMMANDS${RESET}

add-template
    Create a reusable tmux layout.

    Stores:
        • Name
        • Path
        • Optional flake
        • Prefix commands
        • Window commands

${GREEN}${BOLD}SESSION COMMANDS${RESET}

session
    Create, attach, or switch
    tmux sessions.

    Single selection:
        • Creates session if needed
        • Attaches/switches

    Multi selection:
        • Creates all missing sessions
        • Opens a terminal per session

kill
    Kill selected tmux sessions.

kill-all
    Kill every active tmux session.

${GREEN}${BOLD}WINDOW COMMANDS${RESET}

window-here
    Create a new window in the
    current tmux session.

    Uses:
        • Project root path
        • Flake environment
        • Prefix commands

${GREEN}${BOLD}BACKUP COMMANDS${RESET}

backup [directory]
    Create a timestamped database
    backup.

${GREEN}${BOLD}FLAKE COMMANDS${RESET}

add-flake-path <path> [...]
    Register flake directories for
    automatic shell discovery.

cache-flakes
    Refresh cached devShell list.

list-flakes
    Show cached flakes.

${GREEN}${BOLD}HELP${RESET}

help
-h
--help

${CYAN}${BOLD}WORKFLOW EXAMPLES${RESET}

Project:

    cd ~/project
    rofi-tmux add
    rofi-tmux session

Template:

    cd ~/project
    rofi-tmux add-template
    rofi-tmux session

${CYAN}${BOLD}TEMPLATE WINDOWS${RESET}

Window commands create tmux windows.

Examples:

    [\"nvim\"]
        One window running nvim

    [\"nvim\", \"btop\"]
        Two windows

    [\"\"]
        One empty shell window

    [\"nvim\", \"\"]
        One nvim window
        One empty shell window

Rules:

    • At least one window entry
      is required

    • Empty strings are allowed

    • Whitespace-only strings are
      treated as empty windows

${CYAN}${BOLD}PREFIX COMMANDS${RESET}

Prefix commands run before
window commands.

Example:

    prefix:
        [\"cd backend\"]

    window:
        \"nvim\"

Result:

    cd backend && nvim

${CYAN}${BOLD}DATABASE${RESET}

${YELLOW}${PROJECT_DB}${RESET}

${CYAN}${BOLD}BACKUPS${RESET}

${YELLOW}${BACKUP_DIR}${RESET}

${CYAN}${BOLD}NOTES${RESET}

[P] = Project
[T] = Template

Session names are generated
automatically and remain unique.

Editing a project's path or a
template's name/path may create
a new session identifier.

${RED}${BOLD}WARNING${RESET}

delete
    Removes database entries.

cleanup
    Removes missing projects and
    may kill matching tmux sessions.

kill-all
    Kills every active tmux session.

"

################################################################################
# Dependency Checks
################################################################################

ensure_dependencies() {
    local missing=()

    for dep in "${DEPENDENCIES[@]}"; do
        if ! command -v "$dep" >/dev/null 2>&1; then
            missing+=("$dep")
        fi
    done

    if ((${#missing[@]} > 0)); then

        local msg="Missing dependencies:

$(printf '%s\n' "${missing[@]}")"

        notify-send \
            -u critical \
            "$APP_NAME" \
            "$msg"

        printf '%s\n' "$msg" >&2
        exit 1
    fi
}

################################################################################
# Filesystem Setup
################################################################################

ensure_data_dir() {
    mkdir -p "$DATA_DIR"
}

ensure_database() {
    ensure_data_dir

    if [[ ! -f "$PROJECT_DB" ]]; then
        cat >"$PROJECT_DB" <<'EOF'
{
  "flakes": {
     "paths": [],
     "cache": []
   },
  "projects": [],
  "templates": []
}
EOF
    fi
}

ensure_runtime_db() {
    local dir
    dir="$(dirname "$RUNTIME_DB")"

    mkdir -p "$dir"

    if [[ ! -f "$RUNTIME_DB" ]]; then
        printf '{}\n' >"$RUNTIME_DB"
    fi
}

################################################################################
# Utility
################################################################################

show_help() {
    printf '%b\n' "$HELP_TEXT" | less -FRX -R
}

normalize_entries() {

    local line
    local name
    local type
    local session
    local path

    entry_types=()
    entry_sessions=()
    entry_names=()
    entry_paths=()

    for line in "${entries[@]}"; do

        IFS='|' read -r \
            name \
            type \
            session \
            path <<<"$line"

        #
        # Trim leading/trailing whitespace.
        #
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"

        type="${type#"${type%%[![:space:]]*}"}"
        type="${type%"${type##*[![:space:]]}"}"

        session="${session#"${session%%[![:space:]]*}"}"
        session="${session%"${session##*[![:space:]]}"}"

        path="${path#"${path%%[![:space:]]*}"}"
        path="${path%"${path##*[![:space:]]}"}"

        [[ -n "$type" ]] || continue
        [[ -n "$session" ]] || continue

        entry_names+=("$name")
        entry_types+=("$type")
        entry_sessions+=("$session")
        entry_paths+=("$path")

    done
}

cleanup_missing_paths() {

    local missing_sessions=()

    while IFS= read -r project; do

        local path
        local session

        path="$(jq -r '.path' <<<"$project")"
        session="$(jq -r '.session' <<<"$project")"

        [[ -d "$path" ]] && continue

        missing_sessions+=("$session")

    done < <(
        db_get_projects
    )

    if ((${#missing_sessions[@]} == 0)); then
        notify_low "No missing projects found"
        return 0
    fi

    if ! rofi_confirm \
        "Remove ${#missing_sessions[@]} missing project(s) ?"; then
        return 0
    fi

    db_backup || true

    #
    # Kill any active tmux sessions first.
    #
    for session in "${missing_sessions[@]}"; do

        kill_session_applications "$session"

        if tmux_session_exists "$session"; then

            tmux kill-session \
                -t "$session" \
                2>/dev/null || true

            notify_low \
                "Killed session: $session"
        fi

    done

    local sessions_json

    sessions_json="$(
        printf '%s\n' "${missing_sessions[@]}" |
            jq -R . |
            jq -s .
    )"

    local tmp
    tmp="$(mktemp)"

    jq \
        --argjson sessions "$sessions_json" \
        '
        .projects |= map(
            select(
                (.session as $s | $sessions | index($s)) | not
            )
        )
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"

    notify_info \
        "Removed ${#missing_sessions[@]} missing project(s)"
}

################################################################################
# Notifications
################################################################################

notify_info() {
    notify-send \
        -u normal \
        "$APP_NAME" \
        "$1"
}

notify_low() {
    notify-send \
        -u low \
        "$APP_NAME" \
        "$1"
}

notify_error() {
    notify-send \
        -u critical \
        -t 30000 \
        "$APP_NAME" \
        "$1"
}

################################################################################
# JSON Database Functions
################################################################################

db_backup() {
    create_backup "$PROJECT_DB"
}

db_get_projects() {
    jq -c '.projects[]' "$PROJECT_DB"
}

db_get_templates() {
    jq -c '.templates[]' "$PROJECT_DB"
}

db_get_flake_paths() {

    jq -r '
        .flakes.paths[]
    ' "$PROJECT_DB"
}

db_get_cached_flakes() {

    jq -r '
        .flakes.cache[]
    ' "$PROJECT_DB"
}

db_add_flake_cache_entry() {

    local flake="$1"

    local tmp
    tmp="$(mktemp)"

    jq \
        --arg flake "$flake" '
        .flakes.cache += [$flake]
        | .flakes.cache |= unique
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

db_clear_flake_cache() {

    local tmp
    tmp="$(mktemp)"

    jq '
        .flakes.cache = []
    ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

cache_flakes() {

    db_clear_flake_cache

    local path
    local system

    system="$(nix eval --impure --raw --expr builtins.currentSystem)"

    while IFS= read -r path; do

        [[ -d "$path" ]] || continue

        while IFS= read -r flake; do

            [[ -n "$flake" ]] || continue

            db_add_flake_cache_entry \
                "${path}#${flake}"

        done < <(

            nix flake show "$path" --json 2>/dev/null |
                jq -r \
                    --arg system "$system" '
                .devShells[$system]
                | keys[]
                '
        )

    done < <(
        db_get_flake_paths
    )
}

db_project_exists() {
    local path="$1"

    jq -e \
        --arg path "$path" \
        '.projects[] | select(.path == $path)' \
        "$PROJECT_DB" >/dev/null
}

db_add_template() {

    local template_file="$1"

    local tmp
    tmp="$(mktemp)"

    jq \
        --slurpfile tpl "$template_file" \
        '
        .templates += $tpl
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

db_remove_template_by_session() {
    local session="$1"

    local tmp
    tmp="$(mktemp)"

    jq \
        --arg session "$session" \
        '
        .templates |= map(
            select(.session != $session)
        )
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

db_get_template_windows() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | .windows[]
        ' \
        "$PROJECT_DB"
}

db_get_template_path() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | .path
        ' \
        "$PROJECT_DB"
}

session_exists_in_database() {

    local session="$1"

    jq -e \
        --arg session "$session" \
        '
        .projects[]
        | select(.session == $session)
        ' \
        "$PROJECT_DB" >/dev/null 2>&1 && return 0

    jq -e \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        ' \
        "$PROJECT_DB" >/dev/null 2>&1
}

db_add_project() {
    local name="$1"
    local path="$2"
    local flake="$3"
    local prefix="$4"
    local applications="$5"
    local session="$6"

    local tmp
    tmp=$(mktemp)

    jq \
        --arg name "$name" \
        --arg path "$path" \
        --arg flake "$flake" \
        --argjson prefix "$prefix" \
        --argjson applications "$applications" \
        --arg session "$session" \
        '
        .projects += [{
            "name": $name,
            "path": $path,
            "flake": $flake,
            "prefix": $prefix,
            "applications": $applications,
            "session": $session
        }]
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

db_get_project_applications_json() {
    local session="$1"

    jq -c \
        --arg session "$session" \
        '
        .projects[]
        | select(.session == $session)
        | (.applications // [])
        ' \
        "$PROJECT_DB"
}

db_get_template_applications_json() {
    local session="$1"

    jq -c \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | (.applications // [])
        ' \
        "$PROJECT_DB"
}

db_remove_project_by_session() {
    local session="$1"

    local tmp
    tmp=$(mktemp)

    jq \
        --arg session "$session" \
        '
        .projects |= map(select(.session != $session))
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
}

db_get_path_from_session() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .projects[]
        | select(.session == $session)
        | .path
        ' \
        "$PROJECT_DB"
}

db_get_project_flake() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .projects[]
        | select(.session == $session)
        | .flake
        ' \
        "$PROJECT_DB"
}

db_get_project_prefix() {
    local session="$1"

    jq -c \
        --arg session "$session" \
        '
        .projects[]
        | select(.session == $session)
        | .prefix
        ' \
        "$PROJECT_DB"
}

db_get_template_flake() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | .flake
        ' \
        "$PROJECT_DB"
}

db_get_template_prefix() {
    local session="$1"

    jq -c \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | .prefix
        ' \
        "$PROJECT_DB"
}

sanitize_unit_component() {
    local s="$1"

    s="${s##*/}" # strip path
    s="${s%% *}" # first token only
    s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]')"
    s="$(printf '%s' "$s" | sed -E 's/[^a-z0-9_.-]+/-/g; s/^-+//; s/-+$//')"

    [[ -n "$s" ]] || s="app"

    printf '%s\n' "$s"
}

db_set_session_app_units() {
    local session="$1"
    local units_json="$2"

    ensure_runtime_db

    local tmp
    tmp="$(mktemp)"

    jq \
        --arg session "$session" \
        --argjson units "$units_json" \
        '
        .[$session] = $units
        ' \
        "$RUNTIME_DB" >"$tmp"

    mv "$tmp" "$RUNTIME_DB"
}

db_get_session_app_units() {
    local session="$1"

    ensure_runtime_db

    jq -r \
        --arg session "$session" \
        '
        .[$session][]?.unit
        ' \
        "$RUNTIME_DB"
}

db_remove_session_app_units() {
    local session="$1"

    ensure_runtime_db

    local tmp
    tmp="$(mktemp)"

    jq \
        --arg session "$session" \
        'del(.[$session])' \
        "$RUNTIME_DB" >"$tmp"

    mv "$tmp" "$RUNTIME_DB"
}

db_list_runtime_sessions() {
    ensure_runtime_db
    jq -r 'keys[]' "$RUNTIME_DB"
}

################################################################################
# Session Helpers
################################################################################

generate_session_name() {

    local path="$1"

    local name

    name="$(
        basename "$path" |
            tr '[:upper:]' '[:lower:]' |
            sed -E 's/[^a-zA-Z0-9]+/-/g; s/^-+//; s/-+$//'
    )"

    while :; do

        local uuid
        local session

        uuid="$(
            uuidgen |
                tr '[:upper:]' '[:lower:]' |
                tr -d '-' |
                cut -c1-6
        )"

        session="${name}-${uuid}"

        if ! session_exists_in_database "$session"; then

            printf '%s\n' "$session"
            return 0

        fi

    done
}

tmux_session_exists() {
    local session="$1"

    tmux has-session -t "$session" \
        >/dev/null 2>&1
}

build_window_command() {

    local command="$1"
    shift

    local prefix_cmds=("$@")

    local full_cmd=""

    if ((${#prefix_cmds[@]})); then
        full_cmd="$(printf '%s && ' "${prefix_cmds[@]}")"
        full_cmd="${full_cmd% && }"
    fi

    if [[ -n "$command" ]]; then

        [[ -n "$full_cmd" ]] &&
            full_cmd+=" && "

        full_cmd+="$command"
    fi

    printf '%s\n' "$full_cmd"
}

window_name_from_command() {
    local cmd="$1"
    local last
    local first

    #
    # Empty / whitespace-only command -> shell
    #
    if [[ -z "${cmd//[[:space:]]/}" ]]; then
        printf '%s\n' "shell"
        return 0
    fi

    #
    # Split on &&, ||, ;
    #
    last="$cmd"

    while [[ "$last" =~ (.*)(&&|\|\||;)(.*) ]]; do
        last="${BASH_REMATCH[3]}"
    done

    #
    # Trim whitespace.
    #
    last="${last#"${last%%[![:space:]]*}"}"
    last="${last%"${last##*[![:space:]]}"}"

    [[ -n "$last" ]] || {
        printf '%s\n' "shell"
        return 0
    }

    #
    # First word of last command segment.
    #
    first="${last%%[[:space:]]*}"

    #
    # Strip path if present.
    #
    first="${first##*/}"

    [[ -n "$first" ]] || first="shell"

    printf '%s\n' "$first"
}

launch_app_scope() {
    local session="$1"
    local path="$2"
    local app="$3"
    local index="$4"

    local app_id
    local unit

    app_id="$(sanitize_unit_component "$app")"
    unit="rofi-tmux-${session}-${app_id}-${index}.scope"

    #
    # Remove any stale old unit with the same name.
    # Ignore failures.
    #
    systemctl --user stop "$unit" >/dev/null 2>&1 || true
    systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true

    #
    # Launch the application inside its own transient user scope.
    #

    systemd-run \
        --user \
        --scope \
        --quiet \
        --no-block \
        --unit="$unit" \
        bash -lc "cd $(printf '%q' "$path") && exec $app" \
        </dev/null >/dev/null 2>&1 &

    printf '%s\n' "$unit"
}

launch_session_applications() {
    local session="$1"
    local path="$2"
    local applications_json="$3"

    local applications=()
    local entries=()
    local app
    local unit
    local index=0

    mapfile -t applications < <(
        jq -r '.[]' <<<"$applications_json"
    )

    ((${#applications[@]} == 0)) && {
        db_remove_session_app_units "$session"
        return 0
    }

    for app in "${applications[@]}"; do
        [[ -n "${app//[[:space:]]/}" ]] || continue

        if unit="$(launch_app_scope "$session" "$path" "$app" "$index")"; then
            entries+=(
                "$(jq -nc \
                    --arg app "$app" \
                    --arg unit "$unit" \
                    '{app:$app, unit:$unit}')"
            )
        else
            notify_error "Failed to launch application in scope: $app"
        fi

        ((++index))
    done

    if ((${#entries[@]} == 0)); then
        db_remove_session_app_units "$session"
        return 0
    fi

    local units_json
    units_json="$(
        printf '%s\n' "${entries[@]}" | jq -s .
    )"

    local app_names
    app_names="$(
        printf '%s\n' "${entries[@]}" |
            jq -r '.app' |
            tr '\n' '\n'
    )"

    notify_low "Launched ${#entries[@]} application(s):
$app_names"

    db_set_session_app_units "$session" "$units_json"
}

kill_session_applications() {
    local session="$1"
    local unit
    local units=()
    local app_names=""
    app_names="$(
        ensure_runtime_db
        jq -r \
            --arg session "$session" \
            '.[$session][]? | .app' \
            "$RUNTIME_DB" |
            paste -sd '\n'
    )"
    while IFS= read -r unit; do
        [[ -n "$unit" ]] || continue
        units+=("$unit")
        systemctl --user stop "$unit" >/dev/null 2>&1 || true
        systemctl --user reset-failed "$unit" >/dev/null 2>&1 || true
    done < <(
        db_get_session_app_units "$session"
    )
    db_remove_session_app_units "$session"
    ((${#units[@]} == 0)) && return 0

    notify_low "Killed ${#units[@]} application(s):
$app_names"
}

create_session() {

    local session="$1"
    local path="$2"
    local flake="$3"
    local prefix_json="$4"
    local applications_json="$5"

    shift 5

    local window_commands=("$@")

    local prefix_cmds=()

    mapfile -t prefix_cmds < <(
        jq -r '.[]' <<<"$prefix_json"
    )

    tmux new-session \
        -d \
        -s "$session" \
        -c "$path"

    tmux set-option \
        -t "$session" \
        @header "$path"

    local window_id
    local cmd

    #
    # PROJECT
    #
    if ((${#window_commands[@]} == 0)); then

        #
        # tw0
        #
        window_id="$(
            tmux list-windows \
                -t "$session" \
                -F '#{window_id}' |
                head -n1
        )"

        cmd="$(
            build_window_command \
                "" \
                "${prefix_cmds[@]}"
        )"

        if [[ -n "$flake" ]]; then

            tmux send-keys \
                -t "$window_id" \
                "export ROFI_TMUX_CMD=$(printf '%q' "$cmd")
nix develop '$flake' -c zsh" \
                C-m

        else

            [[ -n "$cmd" ]] &&
                tmux send-keys \
                    -t "$window_id" \
                    "$cmd" \
                    C-m

        fi

        #
        # tw1
        #
        window_id="$(
            tmux new-window \
                -d \
                -P \
                -F '#{window_id}' \
                -t "$session" \
                -c "$path"
        )"

        if [[ -n "$flake" ]]; then

            tmux send-keys \
                -t "$window_id" \
                "export ROFI_TMUX_CMD=$(printf '%q' "$cmd")
nix develop '$flake' -c zsh" \
                C-m

        else

            [[ -n "$cmd" ]] &&
                tmux send-keys \
                    -t "$window_id" \
                    "$cmd" \
                    C-m

        fi

    #
    # TEMPLATE
    #
    else

        local index=0
        local window_cmd
        local window_name

        for window_cmd in "${window_commands[@]}"; do

            window_name="$(
                window_name_from_command "$window_cmd"
            )"

            if ((index == 0)); then

                window_id="$(
                    tmux list-windows \
                        -t "$session" \
                        -F '#{window_id}' |
                        head -n1
                )"

                tmux rename-window \
                    -t "$window_id" \
                    "$window_name"

            else

                window_id="$(
                    tmux new-window \
                        -d \
                        -P \
                        -F '#{window_id}' \
                        -t "$session" \
                        -n "$window_name" \
                        -c "$path"
                )"

            fi

            cmd="$(
                build_window_command \
                    "$window_cmd" \
                    "${prefix_cmds[@]}"
            )"

            if [[ -n "$flake" ]]; then

                tmux send-keys \
                    -t "$window_id" \
                    "export ROFI_TMUX_CMD=$(printf '%q' "$cmd")
nix develop '$flake' -c zsh" \
                    C-m

            else

                [[ -n "$cmd" ]] &&
                    tmux send-keys \
                        -t "$window_id" \
                        "$cmd" \
                        C-m

            fi

            ((++index))

        done

    fi

    launch_session_applications \
        "$session" \
        "$path" \
        "$applications_json"

    notify_low \
        "Created session: $session"
}

################################################################################
# Active Session Index Builder
################################################################################

build_active_indices() {

    local active_sessions=()

    while IFS= read -r session; do

        active_sessions+=("$session")

    done < <(
        tmux list-sessions \
            -F '#S' \
            2>/dev/null || true
    )

    local indices=()
    local index=0

    while IFS= read -r session; do

        local active

        for active in "${active_sessions[@]}"; do

            if [[ "$active" == "$session" ]]; then

                indices+=("$index")
                break

            fi

        done

        ((++index))

    done < <(
        {
            db_get_projects |
                jq -r '.session'

            db_get_templates |
                jq -r '.session'
        }
    )

    (
        IFS=,
        printf '%s' "${indices[*]}"
    )
}

################################################################################
# Rofi Helpers
################################################################################

rofi_confirm() {

    local prompt="$1"

    local result

    result="$(
        printf "Proceed\nCancel\n" |
            rofi -dmenu -p "$prompt"
    )"

    [[ "$result" == "Proceed" ]]
}

rofi_pro_temp_selector() {

    local prompt="$1"

    local active_indices

    active_indices="$(build_active_indices)"

    {
        db_get_projects |
            jq -r '
            [
                .name,
                "[P]",
                .session,
                .path
            ] | join(" | ")
            '

        db_get_templates |
            jq -r '
            [
                .name,
                "[T]",
                .session,
                .path
            ] | join(" | ")
            '
    } |
        rofi \
            -dmenu \
            -i \
            -multi-select \
            -a "$active_indices" \
            -ballot-selected-str "● " \
            -ballot-unselected-str "○ " \
            -p "$prompt"
}

################################################################################
# Attach / Switch Helpers
################################################################################

attach_or_switch_session() {

    local session="$1"

    if [[ -n "${TMUX:-}" ]]; then

        tmux switch-client -t "$session"

    else

        alacritty \
            --class "${ALACRITTY_CLASS_PREFIX}-${session}" \
            -e tmux attach-session -t "$session" &
    fi
}

spawn_session_terminal() {

    local session="$1"

    alacritty \
        --class "${ALACRITTY_CLASS_PREFIX}-${session}" \
        -e tmux attach-session -t "$session" &
}

################################################################################
# ADD
################################################################################
validate_commands() {

    local file="$1"

    local cmd
    local flake

    #
    # Validate flake.
    #
    flake="$(
        jq -r '.flake // ""' "$file"
    )"

    if [[ -n "$flake" ]]; then

        if ! db_get_cached_flakes |
            grep -Fxq -- "$flake"; then

            notify_error \
                "Invalid flake: $flake"

            return 1

        fi

    fi

    #
    # Validate prefix commands.
    #
    while IFS= read -r cmd; do

        [[ -n "$cmd" ]] || {

            notify_error \
                "Empty prefix command"

            return 1
        }

        if ! command -v "${cmd%% *}" >/dev/null 2>&1; then

            notify_error \
                "Invalid prefix command: $cmd"

            return 1

        fi

    done < <(
        jq -r '
            .prefix[]?
        ' "$file"
    )

    #
    # Validate window commands.
    #
    while IFS= read -r cmd; do

        #
        # Skip empty/whitespace-only entries.
        #
        if [[ -z "${cmd//[[:space:]]/}" ]]; then
            continue
        fi

        if ! command -v "${cmd%% *}" >/dev/null 2>&1; then

            notify_error \
                "Invalid window command: $cmd"

            return 1

        fi

    done < <(
        jq -r '
        .windows[]?
    ' "$file"
    )

    #
    # Validate application commands.
    #

    while IFS= read -r cmd; do

        if [[ -z "${cmd//[[:space:]]/}" ]]; then
            continue
        fi

        if ! command -v "${cmd%% *}" >/dev/null 2>&1; then

            notify_error \
                "Invalid application command: $cmd"

            return 1
        fi

    done < <(
        jq -r '
        .applications[]?
    ' "$file"
    )

    return 0
}

validate_path() {

    local path="$1"

    [[ -d "$path" ]] && return 0

    local action

    action="$(
        printf "Edit Again\nCreate Path\nCancel\n" |
            rofi \
                -dmenu \
                -p "Path Does Not Exist" ||
            true
    )"

    case "$action" in

    "Edit Again")
        return 2
        ;;

    "Create Path")

        mkdir -p -- "$path" || {

            notify_error \
                "Failed to create path"

            return 1
        }

        return 0
        ;;

    *)

        return 1
        ;;

    esac
}

cmd_add_entry() {

    local type="$1" # project | template

    local path
    local name
    local session
    local tmp
    local merged

    path="$(pwd -L)"

    #
    # Duplicate project check.
    #
    if [[ "$type" == "project" ]]; then

        if db_project_exists "$path"; then

            notify_error \
                "Project already exists"

            return 1
        fi

    fi

    tmp="$(mktemp)"

    #
    # Initial config.
    #
    local flakes

    flakes="$(
        db_get_cached_flakes |
            awk '
            NR == 1 { printf "%s", $0; next }
            { printf " | %s", $0 }
        '
    )"

    if [[ "$type" == "project" ]]; then

        cat >"$tmp" <<EOF
{
    "path": "$path",
    "flake": "$flakes",
    "prefix": [],
    "applications": []
}
EOF

    else

        cat >"$tmp" <<EOF
{
    "name": "",
    "path": "$path",
    "flake": "$flakes",
    "prefix": [],
    "windows": [
        "nvim",
        "btop"
    ],
    "applications": []
}
EOF

    fi
    while :; do

        alacritty \
            --class "${APP_NAME}-editor" \
            -e nvim "$tmp"

        #
        # JSON validation.
        #
        if ! jq empty "$tmp" >/dev/null 2>&1; then

            local action

            action="$(
                printf "Edit Again\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Invalid JSON"
            )"

            [[ "$action" == "Edit Again" ]] && continue

            rm -f "$tmp"
            return 0

        fi

        #
        # Project validation.
        #
        if [[ "$type" == "project" ]]; then

            if ! jq -e '
                (.path | type == "string")
                and
                (.path | test("\\S"))

                and

                (.flake | type == "string")

                and

                (.prefix | type == "array")

                and

                (
                    all(
                        .prefix[];
                        type == "string"
                    )
                )

                and

                (.applications | type == "array")

                and

                (
                    all(
                        .applications[];
                        type == "string" and test("\\S")
                    )
                )
            ' "$tmp" >/dev/null 2>&1; then

                local action

                action="$(
                    printf "Edit Again\nCancel\n" |
                        rofi \
                            -dmenu \
                            -p "Invalid Project"
                )"

                [[ "$action" == "Edit Again" ]] && continue

                rm -f "$tmp"
                return 0

            fi

        #
        # Template validation.
        #
        else

            if ! jq -e '
                (.name | type == "string")
                and
                (.name | test("\\S"))
                and
                (
                    (.name | test("^\\*+$"))
                    | not
                )

                and

                (.path | type == "string")
                and
                (.path | test("\\S"))

                and

                (.flake | type == "string")

                and

                (.prefix | type == "array")

                and

                (
                    all(
                        .prefix[];
                        type == "string"
                    )
                )

                and

                (.windows | type == "array")

                and

                (.windows | length > 0)

                and

                (
                    all(
                        .windows[];
                        type == "string"
                    )
                )

                and

                (.applications | type == "array")

                and

                (
                    all(
                        .applications[];
                        type == "string" and test("\\S")
                    )
                )
            ' "$tmp" >/dev/null 2>&1; then

                local action

                action="$(
                    printf "Edit Again\nCancel\n" |
                        rofi \
                            -dmenu \
                            -p "Invalid Template"
                )"

                [[ "$action" == "Edit Again" ]] && continue

                rm -f "$tmp"
                return 0

            fi

        fi
        if ! validate_commands "$tmp"; then

            local action

            action="$(
                printf "Edit Again\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Invalid Commands"
            )"

            [[ "$action" == "Edit Again" ]] && continue

            rm -f "$tmp"
            return 0

        fi

        path="$(jq -r '.path' "$tmp")"

        validate_path "$path"

        case $? in

        0)
            break
            ;;

        2)
            continue
            ;;

        *)

            rm -f "$tmp"
            return 0
            ;;

        esac
        break

    done

    #
    # Save project.
    #
    if [[ "$type" == "project" ]]; then

        path="$(jq -r '.path' "$tmp")"

        if db_project_exists "$path"; then

            notify_error \
                "Project already exists"

            rm -f "$tmp"
            return 1

        fi

        local flake
        local prefix
        local applications

        flake="$(jq -r '.flake' "$tmp")"
        prefix="$(jq -c '.prefix' "$tmp")"
        applications="$(jq -c '.applications' "$tmp")"

        session="$(
            generate_session_name "$path"
        )"

        name="$(basename "$path")"

        db_add_project \
            "$name" \
            "$path" \
            "$flake" \
            "$prefix" \
            "$applications" \
            "$session"

        rm -f "$tmp"

        notify_info \
            "Added project: $session"

        return 0

    fi

    #
    # Save template.
    #
    name="$(jq -r '.name' "$tmp")"
    path="$(jq -r '.path' "$tmp")"
    session="$(
        generate_template_session_name \
            "$path" \
            "$name"
    )"

    merged="$(mktemp)"

    jq \
        --arg path "$path" \
        --arg session "$session" \
        '
        . + {
            path: $path,
            session: $session
        }
        ' \
        "$tmp" >"$merged"

    db_add_template "$merged"

    rm -f \
        "$tmp" \
        "$merged"

    notify_info \
        "Added template: $name"
}

################################################################################
# SESSION
################################################################################
create_entry_session() {
    local session="$1"
    local type="$2"
    local path flake prefix applications_json
    local windows=()

    if [[ "$type" == "[T]" ]]; then
        path="$(db_get_template_path "$session")"
        flake="$(db_get_template_flake "$session")"
        prefix="$(db_get_template_prefix "$session")"
        applications_json="$(db_get_template_applications_json "$session")"
        mapfile -t windows < <(db_get_template_windows "$session")
    else
        path="$(db_get_path_from_session "$session")"
        flake="$(db_get_project_flake "$session")"
        prefix="$(db_get_project_prefix "$session")"
        applications_json="$(db_get_project_applications_json "$session")"
        [[ -n "$path" ]] || return 1
    fi

    tmux_session_exists "$session" && return 0

    create_session \
        "$session" \
        "$path" \
        "$flake" \
        "$prefix" \
        "$applications_json" \
        "${windows[@]+"${windows[@]}"}"
}

cmd_session() {
    local selections
    selections="$(rofi_pro_temp_selector "Tmux-Session:")"
    [[ -n "$selections" ]] || return 0
    mapfile -t entries <<<"$selections"
    normalize_entries

    if [[ ${#entry_sessions[@]} -eq 1 ]]; then
        local session="${entry_sessions[0]}"
        local type="${entry_types[0]}"
        create_entry_session "$session" "$type" || return 1
        attach_or_switch_session "$session"
        return 0
    fi

    rofi_confirm "Create Sessions ?" || return 0

    local created=0
    local i
    for i in "${!entry_sessions[@]}"; do
        local session="${entry_sessions[$i]}"
        local type="${entry_types[$i]}"
        if tmux_session_exists "$session"; then
            notify_low "Ignored existing session: $session"
            continue
        fi
        create_entry_session "$session" "$type" || continue
        spawn_session_terminal "$session"
        ((++created))
    done
    notify_info "Created $created session(s)"
}

################################################################################
# WINDOW HERE
################################################################################

cmd_window_here() {

    [[ -n "${TMUX:-}" ]] || {
        notify_error "Not running inside tmux"
        return 1
    }

    local session
    session="$(tmux display-message -p '#S')" || {
        notify_error "Failed to determine tmux session"
        return 1
    }

    local path=""
    local flake=""
    local prefix_json='[]'

    #
    # Path from session metadata.
    #
    path="$(
        tmux show-option \
            -t "$session" \
            -qv @header \
            2>/dev/null || true
    )"

    #
    # Fallback to current pane path.
    #
    if [[ -z "$path" ]]; then

        path="$(
            tmux display-message \
                -p '#{pane_current_path}' \
                2>/dev/null || true
        )"

    fi

    [[ -n "$path" ]] || {
        notify_error "Unable to determine session path"
        return 1
    }

    #
    # Project lookup.
    #
    flake="$(
        db_get_project_flake "$session" \
            2>/dev/null || true
    )"

    prefix_json="$(
        db_get_project_prefix "$session" \
            2>/dev/null || true
    )"

    #
    # Template fallback.
    #
    if [[ -z "$flake" ]] ||
        [[ "$flake" == "null" ]]; then

        flake="$(
            db_get_template_flake "$session" \
                2>/dev/null || true
        )"

    fi

    if [[ -z "$prefix_json" ]] ||
        [[ "$prefix_json" == "null" ]]; then

        prefix_json="$(
            db_get_template_prefix "$session" \
                2>/dev/null || true
        )"

    fi

    #
    # Normalize values.
    #
    [[ "$flake" == "null" ]] &&
        flake=""

    [[ -n "$prefix_json" ]] &&
        jq empty <<<"$prefix_json" >/dev/null 2>&1 ||
        prefix_json='[]'

    local prefix_cmds=()

    mapfile -t prefix_cmds < <(
        jq -r '.[]' <<<"$prefix_json" \
            2>/dev/null || true
    )

    local window_id

    window_id="$(
        tmux new-window \
            -P \
            -F '#{window_id}' \
            -c "$path" \
            2>/dev/null
    )" || {
        notify_error "Failed to create tmux window"
        return 1
    }

    local cmd

    cmd="$(
        build_window_command \
            "" \
            "${prefix_cmds[@]}"
    )"

    #
    # Flake session.
    #
    if [[ -n "$flake" ]]; then

        tmux send-keys \
            -t "$window_id" \
            "export ROFI_TMUX_CMD=$(printf '%q' "$cmd")
nix develop '$flake' -c zsh" \
            C-m || {

            notify_error "Failed to initialize flake shell"
            return 1
        }

    #
    # Normal session.
    #
    elif [[ -n "$cmd" ]]; then

        tmux send-keys \
            -t "$window_id" \
            "$cmd" \
            C-m || {

            notify_error "Failed to execute prefix commands"
            return 1
        }

    fi

    return 0
}

################################################################################
# TEMPLATE NAME
################################################################################

generate_template_session_name() {

    local path="$1"
    local template="$2"

    local project

    project="$(
        basename "$path" |
            tr '[:upper:]' '[:lower:]' |
            sed -E 's/[^a-zA-Z0-9]+/-/g'
    )"

    template="$(
        printf '%s' "$template" |
            tr '[:upper:]' '[:lower:]' |
            sed -E 's/[^a-zA-Z0-9]+/-/g'
    )"

    while :; do

        local uuid
        local session

        uuid="$(
            uuidgen |
                tr -d '-' |
                tr '[:upper:]' '[:lower:]' |
                cut -c1-6
        )"

        session="${project}-${template}-${uuid}"

        if ! session_exists_in_database "$session"; then

            printf '%s\n' "$session"
            return 0

        fi
    done
}

################################################################################
# EDIT
################################################################################

build_edit_json() {

    local output_file="$1"

    jq -n '
        []
    ' >"$output_file"

    local i

    for i in "${!entry_sessions[@]}"; do

        local session
        local type

        session="${entry_sessions[$i]}"
        type="${entry_types[$i]}"

        local entry

        if [[ "$type" == "[P]" ]]; then

            entry="$(
                jq -c \
                    --arg session "$session" \
                    '
                    .projects[]
                    | select(.session == $session)
                    | {
                        type: "project",
                        _session: .session,
                        _name: .name,
                        path,
                        flake,
                        prefix,
                        applications
                    }
                    ' \
                    "$PROJECT_DB"
            )"

        else

            entry="$(
                jq -c \
                    --arg session "$session" \
                    '
                    .templates[]
                    | select(.session == $session)
                    | {
                        type: "template",
                        _session: .session,
                        name,
                        path,
                        flake,
                        prefix,
                        windows,
                        applications
                    }
                    ' \
                    "$PROJECT_DB"
            )"

        fi

        jq \
            --argjson item "$entry" \
            '. += [$item]' \
            "$output_file" >"${output_file}.tmp"

        mv \
            "${output_file}.tmp" \
            "$output_file"

    done
}

validate_edit_structure() {

    local file="$1"

    jq -e '
        type == "array"
        and

        all(
            .[];

            (
                .type == "project"

                and

                (.path | type == "string")
                and
                (.path | test("\\S"))

                and

                (.flake | type == "string")

                and

                (.prefix | type == "array")

                and

                (
                    all(
                        .prefix[];
                        type == "string"
                    )
                )

                and

                (.applications | type == "array")

                and

                (
                    all(
                        .applications[];
                        type == "string"  and test("\\S")
                    )
                )
            )

            or

            (
                .type == "template"

                and

                (.name | type == "string")
                and
                (.name | test("\\S"))

                and
                (
                    (.name | test("^\\*+$"))
                    | not
                )

                and

                (.path | type == "string")
                and
                (.path | test("\\S"))

                and

                (.flake | type == "string")

                and

                (.prefix | type == "array")

                and

                (
                    all(
                        .prefix[];
                        type == "string"
                    )
                )

                and

                (.windows | type == "array")

                and

                (.windows | length > 0)

                and

                (
                    all(
                        .windows[];
                        type == "string"
                    )
                )

                and

                (.applications | type == "array")

                and

                (
                    all(
                        .applications[];
                        type == "string" and test("\\S")
                    )
                )
            )
        )
    ' "$file" >/dev/null 2>&1
}

validate_edited_commands() {

    local file="$1"

    local template
    local tmp

    while IFS= read -r template; do

        tmp="$(mktemp)"

        printf '%s\n' "$template" >"$tmp"

        if ! validate_commands "$tmp"; then

            rm -f "$tmp"
            return 1

        fi

        rm -f "$tmp"

    done < <(
        jq -c '
            .[]
            | select(
                .type == "template"
                or
                .type == "project"
            )
        ' "$file"
    )

    return 0
}

validate_edit_file() {

    local file="$1"

    jq empty "$file" >/dev/null 2>&1 ||
        return 1

    validate_edit_structure "$file" ||
        return 1

    validate_edited_commands "$file" ||
        return 1
}

apply_edits() {

    local edited_file="$1"
    shift

    local original_sessions=("$@")

    local tmp_db
    tmp_db="$(mktemp)"

    cp "$PROJECT_DB" "$tmp_db"

    local index=0
    local item

    while IFS= read -r item; do

        local type
        local old_session

        type="$(jq -r '.type' <<<"$item")"
        old_session="${original_sessions[$index]}"

        [[ -n "$old_session" ]] || {
            notify_error "Internal error: missing session"
            return 1
        }

        if [[ "$type" == "project" ]]; then

            local old_path

            old_path="$(
                jq -r \
                    --arg session "$old_session" \
                    '
                    .projects[]
                    | select(.session == $session)
                    | .path
                    ' \
                    "$PROJECT_DB"
            )"

            [[ -n "$old_path" ]] || {
                notify_error \
                    "Project no longer exists"
                return 1
            }

            local new_name
            local new_path
            local new_flake
            local new_prefix
            local new_applications
            local new_session

            new_path="$(jq -r '.path' <<<"$item")"
            new_flake="$(jq -r '.flake' <<<"$item")"
            new_prefix="$(jq -c '.prefix' <<<"$item")"
            new_applications="$(jq -c '.applications' <<<"$item")"

            validate_path "$new_path" || return 1

            if [[ "$new_path" != "$old_path" ]]; then

                if jq -e \
                    --arg path "$new_path" \
                    --arg session "$old_session" \
                    '
        .projects[]
        | select(.path == $path)
        | select(.session != $session)
        ' \
                    "$PROJECT_DB" >/dev/null; then

                    notify_error \
                        "Project path already exists"

                    return 1
                fi

            fi

            new_name="$(basename "$new_path")"
            new_session="$old_session"

            if [[ "$new_path" != "$old_path" ]]; then

                new_session="$(
                    generate_session_name "$new_path"
                )"
                kill_session_applications "$old_session"

                if tmux_session_exists "$old_session"; then
                    tmux kill-session \
                        -t "$old_session" \
                        2>/dev/null || true
                fi

            fi

            jq \
                --arg old_session "$old_session" \
                --arg new_name "$new_name" \
                --arg new_path "$new_path" \
                --arg new_flake "$new_flake" \
                --argjson new_prefix "$new_prefix" \
                --argjson new_applications "$new_applications" \
                --arg new_session "$new_session" \
                '
                .projects |= map(
                    if .session == $old_session
                    then
                        .name = $new_name
                        | .path = $new_path
                        | .flake = $new_flake
                        | .prefix = $new_prefix
                        | .applications = $new_applications
                        | .session = $new_session
                    else .
                    end
                )
                ' \
                "$tmp_db" >"${tmp_db}.new"

            mv \
                "${tmp_db}.new" \
                "$tmp_db"

        else

            local old_name
            local old_path

            old_name="$(
                jq -r \
                    --arg session "$old_session" \
                    '
                    .templates[]
                    | select(.session == $session)
                    | .name
                    ' \
                    "$PROJECT_DB"
            )"
            [[ -n "$old_name" ]] || {
                notify_error \
                    "Template no longer exists"
                return 1
            }

            old_path="$(
                jq -r \
                    --arg session "$old_session" \
                    '
                    .templates[]
                    | select(.session == $session)
                    | .path
                    ' \
                    "$PROJECT_DB"
            )"

            [[ -n "$old_path" ]] || {
                notify_error \
                    "Template no longer exists"
                return 1
            }

            local new_name
            local new_path
            local new_flake
            local new_prefix
            local new_windows
            local new_applications
            local new_session

            new_name="$(jq -r '.name' <<<"$item")"
            new_path="$(jq -r '.path' <<<"$item")"
            new_flake="$(jq -r '.flake' <<<"$item")"
            new_prefix="$(jq -c '.prefix' <<<"$item")"
            new_applications="$(jq -c '.applications' <<<"$item")"
            new_windows="$(jq -c '.windows' <<<"$item")"

            validate_path "$new_path" || return 1

            new_session="$old_session"

            if [[ "$new_name" != "$old_name" ]] ||
                [[ "$new_path" != "$old_path" ]]; then

                new_session="$(
                    generate_template_session_name \
                        "$new_path" \
                        "$new_name"
                )"

                kill_session_applications "$old_session"

                if tmux_session_exists "$old_session"; then
                    tmux kill-session \
                        -t "$old_session" \
                        2>/dev/null || true
                fi

            fi

            jq \
                --arg old_session "$old_session" \
                --arg new_name "$new_name" \
                --arg new_path "$new_path" \
                --arg new_flake "$new_flake" \
                --argjson new_prefix "$new_prefix" \
                --arg new_session "$new_session" \
                --argjson new_applications "$new_applications" \
                --argjson new_windows "$new_windows" \
                '
                .templates |= map(
                    if .session == $old_session
                    then
                        .name = $new_name
                        | .path = $new_path
                        | .flake = $new_flake
                        | .prefix = $new_prefix
                        | .windows = $new_windows
                        | .applications = $new_applications
                        | .session = $new_session
                    else .
                    end
                )
                ' \
                "$tmp_db" >"${tmp_db}.new"

            mv \
                "${tmp_db}.new" \
                "$tmp_db"

        fi

        ((++index))

    done < <(
        jq -c '.[]' "$edited_file"
    )

    db_backup || true

    mv \
        "$tmp_db" \
        "$PROJECT_DB"
}

cmd_edit() {

    local selections

    selections="$(
        rofi_pro_temp_selector \
            "Edit-Projects/Templates:"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    local tmp
    tmp="$(mktemp)"

    trap 'rm -f "$tmp"' RETURN

    build_edit_json "$tmp"

    local original_hash
    original_hash="$(
        sha256sum "$tmp" |
            cut -d' ' -f1
    )"

    while :; do

        alacritty \
            --class "${APP_NAME}-editor" \
            -e nvim "$tmp"

        local new_hash

        new_hash="$(
            sha256sum "$tmp" |
                cut -d' ' -f1
        )"

        #
        # Nothing changed.
        #
        if [[ "$original_hash" == "$new_hash" ]]; then

            notify_low \
                "No changes detected"

            return 0

        fi

        if ! validate_edit_file "$tmp"; then

            local action

            action="$(
                printf "Edit Again\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Validation Failed" ||
                    true
            )"

            [[ "$action" == "Edit Again" ]] &&
                continue

            return 0

        fi

        break

    done

    #
    # Pass original sessions so apply_edits()
    # does not trust _session from the edited JSON.
    #
    apply_edits \
        "$tmp" \
        "${entry_sessions[@]}" ||
        return 1

    notify_info \
        "Updated selected entries"
}

################################################################################
# DELETE
################################################################################

cmd_delete() {

    local selections

    selections="$(
        rofi_pro_temp_selector \
            "Delete-Projects/Templates:"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    if ! rofi_confirm \
        "Delete ${#entry_sessions[@]} selected item(s) ?"; then
        return 0
    fi

    db_backup || true

    local deleted=0
    local i

    for i in "${!entry_sessions[@]}"; do

        local session
        local type

        session="${entry_sessions[$i]}"
        type="${entry_types[$i]}"

        local had_tmux=0

        if tmux_session_exists "$session"; then
            had_tmux=1
        fi

        kill_session_applications "$session"

        if ((had_tmux)); then
            tmux kill-session \
                -t "$session" \
                2>/dev/null || true

            notify_low \
                "Killed session: $session"
        fi

        case "$type" in

        "[P]")

            db_remove_project_by_session \
                "$session"

            notify_low \
                "Deleted project: $session"
            ;;

        "[T]")

            db_remove_template_by_session \
                "$session"

            notify_low \
                "Deleted template: $session"
            ;;

        *)

            notify_error \
                "Unknown type: $type"

            continue
            ;;

        esac

        ((++deleted))

    done

    notify_info \
        "Deleted $deleted item(s)"
}

################################################################################
# KILL
################################################################################

cmd_kill() {

    local selections

    selections="$(
        rofi_pro_temp_selector "Kill-Sessions:"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    if ! rofi_confirm "Kill Selected Sessions ?"; then
        return 0
    fi

    local killed=0
    local cleaned_only=0
    local session

    for session in "${entry_sessions[@]}"; do

        local had_tmux=0

        if tmux_session_exists "$session"; then
            had_tmux=1
        fi

        kill_session_applications "$session"

        if ((had_tmux)); then
            tmux kill-session \
                -t "$session" \
                2>/dev/null || true

            notify_low \
                "Killed: $session"

            ((++killed))
        else
            notify_low \
                "Cleaned app state for inactive session: $session"

            ((++cleaned_only))
        fi

    done

    if ((killed > 0 && cleaned_only > 0)); then
        notify_info \
            "Killed $killed session(s), cleaned $cleaned_only inactive session app state(s)"
    elif ((killed > 0)); then
        notify_info \
            "Killed $killed session(s)"
    elif ((cleaned_only > 0)); then
        notify_info \
            "Cleaned $cleaned_only inactive session app state(s)"
    else
        notify_low \
            "Nothing to kill"
    fi
}

################################################################################
# KILL ALL
################################################################################

cmd_kill_all() {
    local active_sessions=()
    local runtime_sessions=()
    local session

    while IFS= read -r session; do
        [[ -n "$session" ]] || continue
        session="${session%%:*}"
        active_sessions+=("$session")
    done < <(
        tmux list-sessions 2>/dev/null || true
    )

    while IFS= read -r session; do
        [[ -n "$session" ]] || continue
        runtime_sessions+=("$session")
    done < <(
        db_list_runtime_sessions
    )

    if ((${#active_sessions[@]} == 0 && ${#runtime_sessions[@]} == 0)); then
        notify_low \
            "No active tmux sessions or tracked applications"
        return 0
    fi

    if ! rofi_confirm "Kill ALL Sessions ?"; then
        return 0
    fi

    local cleaned_apps=0
    local killed_tmux=0

    #
    # First clean all tracked applications,
    # including stale sessions with no tmux session.
    #
    for session in "${runtime_sessions[@]}"; do
        kill_session_applications "$session"
        ((++cleaned_apps))
    done

    #
    # Then kill active tmux sessions.
    #
    for session in "${active_sessions[@]}"; do
        tmux kill-session \
            -t "$session" \
            2>/dev/null || true
        ((++killed_tmux))
    done

    if ((killed_tmux > 0 && cleaned_apps > 0)); then
        notify_info \
            "Killed $killed_tmux tmux session(s) and cleaned $cleaned_apps tracked application group(s)"
    elif ((killed_tmux > 0)); then
        notify_info \
            "Killed $killed_tmux tmux session(s)"
    else
        notify_info \
            "Cleaned $cleaned_apps tracked application group(s)"
    fi
}

################################################################################
# CREATE BACKUP
################################################################################

create_backup() {

    local source_file="$1"
    local backup_dir="${2:-}"

    [[ -f "$source_file" ]] || return 1

    if [[ -z "$backup_dir" ]]; then
        backup_dir="$BACKUP_DIR"
    fi

    mkdir -p "$backup_dir"

    local filename
    filename="$(basename "$source_file")"

    local timestamp
    timestamp="$(date '+%Y-%m-%d_%H-%M-%S')"

    local backup_file
    backup_file="${backup_dir}/${filename}.${timestamp}.backup"

    cp \
        "$source_file" \
        "$backup_file"

    notify_info \
        "Backup created: $(basename "$backup_file")"
}

################################################################################
# LIST
################################################################################

cmd_list() {

    {
        db_get_projects |
            jq -r '
            [
                "[P]",
                .name,
                .session,
                .path
            ] | @tsv
            '

        db_get_templates |
            jq -r '
            [
                "[T]",
                .name,
                .session,
                .path
            ] | @tsv
            '
    } |
        column -t -s $'\t'
}

################################################################################
# FLAKE CACHE
################################################################################

cmd_add_flake_path() {

    (($# > 0)) || {

        notify_error \
            "Usage: add-flake-path <path> [path ...]"

        return 1
    }

    local path
    local tmp
    local added=0

    for path in "$@"; do

        [[ -d "$path" ]] || {

            notify_error \
                "Path does not exist: $path"

            continue
        }

        [[ -f "$path/flake.nix" ]] || {

            notify_error \
                "No flake.nix found: $path"

            continue
        }

        tmp="$(mktemp)"

        jq \
            --arg path "$path" '
            .flakes.paths += [$path]
            | .flakes.paths |= unique
            ' \
            "$PROJECT_DB" >"$tmp"

        mv "$tmp" "$PROJECT_DB"

        ((++added))

    done

    notify_info \
        "Added $added flake path(s)"
}

cmd_list_flakes() {

    local flakes

    flakes="$(
        db_get_cached_flakes
    )"

    [[ -n "$flakes" ]] || {

        notify_low \
            "No cached flakes"

        return 0
    }

    printf '%s\n' "$flakes"
}

cmd_cache_flakes() {

    cache_flakes

    notify_info \
        "Flake cache updated"
}

################################################################################
# MAIN
################################################################################

main() {

    ensure_dependencies
    ensure_database

    local command="${1:-help}"

    case "$command" in

    ########################################################################
    # Help
    ########################################################################

    help | -h | --help)
        show_help
        ;;

    ########################################################################
    # Database
    ########################################################################

    add)
        cmd_add_entry "project"
        ;;

    add-template)
        cmd_add_entry "template"
        ;;

    delete)
        cmd_delete
        ;;

    ########################################################################
    # Sessions
    ########################################################################

    session)
        cmd_session
        ;;

    kill)
        cmd_kill
        ;;

    kill-all)
        cmd_kill_all
        ;;

    ########################################################################
    # Windows Here
    ########################################################################

    window-here)
        cmd_window_here
        ;;

    ########################################################################
    # Edit Templates
    ########################################################################
    edit)
        cmd_edit
        ;;

    ########################################################################
    # Create Backup
    ########################################################################
    backup)
        create_backup "$PROJECT_DB" "${2:-}"
        ;;

    ########################################################################
    # Cleanup
    ########################################################################
    cleanup)
        cleanup_missing_paths
        ;;

    ########################################################################
    # List
    ########################################################################
    list)
        cmd_list
        ;;

    ########################################################################
    # Flake Cache
    ########################################################################
    add-flake-path)
        shift
        cmd_add_flake_path "$@"
        ;;

    cache-flakes)
        cmd_cache_flakes
        ;;

    list-flakes)
        cmd_list_flakes
        ;;

    ########################################################################
    # Invalid
    ########################################################################

    *)
        notify_error \
            "Unknown command: $command"

        return 1
        ;;
    esac
}

################################################################################
# ENTRYPOINT
################################################################################

main "$@"
