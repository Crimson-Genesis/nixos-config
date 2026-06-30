#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# rofi-dictionary
# WordNet dictionary launcher with rofi history
# ==================================================

# --------------------------------------------------
# config
# --------------------------------------------------
CACHE_DIR="/tmp/rofi-dictionary"
HISTORY_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-dictionary"
HISTORY_FILE="$HISTORY_DIR/history"
CURRENT_FILE="$CACHE_DIR/current.md"
LAST_FILE="$CACHE_DIR/last.md"
MAX_HISTORY="${MAX_HISTORY:-200}"

ROFI_CMD=(
    rofi
    -dmenu
    -i
    -p "Dictionary:"
    -mesg "Type a word or pick from history"
)

TERMINAL="${TERMINAL:-alacritty}"
EDITOR_CMD="${EDITOR_CMD:-nvim}"
WN="${WN:-wn}"

mkdir -p "$CACHE_DIR" "$HISTORY_DIR"
touch "$HISTORY_FILE"

# --------------------------------------------------
# helpers
# --------------------------------------------------
usage() {
    cat <<EOF
rofi-dictionary - WordNet dictionary launcher with rofi history

Usage:
  $(basename "$0")                  Open rofi and look up a word
  $(basename "$0") --word WORD      Look up WORD directly
  $(basename "$0") --print WORD     Print formatted markdown to stdout
  $(basename "$0") --dump WORD      Generate markdown file only and print its path
  $(basename "$0") --help           Show this help message
  $(basename "$0") --clear          Clear lookup history

Options:
  --word WORD     Look up WORD without opening rofi
  --print WORD    Print formatted markdown to stdout and exit
  --dump WORD     Write markdown to \$CURRENT_FILE and print the file path
  --help, -h      Show this help message and exit
  --clear         Remove all saved lookup history and exit

Environment variables:
  TERMINAL        Terminal used to display results
                  default: alacritty
  EDITOR_CMD      Editor opened inside terminal
                  default: nvim
  WN              WordNet backend command
                  default: wn
  MAX_HISTORY     Maximum history size
                  default: 200

Files:
  History file:      $HISTORY_FILE
  Current lookup file:  $CURRENT_FILE
EOF
}

die() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

have() {
    command -v "$1" >/dev/null 2>&1
}

trim() {
    local s="${1-}"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

get_cached_wn() {
    local flag="$1"
    cat "$CACHE_DIR/jobs/$flag" 2>/dev/null || true
}

escape_md_inline() {
    local s="${1-}"
    s=${s//\\/\\\\}
    s=${s//\*/\\*}
    s=${s//_/\\_}
    s=${s//\[/\\[}
    s=${s//\]/\\]}
    printf '%s' "$s"
}

normalize_word() {
    local word
    word="$(trim "${1-}")"
    [[ -n "$word" ]] || return 1
    printf '%s' "$word"
}

ensure_dependencies() {
    have "$WN" || die "WordNet command not found: $WN"
}

trim_history() {
    awk 'NF && !seen[$0]++' "$HISTORY_FILE" | head -n "$MAX_HISTORY" >"${HISTORY_FILE}.tmp"
    mv "${HISTORY_FILE}.tmp" "$HISTORY_FILE"
}

add_history() {
    local word="$1"
    local tmp
    tmp="$(mktemp)"

    {
        printf '%s\n' "$word"
        grep -vxF "$word" "$HISTORY_FILE" 2>/dev/null || true
    } >"$tmp"

    head -n "$MAX_HISTORY" "$tmp" >"${tmp}.trim"
    mv "${tmp}.trim" "$HISTORY_FILE"
    rm -f "$tmp"
}

clear_history() {
    : >"$HISTORY_FILE"
    printf 'Dictionary history cleared: %s\n' "$HISTORY_FILE"
}

# --------------------------------------------------
# output helpers
# --------------------------------------------------
parse_relation_output() {
    local raw="$1"
    awk '
    function trim(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        return s
    }

    function format_relation_line(s) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        if (sub(/^HAS INSTANCE=>[[:space:]]*/, "", s)) return "**Has Instance:** " s
        if (sub(/^HAS PART:[[:space:]]*/, "", s)) return "**Has Part:** " s
        if (sub(/^HAS MEMBER:[[:space:]]*/, "", s)) return "**Has Member:** " s
        if (sub(/^HAS SUBSTANCE:[[:space:]]*/, "", s)) return "**Has Substance:** " s
        if (sub(/^(PART OF:|PART OF=>)[[:space:]]*/, "", s)) return "**Part of:** " s
        if (sub(/^(MEMBER OF:|MEMBER OF=>)[[:space:]]*/, "", s)) return "**Member of:** " s
        if (sub(/^(SUBSTANCE OF:|SUBSTANCE OF=>)[[:space:]]*/, "", s)) return "**Substance of:** " s
        if (sub(/^TOPIC TERM->[[:space:]]*/, "", s)) return "**Topic Term:** " s
        if (sub(/^REGION TERM->[[:space:]]*/, "", s)) return "**Region Term:** " s
        if (sub(/^USAGE TERM->[[:space:]]*/, "", s)) return "**Usage Term:** " s
        if (sub(/^TOPIC->[[:space:]]*/, "", s)) return "**Topic:** " s
        if (sub(/^REGION->[[:space:]]*/, "", s)) return "**Region:** " s
        if (sub(/^USAGE->[[:space:]]*/, "", s)) return "**Usage:** " s
        if (sub(/^RELATED TO->[[:space:]]*/, "", s)) return "**Related to:** " s
        if (sub(/^Also See->[[:space:]]*/, "", s)) return "**See also:** " s
        if (sub(/^Verb Group->[[:space:]]*/, "", s)) return "**Verb Group:** " s
        if (sub(/^Causes->[[:space:]]*/, "", s)) return "**Causes:** " s
        if (sub(/^Entails->[[:space:]]*/, "", s)) return "**Entails:** " s
        if (sub(/^Antonym of[[:space:]]*/, "", s)) return "**Antonym of:** " s
        if (sub(/^Phrasal Verb->[[:space:]]*/, "", s)) return "**Phrasal Verb:** " s
        if (match(s, /^INDIRECT \(VIA [^)]+\) ->/)) {
            idx_start = index(s, "(VIA ") + 5
            idx_end = index(s, ") ->")
            via = substr(s, idx_start, idx_end - idx_start)
            idx_arrow = index(s, "->")
            rest = substr(s, idx_arrow + 2)
            sub(/^[[:space:]]+/, "", rest)
            return "**Indirect Antonym (via " via "):** " rest
        }
        if (sub(/^EX:[[:space:]]*/, "", s)) return "*Example:* \"" s "\""
        if (sub(/^\*>[[:space:]]*/, "", s)) return "*Frame:* " s
        if (sub(/^=>[[:space:]]*/, "", s)) return s
        if (sub(/^->[[:space:]]*/, "", s)) return s
        if (match(s, /^Pertains to /)) return "**Pertains to:** " substr(s, 13)
        if (match(s, /^Derived from /)) return "**Derived from:** " substr(s, 14)
        return s
    }

    BEGIN {
        sense_num = ""
        is_first_line_of_sense = 0
        indent_count = 0
        have_output = 0
        non_empty_count = 0
    }

    /^[[:space:]]*$/ { next }

    # The very first non-empty line is always the title of the search, skip it
    ++non_empty_count == 1 { next }

    # Skip sense count lines
    / senses? of / { next }
    / of [0-9]+ senses of / { next }

    # Sense matching
    /^Sense[[:space:]]+[0-9]+/ {
        sense_num = $2
        gsub(/[^0-9]/, "", sense_num)
        is_first_line_of_sense = 1
        indent_count = 0
        next
    }

    {
        raw = $0
        line = trim(raw)
        if (line == "") next

        # Get leading spaces
        match(raw, /[^ ]/)
        spaces = RSTART - 1

        is_relation = 0
        if (spaces > 0 || line ~ /^INDIRECT/ || line ~ /->/ || line ~ /=>/ || line ~ /^(HAS|PART OF|MEMBER OF|SUBSTANCE OF|RELATED TO|Also See|Verb Group|Causes|Entails|Antonym of|Phrasal Verb)/) {
            is_relation = 1
        }

        if (!is_relation) {
            # This is the synset line
            if (sense_num != "") {
                if (have_output) print ""
                printf "#### Sense %s\n\n", sense_num
                printf "- %s\n", line
                have_output = 1
            } else {
                # Flat list term
                print "- " line
                have_output = 1
            }
            is_first_line_of_sense = 0
        } else {
            # Find/add level
            level = 0
            if (spaces == 0) {
                level = 1
            } else {
                for (i = 1; i <= indent_count; i++) {
                    if (spaces >= indent_list[i] - 2 && spaces <= indent_list[i] + 2) {
                        level = i
                        break
                    }
                }
                if (level == 0) {
                    indent_list[++indent_count] = spaces
                    # Sort indent list
                    for (i = 1; i <= indent_count; i++) {
                        for (j = i + 1; j <= indent_count; j++) {
                            if (indent_list[i] > indent_list[j]) {
                                tmp = indent_list[i]
                                indent_list[i] = indent_list[j]
                                indent_list[j] = tmp
                            }
                        }
                    }
                    # Re-find
                    for (i = 1; i <= indent_count; i++) {
                        if (spaces >= indent_list[i] - 2 && spaces <= indent_list[i] + 2) {
                            level = i
                            break
                        }
                    }
                }
            }

            # Generate indentation (nested under the synset root)
            pad = "  "
            for (k = 1; k < level; k++) {
                pad = pad "  "
            }

            formatted = format_relation_line(line)
            if (formatted != "") {
                if (sense_num == "") {
                    # Outside sense, just output flat bullet
                    print "- " formatted
                } else {
                    printf "%s- %s\n", pad, formatted
                }
                have_output = 1
            }
        }
    }
    ' <<<"$raw"
}

render_overview_for_pos() {
    local word="$1"
    local pos="$2"
    local raw
    raw="$(get_cached_wn -over)"
    [[ -n "${raw//[[:space:]]/}" ]] || return 1

    # Map POS to WN header naming
    local wn_pos="$pos"

    awk -v pos="$wn_pos" -v word="$word" '
    BEGIN {
        matched = 0
        sense_num = ""
        sense_head = ""
        sense_def = ""
        example_count = 0
    }
    function trim(s) {
        sub(/^[[:space:]]+/, "", s)
        sub(/[[:space:]]+$/, "", s)
        return s
    }
    function flush_sense() {
        if (sense_num == "") return
        printf "#### Sense %s\n\n", sense_num
        if (sense_head != "") printf "**Words:** %s\n\n", sense_head
        if (sense_def != "") printf "**Meaning:** %s\n\n", sense_def
        if (example_count > 0) {
            print "**Examples:**"
            for (i = 1; i <= example_count; i++) {
                printf "- %s\n", examples[i]
            }
            print ""
        }
        sense_num = ""
        sense_head = ""
        sense_def = ""
        example_count = 0
        delete examples
    }

    $0 ~ "^Overview of " pos " " {
        matched = 1
        next
    }
    matched && /^Overview of / {
        matched = 0
        exit
    }

    matched {
        if (/^[[:space:]]*[0-9]+\.[[:space:]]/) {
            flush_sense()
            line = $0
            sub(/^[[:space:]]*/, "", line)
            sense_num = line
            sub(/\..*$/, "", sense_num)
            sub(/^[0-9]+\.[[:space:]]*/, "", line)
            sub(/^\([0-9]+\)[[:space:]]*/, "", line)

            if (match(line, /\(.*\)$/)) {
                gloss = substr(line, RSTART + 1, RLENGTH - 2)
                head = trim(substr(line, 1, RSTART - 1))
                sub(/[[:space:]]*--[[:space:]]*$/, "", head)
                sense_head = head

                n = split(gloss, parts, /;[[:space:]]*/)
                if (n >= 1) {
                    sense_def = trim(parts[1])
                    example_count = 0
                    for (i = 2; i <= n; i++) {
                        ex = trim(parts[i])
                        gsub(/^"/, "", ex)
                        gsub(/"$/, "", ex)
                        if (ex != "") {
                            example_count++
                            examples[example_count] = ex
                        }
                    }
                }
            } else {
                sense_head = trim(line)
            }
        }
    }
    END {
        flush_sense()
    }
    ' <<<"$raw"
}

render_familiarity() {
    local word="$1"
    local flag="$2"
    local raw
    raw="$(get_cached_wn "$flag")"
    [[ -n "${raw//[[:space:]]/}" ]] || return 0

    local parsed
    parsed="$(
        awk '
        function trim(s) {
            sub(/^[[:space:]]+/, "", s)
            sub(/[[:space:]]+$/, "", s)
            return s
        }
        /^Familiarity of/ { next }
        /^No information available/ { next }
        /^[[:space:]]*$/ { next }
        {
            line = trim($0)
            if (line != "") print "- " line
        }
        ' <<<"$raw"
    )"
    [[ -n "$parsed" ]] || return 0

    printf '### Familiarity\n\n'
    printf '%s\n\n' "$parsed"
}

render_pos_details() {
    local word="$1"
    local pos="$2"

    # 1. Overview
    if has_flag "$pos" "-over"; then
        local section
        section="$(render_overview_for_pos "$word" "$pos" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Overview\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 2. Synonyms & Similarity
    if [[ "$pos" == "verb" ]]; then
        if has_flag "$pos" "-synsv"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -synsv 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Synonyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
        if has_flag "$pos" "-simsv"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -simsv 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Synonyms (Grouped by Similarity)\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
    else
        local flag=""
        case "$pos" in
        noun) flag="-synsn" ;;
        adj) flag="-synsa" ;;
        adv) flag="-synsr" ;;
        esac
        if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Synonyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
    fi

    # 3. Antonyms
    local flag=""
    case "$pos" in
    noun) flag="-antsn" ;;
    verb) flag="-antsv" ;;
    adj) flag="-antsa" ;;
    adv) flag="-antsr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Antonyms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 4. Pertainyms
    local flag=""
    case "$pos" in
    adj) flag="-perta" ;;
    adv) flag="-pertr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Pertainyms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 5. Attributes
    local flag=""
    case "$pos" in
    noun) flag="-attrn" ;;
    adj) flag="-attra" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Attributes\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 6. Derived Forms
    local flag=""
    case "$pos" in
    noun) flag="-derin" ;;
    verb) flag="-deriv" ;;
    adj) flag="-deria" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Derived Forms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 7. Hypernyms & Hyponyms / Trees
    # Hypernyms
    local flag=""
    case "$pos" in
    noun) flag="-hypen" ;;
    verb) flag="-hypev" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Hypernyms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # Hyponyms (prefer tree if available, otherwise immediate)
    local flag=""
    local tree_flag=""
    case "$pos" in
    noun)
        flag="-hypon"
        tree_flag="-treen"
        ;;
    verb)
        flag="-hypov"
        tree_flag="-treev"
        ;;
    esac
    if [[ -n "$tree_flag" ]] && has_flag "$pos" "$tree_flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$tree_flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Hyponym Tree\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    elif [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Hyponyms (Immediate)\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 8. Coordinate Terms
    local flag=""
    case "$pos" in
    noun) flag="-coorn" ;;
    verb) flag="-coorv" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Coordinate Terms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 9. Meronyms (Noun only)
    if [[ "$pos" == "noun" ]]; then
        # Prefer All Meronyms (-meron) and Hierarchical Meronyms (-hmern)
        if has_flag "$pos" "-meron"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -meron 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Meronyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
        if has_flag "$pos" "-hmern"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -hmern 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Hierarchical Meronyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
        # If -meron is not available, try specific meronym options
        if ! has_flag "$pos" "-meron"; then
            for f in -partn -membn -subsn; do
                if has_flag "$pos" "$f"; then
                    local f_title=""
                    case "$f" in
                    -partn) f_title="Part Meronyms" ;;
                    -membn) f_title="Member Meronyms" ;;
                    -subsn) f_title="Substance Meronyms" ;;
                    esac
                    local section
                    section="$(parse_relation_output "$(get_cached_wn "$f" 2>/dev/null || true)" || true)"
                    if [[ -n "$(trim "$section")" ]]; then
                        printf '### %s\n\n' "$f_title" >>"$CURRENT_FILE"
                        printf '%s\n\n' "$section" >>"$CURRENT_FILE"
                    fi
                fi
            done
        fi
    fi

    # 10. Holonyms (Noun only)
    if [[ "$pos" == "noun" ]]; then
        # Prefer All Holonyms (-holon) and Hierarchical Holonyms (-hholn)
        if has_flag "$pos" "-holon"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -holon 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Holonyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
        if has_flag "$pos" "-hholn"; then
            local section
            section="$(parse_relation_output "$(get_cached_wn -hholn 2>/dev/null || true)" || true)"
            if [[ -n "$(trim "$section")" ]]; then
                printf '### Hierarchical Holonyms\n\n' >>"$CURRENT_FILE"
                printf '%s\n\n' "$section" >>"$CURRENT_FILE"
            fi
        fi
        # If -holon is not available, try specific holonym options
        if ! has_flag "$pos" "-holon"; then
            for f in -sprtn -smemn -ssubn; do
                if has_flag "$pos" "$f"; then
                    local f_title=""
                    case "$f" in
                    -sprtn) f_title="Part Holonyms" ;;
                    -smemn) f_title="Member Holonyms" ;;
                    -ssubn) f_title="Substance Holonyms" ;;
                    esac
                    local section
                    section="$(parse_relation_output "$(get_cached_wn "$f" 2>/dev/null || true)" || true)"
                    if [[ -n "$(trim "$section")" ]]; then
                        printf '### %s\n\n' "$f_title" >>"$CURRENT_FILE"
                        printf '%s\n\n' "$section" >>"$CURRENT_FILE"
                    fi
                fi
            done
        fi
    fi

    # 11. Verb Relations (Verb only)
    if [[ "$pos" == "verb" ]]; then
        for f in -entav -causv -framv; do
            if has_flag "$pos" "$f"; then
                local f_title=""
                case "$f" in
                -entav) f_title="Verb Entailment" ;;
                -causv) f_title="Cause To" ;;
                -framv) f_title="Verb Frames" ;;
                esac
                local section
                section="$(parse_relation_output "$(get_cached_wn "$f" 2>/dev/null || true)" || true)"
                if [[ -n "$(trim "$section")" ]]; then
                    printf '### %s\n\n' "$f_title" >>"$CURRENT_FILE"
                    printf '%s\n\n' "$section" >>"$CURRENT_FILE"
                fi
            fi
        done
    fi

    # 12. Domain & Domain Terms
    # Domain
    local flag=""
    case "$pos" in
    noun) flag="-domnn" ;;
    verb) flag="-domnv" ;;
    adj) flag="-domna" ;;
    adv) flag="-domnr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Domain\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi
    # Domain Terms
    local flag=""
    case "$pos" in
    noun) flag="-domtn" ;;
    verb) flag="-domtv" ;;
    adj) flag="-domta" ;;
    adv) flag="-domtr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Domain Terms\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 13. Compound Words
    local flag=""
    case "$pos" in
    noun) flag="-grepn" ;;
    verb) flag="-grepv" ;;
    adj) flag="-grepa" ;;
    adv) flag="-grepr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(parse_relation_output "$(get_cached_wn "$flag" 2>/dev/null || true)" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '### Compound Words\n\n' >>"$CURRENT_FILE"
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi

    # 14. Familiarity
    local flag=""
    case "$pos" in
    noun) flag="-famln" ;;
    verb) flag="-famlv" ;;
    adj) flag="-famla" ;;
    adv) flag="-famlr" ;;
    esac
    if [[ -n "$flag" ]] && has_flag "$pos" "$flag"; then
        local section
        section="$(render_familiarity "$word" "$flag" || true)"
        if [[ -n "$(trim "$section")" ]]; then
            printf '%s\n\n' "$section" >>"$CURRENT_FILE"
        fi
    fi
}

has_flag() {
    local pos="$1"
    local flag="$2"
    [[ " ${pos_flags[$pos]:-} " == *" $flag "* ]]
}

# --------------------------------------------------
# document builder
# --------------------------------------------------
render_document() {
    local word="$1"
    if [[ -f "$CURRENT_FILE" ]]; then
        mv "$CURRENT_FILE" "$LAST_FILE"
    fi
    : >"$CURRENT_FILE"

    printf '# %s\n\n' "$(escape_md_inline "$word")" >>"$CURRENT_FILE"

    # Get available POS and flags from a single fast "wn <word>" run
    local pos_list=()
    declare -A pos_flags=()
    local info_output
    info_output="$("$WN" "$word" 2>/dev/null || true)"

    local all_flags=("-over") # Always run -over if possible

    while read -r pos flags; do
        [[ -n "$pos" ]] || continue
        pos_list+=("$pos")
        pos_flags["$pos"]="$flags"
        for f in $flags; do
            all_flags+=("$f")
        done
    done < <(
        awk '
        /^Information available for / {
            if (pos != "") {
                print pos, flags
            }
            pos = $4
            flags = ""
            next
        }
        /^[[:space:]]+-/ {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, /\t|[[:space:]]{2,}/)
            n = split(parts[1], f_parts, /,[[:space:]]*/)
            for (i = 1; i <= n; i++) {
                flags = flags " " f_parts[i]
            }
        }
        END {
            if (pos != "") {
                print pos, flags
            }
        }
        ' <<<"$info_output"
    )

    if [[ ${#pos_list[@]} -eq 0 ]]; then
        printf 'No results found in WordNet.\n' >>"$CURRENT_FILE"
        return 0
    fi

    # Unique all_flags and spawn background jobs
    local jobs_dir="$CACHE_DIR/jobs"
    rm -rf "$jobs_dir"
    mkdir -p "$jobs_dir"

    # Extract unique flags
    local unique_flags=()
    while read -r flag; do
        [[ -n "$flag" ]] && unique_flags+=("$flag")
    done < <(printf '%s\n' "${all_flags[@]}" | sort -u)

    # Spawn jobs in parallel
    declare -A job_pids=()
    for flag in "${unique_flags[@]}"; do
        "$WN" "$word" "$flag" >"$jobs_dir/$flag" 2>/dev/null &
        job_pids["$flag"]=$!
    done

    # Wait for all background jobs
    for flag in "${unique_flags[@]}"; do
        wait "${job_pids[$flag]}" 2>/dev/null || true
    done

    # Sort POS list: noun, verb, adj, adv
    local sorted_pos_list=()
    for p in noun verb adj adv; do
        for k in "${pos_list[@]}"; do
            if [[ "$p" == "$k" ]]; then
                sorted_pos_list+=("$p")
                break
            fi
        done
    done

    # Process each POS using cached files
    for pos in "${sorted_pos_list[@]}"; do
        # Print POS header
        local pos_name=""
        case "$pos" in
        noun) pos_name="Noun" ;;
        verb) pos_name="Verb" ;;
        adj) pos_name="Adjective" ;;
        adv) pos_name="Adverb" ;;
        esac

        printf '## %s\n\n' "$pos_name" >>"$CURRENT_FILE"
        render_pos_details "$word" "$pos"
    done
}

# --------------------------------------------------
# UI
# --------------------------------------------------
open_viewer() {
    local word="$1"

    have "$TERMINAL" || die "Terminal not found: $TERMINAL"
    have "$EDITOR_CMD" || die "Editor not found: $EDITOR_CMD"

    local lua_script="/home/nico/.config/LSD/dict.lua"
    if [[ -f "$lua_script" ]]; then
        "$TERMINAL" \
            --title="Dictionary: $word" \
            --class "rofi-dictionary" \
            -e "$EDITOR_CMD" -S "$lua_script" -R "$CURRENT_FILE"
    else
        "$TERMINAL" \
            --title="Dictionary: $word" \
            --class "rofi-dictionary" \
            -e "$EDITOR_CMD" -R "$CURRENT_FILE"
    fi
}

lookup_word() {
    local word="$1"
    render_document "$word"
    open_viewer "$word"
}

lookup_and_print() {
    local word="$1"
    render_document "$word"
    cat "$CURRENT_FILE"
}

lookup_and_dump() {
    local word="$1"
    render_document "$word"
    printf '%s\n' "$CURRENT_FILE"
}

prompt_word() {
    trim_history

    local word
    word="$(
        tac "$HISTORY_FILE" 2>/dev/null | "${ROFI_CMD[@]}"
    )" || return 1

    word="$(normalize_word "$word")" || return 1
    printf '%s\n' "$word"
}

main() {
    ensure_dependencies

    local mode="rofi"
    local word=""

    case "${1:-}" in
    "")
        mode="rofi"
        ;;
    --help | -h)
        usage
        exit 0
        ;;
    --clear)
        clear_history
        exit 0
        ;;
    --word)
        [[ $# -ge 2 ]] || die "--word requires an argument"
        mode="word"
        word="$2"
        ;;
    --print)
        [[ $# -ge 2 ]] || die "--print requires an argument"
        mode="print"
        word="$2"
        ;;
    --dump)
        [[ $# -ge 2 ]] || die "--dump requires an argument"
        mode="dump"
        word="$2"
        ;;
    *)
        die "Unknown option: $1"
        ;;
    esac

    case "$mode" in
    rofi)
        word="$(prompt_word)" || exit 0
        ;;
    word | print | dump)
        word="$(normalize_word "$word")" || die "Empty word"
        ;;
    esac

    case "$mode" in
    rofi | word)
        add_history "$word"
        lookup_word "$word"
        ;;
    print)
        lookup_and_print "$word"
        ;;
    dump)
        lookup_and_dump "$word"
        ;;
    esac
}

main "$@"
