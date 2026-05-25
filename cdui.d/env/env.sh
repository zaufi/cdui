#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Resolve a shell-style home-relative path into an absolute directory path.
#
# @param $1 -- path to normalize
#
function _cdui.env.resolve_path()
{
    local -r _path="$1"

    # shellcheck disable=SC2088
    case "${_path}" in
        '~')
            printf '%s\n' "${HOME}"
            ;;
        '~/'*)
            printf '%s/%s\n' "${HOME}" "${_path:2}"
            ;;
        *)
            printf '%s\n' "${_path}"
            ;;
    esac
}

#
# Check whether a value looks like a directory path.
#
# @param $1 -- value to inspect
#
function _cdui.env.looks_like_path()
{
    local -r _path="$1"

    [[ -n ${_path} && ${_path} != '.' ]] || return 1
    [[ ${_path} =~ ^[A-Za-z][A-Za-z0-9+.-]*: ]] && return 1
    [[ ${_path} == //* ]] && return 1
    [[ ${_path} == /* || ${_path} == ~ || ${_path} == ~/* ]]
}

#
# Check whether a resolved path should be kept in the feed.
#
# Keep existing directories and missing paths, but drop existing non-directories.
#
# @param $1 -- resolved path to inspect
#
function _cdui.env.is_directory_or_missing()
{
    local -r _path="$1"

    [[ ! -e ${_path} || -d ${_path} ]]
}

#
# Return the environment-directory list as a JSON array for the CDUI feed.
#
function cdui.env.get_dirs()
{
    local _var_name
    local -a _items=()

    while IFS= read -r _var_name; do
        [[ ${_var_name} == PWD ]] && continue
        # Some variables definitely don't contain paths...
        # TODO Add more patterns to speedup the process a little
        [[ ${_var_name} == *FILE ]] && continue
        [[ ${_var_name} == *CONFIG ]] && continue
        [[ ${_var_name} == *_COLORS ]] && continue

        local _value="${!_var_name-}"
        [[ -z ${_value} ]] && continue
        # Check if variable value starts with some URL schema
        [[ ${_value} =~ ^[A-Za-z]*: ]] && continue

        local _delimiter=''
        if [[ ${_value} == *:* ]]; then
            _delimiter=':'
        elif [[ ${_value} == *' '* ]]; then
            # Some env vars use space-separated path lists, e.g. CONFIG_PROTECT_MASK.
            _delimiter=' '
        fi

        if [[ -n ${_delimiter} ]]; then
            local -a _parts=()
            local IFS="${_delimiter}"
            read -r -a _parts <<< "${_value}"

            local _index
            for _index in "${!_parts[@]}"; do
                local _path="${_parts[${_index}]}"
                _cdui.env.looks_like_path "${_path}" || continue

                local _resolved_path
                _resolved_path=$(_cdui.env.resolve_path "${_path}")
                _cdui.env.is_directory_or_missing "${_resolved_path}" || continue
                _items+=( "$(cdui.mkentry "\$${_var_name}[${_index}]" "${_resolved_path}")" )
            done
            continue
        fi

        _cdui.env.looks_like_path "${_value}" || continue
        local _resolved_value
        _resolved_value=$(_cdui.env.resolve_path "${_value}")
        _cdui.env.is_directory_or_missing "${_resolved_value}" || continue
        _items+=( "$(cdui.mkentry "\$${_var_name}" "${_resolved_value}")" )
    done < <(compgen -e | sort -u)

    if ((${#_items[@]} == 0)); then
        printf '[]\n'
        return 0
    fi

    printf '%s\n' "${_items[@]}" | jq -s add
}
