#!/usr/bin/env bash

set -euo pipefail

################################################################################
# Configuration
################################################################################

APP_NAME="rofi-tmux"

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/rofi-tmux"
PROJECT_DB="${DATA_DIR}/database.json"
BACKUP_DIR="${DATA_DIR}/backups"

#ROFI_CMD=(
#    rofi
#    -dmenu
#    -i
#    -multi-select
#    -ballot-selected-str "● "
#    -ballot-unselected-str "○ "
#)

ALACRITTY_CLASS_PREFIX="tmux"

MAX_CREATE_ALL=5

DEPENDENCIES=(
    jq
    tmux
    rofi
    uuidgen
    alacritty
    notify-send
)

################################################################################
# Help Text
################################################################################

readonly HELP_TEXT="
rofi-tmux - Project and Template Based tmux Manager

USAGE
rofi-tmux <command>

PROJECT COMMANDS

add
Add the current working directory as a project.

edit
Edit selected projects and/or templates.

delete
Delete selected projects and/or templates.
Active tmux sessions are terminated first.

cleanup
Remove projects whose directories no longer exist.
Active tmux sessions are terminated first.

list
Display all stored projects and templates.

TEMPLATE COMMANDS

add-template
Create a reusable template for the current directory.

SESSION COMMANDS

session
Create, attach, or switch to project/template
sessions.

create-all
Create tmux sessions for stored projects.
Limited by MAX_CREATE_ALL.

kill
Kill selected tmux sessions.

kill-all
Kill all running tmux sessions.

WINDOW COMMANDS

window
Create tmux window(s) using selected
project/template paths.

window-here
Create a numbered window in the current
tmux session using the session root path.

BACKUP COMMANDS

backup [directory]
Create a timestamped database backup.

HELP

help
-h
--help

Show this help message.

WORKFLOW

Project

cd ~/projects/my-app
rofi-tmux add
rofi-tmux session

Template

cd ~/projects/my-app
rofi-tmux add-template
rofi-tmux session

EDITING

rofi-tmux edit

The edit command opens selected entries in Neovim.

Projects expose:

{
    \"type\": \"project\",
    \"_session\": \"...\",
    \"_name\": \"...\",
    \"path\": \"/path/to/project\"
}

Templates expose:

{
    \"type\": \"template\",
    \"_session\": \"...\",
    \"name\": \"Development\",
    \"path\": \"/path/to/project\",
    \"startup\": \"nvim\",
    \"windows\": [
        \"btop\",
        \"lazygit\"
    ]
}

EDIT RULES

Projects

Editable:
    path

Automatically regenerated:
    name
    session

Templates

Editable:
    name
    path
    startup
    windows

Automatically regenerated when
name or path changes:
    session

PROTECTED FIELDS

_session
_name

These fields are informational only.

Changes to these fields are ignored.

VALIDATION

Projects

• Path must exist
• Path cannot be empty
• Duplicate project paths are rejected

Templates

• Name cannot be empty
• Path must exist
• Startup command must exist
• Windows must contain at least one command
• Every command must exist on PATH

SESSION REGENERATION

Project

Changing path:
    old-session -> new-session

Template

Changing name or path:
    old-session -> new-session

If the old tmux session is running,
it is terminated before regeneration.

DATA FILES

Database:
${PROJECT_DB}

Data Directory:
${DATA_DIR}

Backup Directory:
${BACKUP_DIR}

FEATURES

• Project management
• Template management
• Multi-select support
• Active session highlighting
• Session creation and attachment
• Automatic backups
• Session cleanup
• Project editing
• Template editing
• Persistent JSON database

NOTES

[P] = Project
[T] = Template

Projects

Startup command:
    exec zsh

Templates

Custom startup command
Custom window layout

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
  "projects": [],
  "templates": []
}
EOF
    fi
}

################################################################################
# Utility
################################################################################

show_help() {
    printf '%s\n' "$HELP_TEXT" | less -FRX
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
        "Remove ${#missing_sessions[@]} missing project(s)?"; then
        return 0
    fi

    db_backup || true

    #
    # Kill any active tmux sessions first.
    #
    for session in "${missing_sessions[@]}"; do

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

db_get_template_by_session() {
    local session="$1"

    jq -c \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        ' \
        "$PROJECT_DB"
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

db_get_template_startup() {
    local session="$1"

    jq -r \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        | .startup
        ' \
        "$PROJECT_DB"
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

db_is_template_session() {
    local session="$1"

    jq -e \
        --arg session "$session" \
        '
        .templates[]
        | select(.session == $session)
        ' \
        "$PROJECT_DB" >/dev/null
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
    local session="$3"

    local tmp
    tmp=$(mktemp)

    jq \
        --arg name "$name" \
        --arg path "$path" \
        --arg session "$session" \
        '
        .projects += [{
            "name": $name,
            "path": $path,
            "session": $session
        }]
        ' \
        "$PROJECT_DB" >"$tmp"

    mv "$tmp" "$PROJECT_DB"
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

create_session() {
    local session="$1"
    local path="$2"
    local startup_cmd="${3:-exec zsh}"

    tmux new-session \
        -d \
        -s "$session" \
        -c "$path" \
        "$startup_cmd"

    tmux set-option \
        -t "$session" \
        @header "$path"

    tmux new-window \
        -t "$session" \
        -n "Terminal" \
        -c "$path" \
        -d

    notify_low "Created session: $session"
}

create_session_if_missing() {
    local session="$1"
    local path="$2"
    local startup_cmd="${3:-exec zsh}"

    if ! tmux_session_exists "$session"; then
        create_session \
            "$session" \
            "$path" \
            "$startup_cmd"
    fi
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

cmd_add() {

    local path
    local name
    local session

    path="$(pwd -L)"
    name="$(basename "$path")"

    if db_project_exists "$path"; then

        notify_error "Project already exists"

        return 1
    fi

    session="$(generate_session_name "$path")"

    db_add_project \
        "$name" \
        "$path" \
        "$session"

    notify_info "Added $session"

    return 0
}

################################################################################
# SESSION
################################################################################

cmd_session() {

    local selections

    selections="$(
        rofi_pro_temp_selector "Tmux Session"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    #
    # Single selection
    #
    if [[ ${#entry_sessions[@]} -eq 1 ]]; then

        local session
        local type

        session="${entry_sessions[0]}"
        type="${entry_types[0]}"

        if [[ "$type" == "[T]" ]]; then

            create_session_from_template \
                "$session"

        else

            local path

            path="$(
                db_get_path_from_session "$session"
            )"

            [[ -n "$path" ]] || return 1

            create_session_if_missing \
                "$session" \
                "$path" \
                "exec zsh"
        fi

        attach_or_switch_session \
            "$session"

        return 0
    fi

    #
    # Multi selection
    #
    if ! rofi_confirm \
        "Create Sessions?"; then
        return 0
    fi

    local created=0

    local i

    for i in "${!entry_sessions[@]}"; do

        local session
        local type

        session="${entry_sessions[$i]}"
        type="${entry_types[$i]}"

        if tmux_session_exists "$session"; then

            notify_low \
                "Ignored existing session: $session"

            continue
        fi

        if [[ "$type" == "[T]" ]]; then

            create_session_from_template \
                "$session"

        else

            local path

            path="$(
                db_get_path_from_session "$session"
            )"

            [[ -n "$path" ]] || continue

            create_session \
                "$session" \
                "$path" \
                "exec zsh"
        fi

        spawn_session_terminal \
            "$session"

        ((++created))

    done

    notify_info \
        "Created $created session(s)"
}

################################################################################
# WINDOW
################################################################################

cmd_window() {

    if [[ -z "${TMUX:-}" ]]; then

        notify_error \
            "window command requires tmux"

        return 1
    fi

    local selections

    selections="$(
        rofi_pro_temp_selector "Create Windows"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    #
    # Single selection
    #
    if [[ ${#entry_sessions[@]} -eq 1 ]]; then

        local session
        local type
        local path

        session="${entry_sessions[0]}"
        type="${entry_types[0]}"

        if [[ "$type" == "[T]" ]]; then

            path="$(
                db_get_template_path "$session"
            )"

        else

            path="$(
                db_get_path_from_session "$session"
            )"

        fi

        [[ -n "$path" && -d "$path" ]] || return 1

        tmux new-window \
            -c "$path"

        return 0
    fi

    #
    # Multi selection
    #
    if ! rofi_confirm "Create Windows?"; then
        return 0
    fi

    local created=0
    local i

    for i in "${!entry_sessions[@]}"; do

        local session
        local type
        local path

        session="${entry_sessions[$i]}"
        type="${entry_types[$i]}"

        if [[ "$type" == "[T]" ]]; then

            path="$(
                db_get_template_path "$session"
            )"

        else

            path="$(
                db_get_path_from_session "$session"
            )"

        fi

        [[ -n "$path" && -d "$path" ]] || continue

        tmux new-window \
            -d \
            -c "$path"

        ((++created))

    done

    notify_info \
        "Created $created window(s)"
}

################################################################################
# WINDOW HERE
################################################################################

cmd_window_here() {

    [[ -n "${TMUX:-}" ]] || return 1

    local session
    local path

    session="$(tmux display-message -p '#S')"

    path="$(
        tmux show-option \
            -t "$session" \
            -qv @header \
            2>/dev/null || true
    )"

    [[ -n "$path" ]] || path="$(
        tmux display-message \
            -p '#{pane_current_path}'
    )"

    #
    # Collect existing numeric window names.
    #
    declare -A used

    while IFS= read -r name; do

        [[ "$name" =~ ^[0-9]+$ ]] || continue

        used["$name"]=1

    done < <(
        tmux list-windows \
            -t "$session" \
            -F '#W'
    )

    #
    # Find lowest missing number.
    #
    local n=0

    while [[ -n "${used[$n]:-}" ]]; do
        ((++n))
    done

    tmux new-window \
        -n "$n" \
        -c "$path"
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
# ADD TEMPLATE
################################################################################
validate_template_commands() {

    local file="$1"

    local startup

    startup="$(
        jq -r '.startup' "$file"
    )"

    command -v "${startup%% *}" >/dev/null 2>&1 || {
        notify_error \
            "Invalid startup command: $startup"
        return 1
    }

    while IFS= read -r cmd; do

        command -v "${cmd%% *}" >/dev/null 2>&1 || {

            notify_error \
                "Invalid window command: $cmd"

            return 1
        }

    done < <(
        jq -r '.windows[]' "$file"
    )
}

cmd_add_template() {

    local path
    local template_name
    local session

    path="$(pwd -L)"

    template_name="$(
        rofi \
            -dmenu \
            -p "Template Name"
    )"

    [[ -n "$template_name" ]] || return 0

    session="$(
        generate_template_session_name \
            "$path" \
            "$template_name"
    )"

    local tmp
    tmp="$(mktemp)"

    cat >"$tmp" <<'EOF'
{
    "startup": "nvim",

    "windows": [
        "btop"
    ]
}
EOF

    while :; do
        alacritty \
            --class "${APP_NAME}-editor" \
            -e nvim "$tmp"

        #
        # JSON validation
        #
        if ! jq empty "$tmp" >/dev/null 2>&1; then

            local action

            action="$(
                printf "Edit Config\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Invalid JSON"
            )"

            if [[ "$action" == "Edit Config" ]]; then
                continue
            fi

            rm -f "$tmp"
            return 0
        fi

        #
        # Structure validation
        #
        if ! jq -e '
            (.startup | type == "string") and
            (.startup != "") and

            (.windows | type == "array") and
            (.windows | length > 0) and

            (
                all(
                    .windows[];
                    type == "string" and . != ""
                )
            )
        ' "$tmp" >/dev/null 2>&1; then

            local action

            action="$(
                printf "Edit Config\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Invalid Template"
            )"

            if [[ "$action" == "Edit Config" ]]; then
                continue
            fi

            rm -f "$tmp"
            return 0
        fi

        #
        # Command validation
        #
        if ! validate_template_commands "$tmp"; then

            local action

            action="$(
                printf "Edit Config\nCancel\n" |
                    rofi \
                        -dmenu \
                        -p "Invalid Command"
            )"

            if [[ "$action" == "Edit Config" ]]; then
                continue
            fi

            rm -f "$tmp"
            return 0
        fi

        break

    done

    local merged
    merged="$(mktemp)"

    jq \
        --arg name "$template_name" \
        --arg path "$path" \
        --arg session "$session" \
        '
        . + {
            name: $name,
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
        "Template added: $template_name"
}

################################################################################
# CREATE TEMPLATE SESSION HELPER
################################################################################

create_session_from_template() {

    local session="$1"

    db_is_template_session "$session" || {

        notify_error \
            "Template not found: $session"

        return 1
    }

    local path
    local startup

    path="$(db_get_template_path "$session")"
    startup="$(db_get_template_startup "$session")"

    if [[ -z "$path" || ! -d "$path" ]]; then

        notify_error \
            "Invalid template path"

        return 1
    fi

    [[ -n "$startup" ]] || startup="exec zsh"

    if tmux_session_exists "$session"; then

        notify_low \
            "Session already exists: $session"

        return 0
    fi

    tmux new-session \
        -d \
        -s "$session" \
        -c "$path"

    local startup_window

    startup_window="$(
        tmux list-windows \
            -t "$session" \
            -F '#{window_id}' |
            head -n1
    )"

    [[ -n "$startup" ]] &&
        tmux send-keys \
            -t "$startup_window" \
            "$startup" \
            C-m

    local index=1
    local window_id

    while IFS= read -r window_cmd; do

        [[ -n "$window_cmd" ]] || continue

        window_id="$(
            tmux new-window \
                -d \
                -P \
                -F '#{window_id}' \
                -t "$session" \
                -n "$index" \
                -c "$path"
        )"

        tmux send-keys \
            -t "$window_id" \
            "$window_cmd" \
            C-m

        ((++index))

    done < <(
        db_get_template_windows "$session"
    )

    notify_low \
        "Created template session: $session"
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
                        path
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
                        startup,
                        windows
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
                and (.path != "")
            )

            or

            (
                .type == "template"

                and

                (.name | type == "string")
                and (.name != "")

                and

                (.path | type == "string")
                and (.path != "")

                and

                (.startup | type == "string")
                and (.startup != "")

                and

                (.windows | type == "array")
                and (.windows | length > 0)

                and

                (
                    all(
                        .windows[];
                        type == "string" and . != ""
                    )
                )
            )
        )
    ' "$file" >/dev/null 2>&1
}

validate_edited_templates() {

    local file="$1"

    local template
    local tmp

    while IFS= read -r template; do

        tmp="$(mktemp)"

        jq '
            {
                startup,
                windows
            }
        ' <<<"$template" >"$tmp"

        if ! validate_template_commands "$tmp"; then

            rm -f "$tmp"
            return 1

        fi

        rm -f "$tmp"

    done < <(
        jq -c '
            .[]
            | select(.type == "template")
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

    validate_edited_templates "$file" ||
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
            local new_session

            new_path="$(jq -r '.path' <<<"$item")"

            [[ -d "$new_path" ]] || {
                notify_error \
                    "Path does not exist: $new_path"
                return 1
            }

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
                --arg new_session "$new_session" \
                '
                .projects |= map(
                    if .session == $old_session
                    then
                        .name = $new_name
                        | .path = $new_path
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
            local new_startup
            local new_windows
            local new_session

            new_name="$(jq -r '.name' <<<"$item")"
            new_path="$(jq -r '.path' <<<"$item")"
            new_startup="$(jq -r '.startup' <<<"$item")"
            new_windows="$(jq -c '.windows' <<<"$item")"

            [[ -d "$new_path" ]] || {
                notify_error \
                    "Path does not exist: $new_path"
                return 1
            }

            new_session="$old_session"

            if [[ "$new_name" != "$old_name" ]] ||
                [[ "$new_path" != "$old_path" ]]; then

                new_session="$(
                    generate_template_session_name \
                        "$new_path" \
                        "$new_name"
                )"

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
                --arg new_startup "$new_startup" \
                --arg new_session "$new_session" \
                --argjson new_windows "$new_windows" \
                '
                .templates |= map(
                    if .session == $old_session
                    then
                        .name = $new_name
                        | .path = $new_path
                        | .startup = $new_startup
                        | .windows = $new_windows
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
            "Edit Projects/Templates"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    local tmp
    tmp="$(mktemp)"

    build_edit_json "$tmp"

    local original_hash
    original_hash="$(
        sha256sum "$tmp" | cut -d' ' -f1
    )"

    while :; do

        alacritty \
            --class "${APP_NAME}-editor" \
            -e nvim "$tmp"

        local new_hash
        new_hash="$(
            sha256sum "$tmp" | cut -d' ' -f1
        )"

        #
        # Nothing changed.
        #
        if [[ "$original_hash" == "$new_hash" ]]; then

            rm -f "$tmp"

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
                        -p "Validation Failed"
            )"

            [[ "$action" == "Edit Again" ]] && continue

            rm -f "$tmp"
            return 0
        fi

        break

    done

    #
    # Pass original sessions so apply_edits()
    # does not trust _session from the edited JSON.
    #

    if ! apply_edits \
        "$tmp" \
        "${entry_sessions[@]}"; then

        rm -f "$tmp"
        return 1
    fi
    rm -f "$tmp"

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
            "Delete Projects/Templates"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    if ! rofi_confirm \
        "Delete ${#entry_sessions[@]} selected item(s)?"; then
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

        if tmux_session_exists "$session"; then

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
        rofi_pro_temp_selector "Kill Sessions"
    )"

    [[ -n "$selections" ]] || return 0

    mapfile -t entries <<<"$selections"

    normalize_entries

    if ! rofi_confirm "Kill Selected Sessions?"; then
        return 0
    fi

    local killed=0
    local session

    for session in "${entry_sessions[@]}"; do

        if ! tmux_session_exists "$session"; then

            notify_low \
                "Ignored inactive session: $session"

            continue
        fi

        tmux kill-session \
            -t "$session"

        notify_low \
            "Killed: $session"

        ((++killed))

    done

    notify_info \
        "Killed $killed session(s)"
}

################################################################################
# CREATE ALL
################################################################################

cmd_create_all() {

    if ! rofi_confirm "Create up to ${MAX_CREATE_ALL} sessions?"; then
        return 0
    fi

    local created=0

    while IFS= read -r project; do

        ((created >= MAX_CREATE_ALL)) && break

        local session
        local path

        session="$(jq -r '.session' <<<"$project")"
        path="$(jq -r '.path' <<<"$project")"

        if tmux_session_exists "$session"; then
            notify_low "Ignored existing session: $session"
            continue
        fi

        create_session \
            "$session" \
            "$path" \
            "exec zsh"

        spawn_session_terminal "$session"

        ((++created))

    done < <(db_get_projects)

    notify_info "Created $created session(s)"
}

################################################################################
# KILL ALL
################################################################################

cmd_kill_all() {

    local active

    active="$(
        tmux list-sessions 2>/dev/null || true
    )"

    if [[ -z "$active" ]]; then

        notify_low \
            "No active tmux sessions"

        return 0
    fi

    if ! rofi_confirm "Kill ALL Sessions?"; then
        return 0
    fi

    local count

    count="$(
        tmux list-sessions 2>/dev/null |
            wc -l
    )"

    #
    # Kill everything.
    #
    # We intentionally do NOT preserve the
    # current session because this command
    # mirrors your original killall behavior.
    #

    while IFS= read -r session; do

        session="$(
            cut -d: -f1 <<<"$session"
        )"

        tmux kill-session \
            -t "$session"

    done < <(
        tmux list-sessions 2>/dev/null
    )

    notify_info \
        "Killed $count session(s)"
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
        cmd_add
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

    create-all)
        cmd_create_all
        ;;

    add-template)
        cmd_add_template
        ;;

    kill)
        cmd_kill
        ;;

    kill-all)
        cmd_kill_all
        ;;

    ########################################################################
    # Windows
    ########################################################################

    window)
        cmd_window
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
