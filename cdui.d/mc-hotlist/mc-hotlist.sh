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
    local -r hotlist_file="$(_cdui.mc_hotlist_file)"
    echo "$(cdui.cache.dir)"/"${hotlist_file//[^[:alnum:]_-]/_}".json
}

#
# Rebuild the hotlist JSON cache when the source file or converter changes.
#
function _cdui.mc_hotlist_ensure_fresh_cache()
{
    local -r converter=$(_cdui.mc_hotlist_converter)
    if [[ ! -r ${converter} ]]; then
        # NOTE Broken installation!?
        cdui.die "converter is not readable: ${converter}"
    fi

    local -r cache_dir=$(cdui.cache.dir)
    mkdir -p -- "${cache_dir}"

    local -r cache_file=$(_cdui.mc_hotlist_cache_file)
    local -r hotlist=$(_cdui.mc_hotlist_file)
    if [[
        -r ${hotlist}
     && -s ${cache_file}
     && ! ${hotlist} -nt ${cache_file}
     && ! ${converter} -nt ${cache_file}
     ]]; then
        return
    fi

    local tmp_file
    # NOTE The only case when this function can fail
    # TODO How to handle this properly? :-()
    tmp_file=$(mktemp "${cache_file}.XXXXXX") || return 1

    if [[ ! ( -f ${hotlist} && -r ${hotlist} ) ]]; then
        cdui.mkentry error "hotlist file is missed or not readable: ${hotlist}" >"${tmp_file}"
    else
        if ! awk -f "${converter}" "${hotlist}" > "${tmp_file}"; then
            # NOTE Smth terribly wrong with conversion script %-)
            # Shouldn't happen normally ;-)
            cdui.mkentry error "error on converting: ${hotlist}" >"${tmp_file}"
        fi
    fi
    mv -f -- "${tmp_file}" "${cache_file}"
}

#
# Return the Midnight Commander hotlist as a JSON array for the CDUI feed.
#
function cdui.mc_hotlist.get_dirs()
{
    _cdui.mc_hotlist_ensure_fresh_cache
    cat "$(_cdui.mc_hotlist_cache_file)"
}
