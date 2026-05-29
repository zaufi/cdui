#!/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

# BEGIN Color string parser
function cdui.color2numbers()
{
    # style mappings
    declare -Ar style_map=(
        [bold]=1
        [dim]=2
        [italic]=3
        [underscore]=4
        [blink]=5
        [reverse]=7
        [strike]=9
        [underline]=21
        [noreverse]=27
        [reset]=0
    )

    # 16-color ANSI map
    declare -Ar color_map=(
        [black]=0
        [red]=1
        [green]=2
        [yellow]=3
        [blue]=4
        [magenta]=5
        [cyan]=6
        [white]=7
        [bright_black]=8
        [bright_red]=9
        [bright_green]=10
        [bright_yellow]=11
        [bright_blue]=12
        [bright_magenta]=13
        [bright_cyan]=14
        [bright_white]=15
    )

    local input="$*"
    local -a codes=()
    for token in ${input}; do
        # styles
        if [[ -n "${style_map[$token]}" ]]; then
            codes+=("${style_map[$token]}")
            continue
        fi

        local mode='fg'
        if [[ "${token}" == bg:* ]]; then
            mode='bg'
            token="${token#bg:}"
        elif [[ "${token}" == fg:* ]]; then
            token="${token#fg:}"
        fi

        # HEX color
        if [[ "${token}" =~ ^#([0-9a-fA-F]{6})$ ]]; then
            local hex="${BASH_REMATCH[1]}"
            local -i r=$((16#${hex:0:2}))
            local -i g=$((16#${hex:2:2}))
            local -i b=$((16#${hex:4:2}))

            if [[ "${mode}" == fg ]]; then
                codes+=("38;2;${r};${g};${b}")
            else
                codes+=("48;2;${r};${g};${b}")
            fi
            continue
        fi

        # rgb(R,G,B)
        if [[ "${token}" =~ ^rgb\(\ *([0-9]+)\ *,\ *([0-9]+)\ *,\ *([0-9]+)\ *\)$ ]]; then
            local -i r="${BASH_REMATCH[1]}"
            local -i g="${BASH_REMATCH[2]}"
            local -i b="${BASH_REMATCH[3]}"

            if [[ "${mode}" == fg ]]; then
                codes+=("38;2;${r};${g};${b}")
            else
                codes+=("48;2;${r};${g};${b}")
            fi
            continue
        fi

        # named color
        if [[ -n "${color_map[${token}]}" ]]; then
            local idx="${color_map[${token}]}"
            if (( idx < 8 )); then
                if [[ "${mode}" == fg ]]; then
                    codes+=("$((30 + idx))")
                else
                    codes+=("$((40 + idx))")
                fi
            else
                if [[ "${mode}" == fg ]]; then
                    codes+=("$((90 + idx - 8))")
                else
                    codes+=("$((100 + idx - 8))")
                fi
            fi
            continue
        fi
    done

    # join codes with ;
    local IFS=';'
    printf '%s' "${codes[*]}"
}

function cdui.color2ansi()
{
    [[ -z ${NO_COLOR:-} && ${TERM:-} != 'dumb' ]] || return

    local codes
    codes=$(cdui.color2numbers "$@")
    if [[ -n ${codes} ]]; then
        printf '\033[%sm' "${codes}"
    fi
}
# END Color string parser

# BEGIN Config location helpers
function cdui.config.dir()
{
    echo "${XDG_CONFIG_HOME:-${HOME}/.config}"/cdui
}

function cdui.config.file()
{
    echo "$(cdui.config.dir)"/config.yaml
}

function cdui.cache.dir()
{
    echo "${XDG_CACHE_HOME:-${HOME}/.cache}"/cdui
}

function cdui.cache.config_file()
{
    echo "$(cdui.cache.dir)"/cdui-config.bash
}
# END Config location helpers

function cdui.config.load()
{
    local -r config_file="$(cdui.config.file)"
    if [[ ! -f ${config_file} ]]; then
        # No config, nothing to load
        return
    fi

    local -r config_cache_file=$(cdui.cache.config_file)
    if [[ ! -f ${config_cache_file} || ${config_file} -nt ${config_cache_file} ]]; then
        mkdir -p -- "$(cdui.cache.dir)"
        yq eval -o=json '.' "${config_file}" \
          | jq -r '
                paths(type != "object" and type != "array") as $path
              | ($path | map(tostring | gsub("-"; "_")) | join(".")) as $key
              | (getpath($path) | tostring) as $value
              | "function cdui.config.\($key)()\n{\n    "
                  + if ".\($key)." | contains(".color.") then
                      "cdui.color2ansi \($value | @sh)"
                    else
                      "printf '\''%s'\'' \($value | @sh)"
                    end
                  + "\n}\n"
            ' > "${config_cache_file}"
    fi

    # shellcheck source=/dev/null
    . "${config_cache_file}"
}

# BEGIN Error reporting helpers
function cdui.error()
{
    local -r message="${*}"
    printf '💀 %sError: %s%s\n' \
        "$(cdui.config.color.error)" \
        "${message}" \
        "$(cdui.color2ansi reset)" \
        >&2
}

function cdui.die()
{
    cdui.error "${@}"
    if [[ ${_CDUI_DIE_NO_EXIT} -eq 0 ]]; then
        exit 1
    else
        return 1
    fi
}
# END Error reporting helpers

#
# Convert a single entry + path pair into a JSON array item.
#
# @param $1 -- entry label to show
# @param $2 -- directory path used as the entry URL
#
function cdui.mkentry()
{
    local -r _entry="$1"
    local -r _url_or_message="$2"

    if [[ ${_entry} == 'error' ]]; then
        jq -cn --arg entry "${_entry}" --arg message "${_url_or_message}" '[{error: $message}]'
    else
        jq -cn --arg entry "${_entry}" --arg url "${_url_or_message}" '[{entry: $entry, url: $url}]'
    fi
}
