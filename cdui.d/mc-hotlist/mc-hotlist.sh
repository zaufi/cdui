#!/bin/sh
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

#
# Return the configured Midnight Commander hotlist file path.
#
function _cdui.mc_hotlist_file()
{
    echo "${CDUI_MC_HOTLIST:-${XDG_CONFIG_HOME:-${HOME}/.config}/mc/hotlist}"
}

#
# Return the path to the AWK converter used for hotlist-to-JSON transformation.
#
function _cdui.mc_hotlist_converter()
{
    # Directory of the current script (even when sourced)
    local -r script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "${script_dir}/hotlist2json.awk"
}

#
# Return the cache file path for the converted hotlist JSON.
#
function _cdui.mc_hotlist_cache_file()
{
    echo "$(cdui.cache.dir)"/mc-hotlist.json
}

#
# Rebuild the hotlist JSON cache when the source file or converter changes.
#
function _cdui.mc_hotlist_refresh_cache()
{
    local -r hotlist=$(_cdui.mc_hotlist_file)
    if [[ ! -r ${hotlist} ]]; then
        printf 'cdui: hotlist file is not readable: %s\n' "${hotlist}" >&2
        return 1
    fi

    local -r converter=$(_cdui.mc_hotlist_converter)
    if [[ ! -r ${converter} ]]; then
        printf 'cdui: converter is not readable: %s\n' "${converter}" >&2
        return 1
    fi

    local -r cache_dir=$(cdui.cache.dir)
    local -r cache_file=$(_cdui.mc_hotlist_cache_file)
    mkdir -p -- "${cache_dir}"

    if [[ ! -e ${cache_file} || ${hotlist} -nt ${cache_file} || ${converter} -nt ${cache_file} ]]; then
        local tmp_file
        tmp_file=$(mktemp "${cache_file}.XXXXXX") || return
        if ! awk -f "${converter}" "${hotlist}" > "${tmp_file}"; then
            rm -f -- "${tmp_file}"
            return 1
        fi
        mv -f -- "${tmp_file}" "${cache_file}"
    fi

    echo "${cache_file}"
}

#
# Return the Midnight Commander hotlist as a JSON array for the CDUI feed.
#
function cdui.mc_hotlist.get_dirs()
{
    local -r cache_file=$(_cdui.mc_hotlist_cache_file)

    if [[ ! -r ${cache_file} ]]; then
        _cdui.mc_hotlist_refresh_cache || {
            printf '[]\n'
            return 0
        }
    elif [[ "$(_cdui.mc_hotlist_file)" -nt ${cache_file} ]]; then
        _cdui.mc_hotlist_refresh_cache || {
            printf '[]\n'
            return 0
        }
    fi

    cat "${cache_file}"
}
