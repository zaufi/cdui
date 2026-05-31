#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

declare -x _cdui_on_trace
if [[ $- == *x* ]]; then
    _cdui_on_trace='-x'
fi

# shellcheck disable=SC2155
declare -r _CDUI_SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f ${_CDUI_SCRIPT_DIR}/cduilib.sh ]]; then
    # shellcheck source=./cduilib.sh
    . "${_CDUI_SCRIPT_DIR}"/cduilib.sh
else
    die "Missed file: ${_CDUI_SCRIPT_DIR}/cduilib.sh"
fi

declare -x _CDUI_FEED_SCRIPT="${_CDUI_SCRIPT_DIR}"/cdui-feed.sh
if [[ ! -f ${_CDUI_FEED_SCRIPT} ]]; then
    die "Missed file: ${_CDUI_FEED_SCRIPT}"
fi

# BEGIN Internal helper functions
function _cdui.hotkey_to_skim_bind_key()
{
    local -r _hotkey="$1"
    echo "${_hotkey,,}" | tr '+' '-'
}
export -f _cdui.hotkey_to_skim_bind_key

function _cdui.get_ui_hints()
{
    # shellcheck disable=SC2086,SC2154
    bash ${_cdui_on_trace} "${_CDUI_FEED_SCRIPT}" --ui-hint | jq -s 'add // []'
}
export -f _cdui.get_ui_hints

function _cdui.feed()
{
    local -r _cli_option="$1"

    cdui.config.load

    # shellcheck disable=SC2086,SC2154
    bash ${_cdui_on_trace} "${_CDUI_FEED_SCRIPT}" "${_cli_option}" \
      | jq \
            --arg pwd "${PWD}" \
            --arg home "${HOME}" \
            --arg current_url_color "$(cdui.config.color.current_url)" \
            --arg missed_url_color "$(cdui.config.color.missed_url)" \
            --arg url_color_prefix "$(cdui.config.color.url)" \
            --arg reset_color "$(cdui.color2ansi reset)" \
            -ref "${_CDUI_SCRIPT_DIR}"/cdui-format-table.jq
}
export -f _cdui.feed

function _cdui.make_header()
{
    local _header=
    local _part

    for _part in "${_cdui_header_parts[@]}"; do
        if [[ -n ${_header} ]]; then
            _header+=' · '
        fi
        _header+="${_part}"
    done

    printf '%s\n' "${_header}"
}
export -f _cdui.make_header
# END Internal helper functions

declare -a _cdui_reload_bindings=()
declare -a _cdui_header_parts=()
function cdui()
{
    cdui.config.load

    _cdui_reload_bindings=()
    _cdui_header_parts=()
    # What to show first, comes first in the `cdui-feed.sh --ui-hint` output.
    _cdui_initial_cli_option=

    while IFS=$'\t' read -r _hotkey _text _cli_option; do
        # All components are mandatory!
        if [[ -z ${_hotkey} || -z ${_text} || -z ${_cli_option} ]]; then
            continue
        fi

        if [[ -z ${_cdui_initial_cli_option} ]]; then
            _cdui_initial_cli_option=${_cli_option}
        fi

        _cdui_reload_bindings+=("--bind=$(_cdui.hotkey_to_skim_bind_key "${_hotkey}"):reload(bash -c '. \"${_CDUI_SCRIPT_DIR}/cdui.sh\"; _cdui.feed \"\$1\"' bash '${_cli_option}')")
        _cdui_header_parts+=("$(cdui.text.to_squarefilled "${_hotkey}") $(cdui.text.to_small_caps "${_text}")")
    done < <(_cdui.get_ui_hints | jq -r '.[] | [.hotkey, .description, .cli_option] | @tsv')

    # TODO Check `_cdui_initial_cli_option`. If it's empty, there's really nothing to show and select.

    local _selected_dir
    _selected_dir=$(
        # shellcheck disable=SC2154
        _cdui.feed "${_cdui_initial_cli_option}" \
          | sk \
                --ansi \
                --delimiter $'\t' \
                --with-nth 1,2,3 \
                --prompt='📁 Select a directory to jump into〉' \
                --border="$(cdui.config.border)" \
                "${_cdui_reload_bindings[@]}" \
                --header "$(_cdui.make_header)" \
          | cut -f4
      )

    if [[ -n ${_selected_dir} && ${_selected_dir} != "${PWD}" ]]; then
        # shellcheck disable=SC2086
        bash ${_cdui_on_trace} "${_CDUI_FEED_SCRIPT}" --update "${_selected_dir}"
        pushd "${_selected_dir}" >/dev/null 2>&1 || return
    fi
}
export -f cdui

if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    cdui
fi
