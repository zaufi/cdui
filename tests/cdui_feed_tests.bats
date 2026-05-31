# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert
    bats_load_library bats-file

    export HOME="${BATS_FILE_TMPDIR}"/"${BATS_TEST_NAME}"/home
    mkdir -p "${HOME}"

    export XDG_CONFIG_HOME="${HOME}"/xdg-config
    mkdir -p "${XDG_CONFIG_HOME}"/cdui

    export XDG_CACHE_HOME="${HOME}"/xdg-cache
    mkdir -p "${XDG_CACHE_HOME}"/cdui

    export CDUI_PLUGIN_DIR="${BATS_FILE_TMPDIR}"/plugins4test
    cp --reflink=auto -r "${BATS_TEST_DIRNAME}"/plugins4test "${BATS_FILE_TMPDIR}"

    export TERM=dumb
    export NO_COLOR=1
}

@test 'cdui-feed handle unknown short option' {
    ls -la
    run bash cdui-feed.sh -u
    assert_failure
    assert_output --partial 'Unknown option: -u'
}

@test 'cdui-feed handle unknown long option' {
    run bash cdui-feed.sh --unknown
    assert_failure
    assert_output --partial 'Unknown option: --unknown'
}

@test 'cdui-feed can find a plugin installed' {
    run bash cdui-feed.sh --help
    assert_success
    assert_output --partial 'Unit test plugin'
}

@test 'cdui-feed can get a hotkey from test plugin ' {
    run bash cdui-feed.sh --ui-hint
    assert_success
    assert_output --partial 'CTRL-U'
}

@test 'cdui-feed can use a plugin installed' {
    run bash cdui-feed.sh -s
    assert_success

    test_json="${output}"

    run jq -r '.[0].entry' <<<"${test_json}"
    assert_output unit

    run jq -r '.[0].url' <<<"${test_json}"
    assert_output /test

    run jq -r '.[0].origin' <<<"${test_json}"
    assert_output '🔧'
}

@test '_cdui.feed marks missing URLs with missed URL color' {
    unset NO_COLOR
    export TERM=xterm-256color
    export CDUI_UNIT_TEST_URL="${BATS_FILE_TMPDIR}"/missing-dir
    cat >"${XDG_CONFIG_HOME}"/cdui/config.yaml <<EOF
color:
  url: green
  missed-url: red italic strike
EOF

    run bash -c '. ./cdui.sh; _cdui.feed "$1"' this-is-arg0 -s

    assert_success
    assert_output --partial $'\033[31;3;9m'"${CDUI_UNIT_TEST_URL}"$'\033[0m'
}

@test 'cdui-feed help screen shows disabled plugin' {
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/disabled-all-config.yaml "${XDG_CONFIG_HOME}"/cdui/config.yaml

    run bash cdui-feed.sh
    assert_success
    assert_output --partial 'disabled via user config'
}

@test 'cdui-feed no UI hint for disabled plugin' {
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/disabled-all-config.yaml "${XDG_CONFIG_HOME}"/cdui/config.yaml

    run bash cdui-feed.sh --ui-hint
    assert_success
    assert_output '[]'
}

@test 'cdui-feed disabled plugin test' {
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/disabled-all-config.yaml "${XDG_CONFIG_HOME}"/cdui/config.yaml

    run bash cdui-feed.sh -s
    assert_failure
    assert_output --partial "Requested plugin is disabled via user's configuration"
}

# kate: hl bash;
