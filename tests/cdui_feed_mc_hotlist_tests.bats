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

    export TERM=dumb
    export NO_COLOR=1
}

@test 'mc-hotlist no data -> error output' {
    CDUI_MC_HOTLIST="${XDG_CONFIG_HOME}"/mc/missed-hotlist-file \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].error'
    assert_success
    assert_output --partial 'hotlist file is missed or not readable:'
}

@test 'mc-hotlist broken data -> empty output' {
    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-broken-hotlist \
    run bats_pipe bash cdui-feed.sh -m \| jq '.'
    assert_success
    assert_output '[]'
}

@test 'mc-hotlist make cache' {
    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-hotlist \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'
}

@test 'mc-hotlist keeps valid cache on repeated reads' {
    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-hotlist \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-hotlist \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'
}

@test 'mc-hotlist updates cache on repeated reads' {
    local -rx CDUI_MC_HOTLIST="${XDG_CONFIG_HOME}"/test-hotlist
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-hotlist "${XDG_CONFIG_HOME}"

    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    # Override the hotlist file with another one containing more entries.
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-dua-hotlist "${XDG_CONFIG_HOME}"/test-hotlist
    touch -m -d '+1 minute' "${CDUI_MC_HOTLIST}"

    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output $'Unit Test: /unit-test\nAdded entry: /unit-test-added'
}

@test 'mc-hotlist can have groups' {
    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-grouped-hotlist \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'
}

@test 'mc-hotlist reload path uses user URL colors' {
    unset NO_COLOR
    export TERM=xterm-256color
    cat >"${XDG_CONFIG_HOME}"/cdui/config.yaml <<EOF
color:
  url: green italic
EOF

    CDUI_MC_HOTLIST="${BATS_TEST_DIRNAME}"/test-hotlist \
    run bash -c '. ./cdui.sh; _cdui.feed "$1"' this-is-arg0 -m

    assert_success
    assert_output --partial $'\033[32;3m/unit-test\033[0m'
}

# kate: hl bash;
