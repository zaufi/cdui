#!/bin/env bash
# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

function cdui_color2numbers()
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

function cdui_color2ansi()
{
    local codes
    codes=$(cdui_color2numbers "$@")
    if [[ -n ${codes} ]]; then
        printf '\033[%sm' "${codes}"
    fi
}
