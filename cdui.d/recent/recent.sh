#!/bin/bash
#
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later
#

declare -Ag _CDUI_RECENT_DIRS_STATS=()

#
# Get the number of recent directories to keep in the JSON cache.
#
function _cdui.recent.dirs_count()
{
    if [[ ${CDUI_RECENT_DIRS_COUNT:-} =~ ^[0-9]+$ ]]; then
        echo "${CDUI_RECENT_DIRS_COUNT}"
        return 0
    fi

    echo 25
}

#
# Return the bash cache file path with recent-directory usage statistics.
#
function _cdui.recent.stats_file()
{
    echo "$(cdui.cache.dir)"/recent-dirs.bash
}

#
# Load recent-directory usage statistics from the bash cache file.
#
function _cdui.recent.load_dirs_stats()
{
    local -r stats_file=$(_cdui.recent.stats_file)

    _CDUI_RECENT_DIRS_STATS=()
    if [[ -r ${stats_file} ]]; then
        # shellcheck source=/dev/null
        . "${stats_file}"
    fi
}

#
# Save recent-directory usage statistics to the bash cache file.
#
function _cdui.save_recent_dirs_stats()
{
    mkdir -p -- "$(cdui.cache.dir)"

    local -r stats_file=$(_cdui.recent.stats_file)
    local tmp_file
    tmp_file=$(mktemp "${stats_file}.XXXXXX") || return 1

    local declaration
    declaration=$(declare -p _CDUI_RECENT_DIRS_STATS) || {
        rm -f -- "${tmp_file}"
        return 1
    }
    printf '%s\n' "${declaration/declare -A/declare -gA}" > "${tmp_file}" || {
        rm -f -- "${tmp_file}"
        return 1
    }
    mv -f -- "${tmp_file}" "${stats_file}"
}

#
# Print a JSON array with the configured number of most recent directories.
#
function _cdui.recent.build_dirs_json()
{
    local -r recent_dirs_count=$(_cdui.recent.dirs_count)
    local _dir _count _timestamp

    {
        for _dir in "${!_CDUI_RECENT_DIRS_STATS[@]}"; do
            read -r _count _timestamp <<< "${_CDUI_RECENT_DIRS_STATS["${_dir}"]}"
            printf '%s\t%s\t%s\n' "${_count:-0}" "${_timestamp:-0}" "${_dir}"
        done
    } | sort -t $'\t' -k2,2nr -k1,1nr \
      | head -n "${recent_dirs_count}" \
      | jq -R -s '
            split("\n")
          | map(select(length > 0))
          | map(split("\t"))
          | map({entry: .[1], url: .[2]})
        '
}

#
# Return the recent directories list as a JSON array for the CDUI feed.
#
function cdui.recent.get_dirs()
{
    _cdui.recent.load_dirs_stats
    _cdui.recent.build_dirs_json | jq '. | map(. + {origin: "🔁"})'
}

#
# Update usage statistics for a selected directory.
#
# @param $1 -- directory name to update in the recent-directory cache
#
function cdui.recent.post_select_dir()
{
    local -r dir_name="$1"

    if [[ -z ${dir_name} || ! -d ${dir_name} ]]; then
        return 0
    fi

    _cdui.recent.load_dirs_stats

    local -i count=0
    local _timestamp
    if [[ -n ${_CDUI_RECENT_DIRS_STATS["${dir_name}"]+x} ]]; then
        read -r count _timestamp <<< "${_CDUI_RECENT_DIRS_STATS["${dir_name}"]}"
    fi

    _CDUI_RECENT_DIRS_STATS["${dir_name}"]="$((count + 1)) $(date +%s)"
    _cdui.save_recent_dirs_stats
}
