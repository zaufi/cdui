# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export HOME="${BATS_FILE_TMPDIR}"/home
    mkdir -p "${HOME}"

    export XDG_CONFIG_HOME="${HOME}"/xdg-config
    mkdir -p "${XDG_CONFIG_HOME}"/cdui

    export XDG_CACHE_HOME="${HOME}"/xdg-cache
    mkdir -p "${XDG_CACHE_HOME}"/cdui

    # shellcheck source=/dev/null
    . "${BATS_TEST_DIRNAME}"/../build/cduilib.sh
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

@test 'cdui_config_dir uses XDG_CONFIG_HOME' {
    config_dir="$(cdui_config_dir)"
    assert_equal "${config_dir}" "${XDG_CONFIG_HOME}"/cdui
}

@test 'cdui_config_file returns config filename' {
    config_file="$(cdui_config_file)"
    assert_equal "${config_file}" "${XDG_CONFIG_HOME}"/cdui/config.yaml
}

@test 'cdui_cache_dir uses XDG_CACHE_HOME' {
    cache_dir="$(cdui_cache_dir)"
    assert_equal "${cache_dir}" "${XDG_CACHE_HOME}"/cdui
}

@test 'cdui_cache_config_file returns cache filename' {
    cache_file="$(cdui_cache_config_file)"
    assert_equal "${cache_file}" "${XDG_CACHE_HOME}"/cdui/cdui-config.sh
}

@test 'cdui_load_config defines empty CONFIG when config.yaml is missing' {
    # Ensure config does not exist
    rm -f "$(cdui_config_file)"

    unset CONFIG

    cdui_load_config

    # CONFIG must exist
    declare -p CONFIG >/dev/null

    # Must be associative array
    assert_equal "$(declare -p CONFIG)" 'declare -A CONFIG=()'

    # Must be empty
    assert [ "${#CONFIG[@]}" -eq 0 ]
}

@test 'cdui_load_config loads YAML into CONFIG associative array' {
    cp -f --reflink=auto "${BATS_TEST_DIRNAME}"/sample-config.yaml "$(cdui_config_file)"

    cdui_load_config

    # Checking config data
    assert_equal "${CONFIG[colors.url]}" 'cyan italic'
    assert_equal "${CONFIG[plugins.env.enable]}" true
    assert_equal "${CONFIG[plugins.env.order]}" 4

    # Checking cache file
    cache_file="$(cdui_cache_config_file)"
    assert_file_exists "${cache_file}"
    assert_file_contains "${cache_file}" 'CONFIG='

    # Checking reloading the config reuses the cache
    before="$(stat -c %Y "${cache_file}")"
    unset CONFIG

    sleep 1  # NOTE Make sure the updated file get not the same modified time
    cdui_load_config

    assert_file_exists "${cache_file}"

    after="$(stat -c %Y "${cache_file}")"
    assert_equal "${before}" "${after}"

    # Checking that loader regenerates the cache if config has changed
    echo 'foo: bar' >>"$(cdui_config_file)"
    CONFIG[colors.url]='will be restored after reload'

    sleep 1  # NOTE Make sure the updated file get not the same modified time
    cdui_load_config

    # Recheck data
    assert_equal "${CONFIG[colors.url]}" 'cyan italic'
    assert_equal "${CONFIG[foo]}" bar

    after_after="$(stat -c %Y "${cache_file}")"
    assert_not_equal "${before}" "${after_after}"
    assert_not_equal "${after}" "${after_after}"
}

# kate: hl bash;
