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

    # NOTE CTest will run this from the CMake's build directory
    # with rendered `cduilib.sh`
    if [[ -f cduilib.sh ]]; then
        # shellcheck source=/dev/null
        . cduilib.sh
    else
        # Otherwise, use the partial file from the source directory
        # shellcheck source=/dev/null
        . "${BATS_TEST_DIRNAME}"/../build/cduilib.sh
    fi
}

@test 'parse color string' {
    empty=$(cdui.color2numbers 'invalid #color rgb(string)')
    assert_equal "${empty}" ''

    red=$(cdui.color2numbers 'red')
    assert_equal "${red}" '31'

    fg_red=$(cdui.color2numbers ' fg:red')
    assert_equal "${fg_red}" '31'

    bg_red=$(cdui.color2numbers 'bg:red')
    assert_equal "${bg_red}" '41'

    bright_red=$(cdui.color2numbers 'bright_red')
    assert_equal "${bright_red}" '91'

    fg_bright_red=$(cdui.color2numbers 'fg:bright_red')
    assert_equal "${fg_bright_red}" '91'

    bg_bright_red=$(cdui.color2numbers 'bg:bright_red')
    assert_equal "${bg_bright_red}" '101'

    bold_red=$(cdui.color2numbers 'bold red')
    assert_equal "${bold_red}" '1;31'

    red_bold=$(cdui.color2numbers 'red bold ')
    assert_equal "${red_bold}" '31;1'

    rgb_red=$(cdui.color2numbers ' #ff0000 ')
    assert_equal "${rgb_red}" '38;2;255;0;0'

    bg_rgb_red=$(cdui.color2numbers 'bg:#ff0000')
    assert_equal "${bg_rgb_red}" '48;2;255;0;0'

    bold_rgb_red=$(cdui.color2numbers 'bold #ff0000')
    assert_equal "${bold_rgb_red}" '1;38;2;255;0;0'

    rgb_red_italic=$(cdui.color2numbers 'rgb(255,0,0)' italic)
    assert_equal "${rgb_red_italic}" '38;2;255;0;0;3'

    bg_rgb_red=$(cdui.color2numbers 'bg:rgb(255,0,0)')
    assert_equal "${bg_rgb_red}" '48;2;255;0;0'
}

@test 'print color string' {
    empty=$(cdui.color2ansi 'invalid #color rgb(string)')
    assert_equal "${empty}" ''

    red=$(cdui.color2ansi 'red')
    assert_equal "${red}" $'\033[31m'

    intro=$(printf '%s%s%s' "$(cdui.color2ansi red)" "Hello Africa!" "$(cdui.color2ansi reset)")
    assert_equal "${intro}" $'\033[31mHello Africa!\033[0m'
}

@test 'cdui.config.dir uses XDG_CONFIG_HOME' {
    config_dir="$(cdui.config.dir)"
    assert_equal "${config_dir}" "${XDG_CONFIG_HOME}"/cdui
}

@test 'cdui.config.file returns config filename' {
    config_file="$(cdui.config.file)"
    assert_equal "${config_file}" "${XDG_CONFIG_HOME}"/cdui/config.yaml
}

@test 'cdui.cache.dir uses XDG_CACHE_HOME' {
    cache_dir="$(cdui.cache.dir)"
    assert_equal "${cache_dir}" "${XDG_CACHE_HOME}"/cdui
}

@test 'cdui.cache.config_file returns cache filename' {
    cache_file="$(cdui.cache.config_file)"
    assert_equal "${cache_file}" "${XDG_CACHE_HOME}"/cdui/cdui-config.sh
}

@test 'cdui.config.load defines empty CONFIG when config.yaml is missing' {
    # Ensure config does not exist
    rm -f "$(cdui.config.file)"

    unset CONFIG

    cdui.config.load

    # CONFIG must exist
    declare -p CONFIG >/dev/null

    # Must be associative array
    assert_equal "$(declare -p CONFIG)" 'declare -A CONFIG=()'

    # Must be empty
    assert [ "${#CONFIG[@]}" -eq 0 ]
}

@test 'cdui.config.load loads YAML into CONFIG associative array' {
    cp -f --reflink=auto "${BATS_TEST_DIRNAME}"/sample-config.yaml "$(cdui.config.file)"

    cdui.config.load

    # Checking config data
    assert_equal "${CONFIG[colors.url]}" 'cyan italic'
    assert_equal "${CONFIG[plugins.env.enable]}" true
    assert_equal "${CONFIG[plugins.env.order]}" 4

    # Checking cache file
    cache_file="$(cdui.cache.config_file)"
    assert_file_exists "${cache_file}"
    assert_file_contains "${cache_file}" 'CONFIG='

    # Checking reloading the config reuses the cache
    before="$(stat -c %Y "${cache_file}")"
    unset CONFIG

    sleep 1  # NOTE Make sure the updated file get not the same modified time
    cdui.config.load

    assert_file_exists "${cache_file}"

    after="$(stat -c %Y "${cache_file}")"
    assert_equal "${before}" "${after}"

    # Checking that loader regenerates the cache if config has changed
    echo 'foo: bar' >>"$(cdui.config.file)"
    CONFIG[colors.url]='will be restored after reload'

    sleep 1  # NOTE Make sure the updated file get not the same modified time
    cdui.config.load

    # Recheck data
    assert_equal "${CONFIG[colors.url]}" 'cyan italic'
    assert_equal "${CONFIG[foo]}" bar

    after_after="$(stat -c %Y "${cache_file}")"
    assert_not_equal "${before}" "${after_after}"
    assert_not_equal "${after}" "${after_after}"
}

# kate: hl bash;
