#!/usr/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

set -eo pipefail

# shellcheck disable=SC2155
declare -r CDUI_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
declare -r CDUI_PLUGIN_DIR="${CDUI_PLUGIN_DIR:-${CDUI_SCRIPT_DIR}/cdui.d}"

if [[ -f ${CDUI_SCRIPT_DIR}/cduilib.sh ]]; then
    # shellcheck source=./cduilib.sh
    . "${CDUI_SCRIPT_DIR}"/cduilib.sh
else
    echo "Missed file: ${CDUI_SCRIPT_DIR}/cduilib.sh" >&2
    exit 1
fi

# BEGIN Helper functions
function validate_manifest()
{
    local -r file="${1}"
    jq -ef "${CDUI_SCRIPT_DIR}"/validate-manifest.jq "${file}" >/dev/null
}

function load_manifests()
{
    local -a files=("${CDUI_PLUGIN_DIR}"/*/manifest.json)
    [[ -e "${files[0]}" ]] || {
        echo '[]'
        return
    }

    local -a valid_files=()
    local f
    for f in "${files[@]}"; do
        if validate_manifest "${f}"; then
            valid_files+=("${f}")
        else
            cdui.die "Invalid manifest: ${f}"
        fi
    done

    jq -s 'sort_by(.order)' "${valid_files[@]}"
}

function build_index()
{
    local -r json="${1}"

    jq -rf "${CDUI_SCRIPT_DIR}"/build-index.jq <<<"${json}"
}

function resolve_script_path()
{
    local -r script="${1}"
    local -r path="${CDUI_PLUGIN_DIR}/${script%.sh}/${script}"

    [[ -f "${path}" ]] || {
        cdui.die "Script not found: ${path}"
    }

    echo "${path}"
}

function parse_entrypoint()
{
    local -r entrypoint="${1}"
    local script run_func update_func

    IFS=':' read -r script run_func update_func <<<"${entrypoint}"

    [[ -n "${script}" && -n "${run_func}" ]] || {
        cdui.die "Invalid entrypoint: ${entrypoint}"
    }

    echo "${script}"$'\t'"${run_func}"$'\t'"${update_func:-}"
}

function execute_entrypoint()
{
    local -r entrypoint="${1}"
    local -r selector="${2}"
    local -r arg="${3:-}"

    local script run_func update_func
    IFS=$'\t' read -r script run_func update_func < <(parse_entrypoint "${entrypoint}")

    local func="${!selector}"
    [[ -n "${func}" ]] || return 0

    # shellcheck disable=SC2155
    local -r script_path="$(resolve_script_path "${script}")"

    # shellcheck disable=SC1090
    source "${script_path}"

    if ! declare -F "${func}" >/dev/null; then
        cdui.die "Function '${func}' not found in ${script_path}"
    fi

    if [[ -n "${arg}" ]]; then
        "${func}" "${arg}"
    else
        "${func}"
    fi
}

function print_ui_hint()
{
    local -r json="${1}"
    jq -r '.[] | "\(.hotkey) \(.description)"' <<<"${json}"
}

function print_help()
{
    local -r json="${1}"

    local -a rows=()
    local opt desc row
    local max_len=0

    echo "Usage: $(basename "$0") [OPTIONS]"
    echo

    rows+=("--help"$'\t'"Show this help screen")
    rows+=("--ui-hint"$'\t'"Show UI hints")
    rows+=("--update PATH"$'\t'"Run plugin update hooks for the selected directory")

    while IFS=$'\t' read -r opt desc; do
        rows+=("${opt}"$'\t'"Use '${desc}' feed")
    done < <(
        jq -r '
          .[]
          | . as $p
          | [ ($p.options | join(", ")), $p.description ]
          | @tsv
        ' <<<"${json}"
    )

    for row in "${rows[@]}"; do
        IFS=$'\t' read -r opt desc <<<"${row}"
        (( ${#opt} > max_len )) && max_len=${#opt}
    done

    echo "Options:"
    for row in "${rows[@]}"; do
        IFS=$'\t' read -r opt desc <<<"${row}"
        printf "  %-*s  %s\n" "${max_len}" "${opt}" "${desc}"
    done
}
# END Helper functions

# Execution

# shellcheck disable=SC2155
declare -r PLUGINS_JSON="$(load_manifests)"
declare -A OPTION_TO_ENTRYPOINT
declare -A ENTRYPOINT_TO_ICON
while IFS=$'\t' read -r kind a b; do
    case "${kind}" in
        ERR_DUP_OPT)
            cdui.die "Duplicate CLI option: ${a}"
            ;;
        ERR_DUP_KEY)
            cdui.die "Duplicate hotkey: ${a}"
            ;;
        MAP)
            OPTION_TO_ENTRYPOINT["${a}"]="${b}"
            ;;
        ICON)
            ENTRYPOINT_TO_ICON["${a}"]="${b}"
            ;;
    esac
done < <(build_index "${PLUGINS_JSON}") || true

# Show help screen if no options given
if [[ $# -eq 0 ]]; then
    print_help "${PLUGINS_JSON}"
    exit 0
fi

cdui.config.load

declare -i ui_hint=0
declare update_path=''
declare -a selected_entrypoints=()
while (($# > 0)); do
    case "${1}" in
        --help)
            print_help "${PLUGINS_JSON}"
            exit 0
            ;;
        --ui-hint)
            ui_hint=1
            shift
            ;;
        --update)
            [[ -n "${2:-}" ]] || {
                cdui.die "Option requires an argument: ${1}"
            }
            update_path="${2}"
            shift 2
            ;;
        --update=*)
            update_path="${1#--update=}"
            shift
            ;;
        --)
            shift
            break
            ;;
        -*)
            if [[ -n "${OPTION_TO_ENTRYPOINT[${1}]:-}" ]]; then
                selected_entrypoints+=("${OPTION_TO_ENTRYPOINT[${1}]}")
            else
                cdui.die "Unknown option: ${1}"
            fi
            shift
            ;;
        *)
            cdui.die "Unexpected argument: ${1}"
            ;;
    esac
done

if [[ -n "${update_path}" ]]; then
    if [[ ${#selected_entrypoints[@]} -gt 0 || ${ui_hint} -eq 1 ]]; then
        cdui.die "--update cannot be combined with other options"
    fi
fi

if [[ ${ui_hint} -eq 1 && ${#selected_entrypoints[@]} -gt 0 ]]; then
    cdui.die "--ui-hint cannot be combined with plugin options"
fi

# UI hint mode
if [[ ${ui_hint} -eq 1 ]]; then
    print_ui_hint "${PLUGINS_JSON}"
    exit 0
fi

# Update mode
if [[ -n "${update_path}" ]]; then
    while IFS= read -r ep; do
        execute_entrypoint "${ep}" update_func "${update_path}"
    done < <(jq -r '.[].entrypoint' <<<"${PLUGINS_JSON}")
    exit 0
fi

# Normal execution
for ep in "${selected_entrypoints[@]}"; do
    # Get the JSON data from a plugin and append `origin` with a plugin icon
    # to all entries
    execute_entrypoint "${ep}" run_func \
      | jq --arg icon "${ENTRYPOINT_TO_ICON[${ep}]}" '. | map(. + {origin: $icon})'
done
