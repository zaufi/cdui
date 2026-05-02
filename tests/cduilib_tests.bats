# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    TEST_DIR="$( cd "$( dirname "$BATS_TEST_FILENAME" )" >/dev/null 2>&1 && pwd )"
    # shellcheck source=cduilib.sh
    . "${TEST_DIR}"/../cduilib.sh
}

@test 'parse color string' {
    empty=$(cdui_color2numbers 'invalid #color rgb(string)')
    assert_equal "${empty}" ''

    red=$(cdui_color2numbers 'red')
    assert_equal "${red}" '31'

    fg_red=$(cdui_color2numbers ' fg:red')
    assert_equal "${fg_red}" '31'

    bg_red=$(cdui_color2numbers 'bg:red')
    assert_equal "${bg_red}" '41'

    bright_red=$(cdui_color2numbers 'bright_red')
    assert_equal "${bright_red}" '91'

    fg_bright_red=$(cdui_color2numbers 'fg:bright_red')
    assert_equal "${fg_bright_red}" '91'

    bg_bright_red=$(cdui_color2numbers 'bg:bright_red')
    assert_equal "${bg_bright_red}" '101'

    bold_red=$(cdui_color2numbers 'bold red')
    assert_equal "${bold_red}" '1;31'

    red_bold=$(cdui_color2numbers 'red bold ')
    assert_equal "${red_bold}" '31;1'

    rgb_red=$(cdui_color2numbers ' #ff0000 ')
    assert_equal "${rgb_red}" '38;2;255;0;0'

    bg_rgb_red=$(cdui_color2numbers 'bg:#ff0000')
    assert_equal "${bg_rgb_red}" '48;2;255;0;0'

    bold_rgb_red=$(cdui_color2numbers 'bold #ff0000')
    assert_equal "${bold_rgb_red}" '1;38;2;255;0;0'

    rgb_red_italic=$(cdui_color2numbers 'rgb(255,0,0)' italic)
    assert_equal "${rgb_red_italic}" '38;2;255;0;0;3'

    bg_rgb_red=$(cdui_color2numbers 'bg:rgb(255,0,0)')
    assert_equal "${bg_rgb_red}" '48;2;255;0;0'
}

@test 'print color string' {
    empty=$(cdui_color2ansi 'invalid #color rgb(string)')
    assert_equal "${empty}" ''

    red=$(cdui_color2ansi 'red')
    assert_equal "${red}" $'\033[31m'

    intro=$(printf '%s%s%s' "$(cdui_color2ansi red)" "Hello Africa!" "$(cdui_color2ansi reset)")
    assert_equal "${intro}" $'\033[31mHello Africa!\033[0m'
}

# kate: hl bash;
