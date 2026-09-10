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
    local -r hotlist="${BATS_TEST_DIRNAME}"/test-hotlist
    local -r cache_file="${XDG_CACHE_HOME}"/cdui/"${hotlist//[^[:alnum:]_-]/_}".json

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    assert_file_exists "${cache_file}"
    assert_file_exists "${cache_file}".stamp
    local -r before=$(stat -c '%y' "${cache_file}")

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    # The cache is still valid, so it must not be rebuilt
    assert_equal "$(stat -c '%y' "${cache_file}")" "${before}"
}

@test 'mc-hotlist updates cache on repeated reads' {
    local -r hotlist="${XDG_CONFIG_HOME}"/test-hotlist
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-hotlist "${hotlist}"

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    # Override the hotlist file with another one containing more entries.
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-dua-hotlist "${hotlist}"

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output $'Unit Test: /unit-test\nAdded entry: /unit-test-added'
}

@test 'mc-hotlist updates cache when the hotlist mtime goes backwards' {
    local -r hotlist="${XDG_CONFIG_HOME}"/test-hotlist
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-hotlist "${hotlist}"

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    # Modify the hotlist the way its modification time doesn't move forward,
    # like restoring a backup or copying a file with timestamps preserved do.
    cp --reflink=auto -vf "${BATS_TEST_DIRNAME}"/test-dua-hotlist "${hotlist}"
    touch -m -d '-1 hour' "${hotlist}"

    CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[] | .entry + ": " + .url'
    assert_success
    assert_output $'Unit Test: /unit-test\nAdded entry: /unit-test-added'
}

@test 'mc-hotlist updates cache when the converter has changed' {
    local -r plugin_dir="${BATS_TEST_TMPDIR}"/cdui.d
    cp -RL --reflink=auto -f ./cdui.d "${plugin_dir}"

    local -r hotlist="${BATS_TEST_DIRNAME}"/test-hotlist
    local -r cache_file="${XDG_CACHE_HOME}"/cdui/"${hotlist//[^[:alnum:]_-]/_}".json

    CDUI_PLUGIN_DIR="${plugin_dir}" CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    local -r before=$(cat "${cache_file}".stamp)

    touch -m "${plugin_dir}"/mc-hotlist/hotlist2json.awk

    CDUI_PLUGIN_DIR="${plugin_dir}" CDUI_MC_HOTLIST="${hotlist}" \
    run bats_pipe bash cdui-feed.sh -m \| jq -r '.[0].entry + ": " + .[0].url'
    assert_success
    assert_output 'Unit Test: /unit-test'

    assert_not_equal "$(cat "${cache_file}".stamp)" "${before}"
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
    mkdir -p "${BATS_TEST_TMPDIR}"/unit-test
    cat >"${XDG_CONFIG_HOME}"/test-hotlist <<EOF
ENTRY "Unit Test" URL "${BATS_TEST_TMPDIR}/unit-test"
EOF
    cat >"${XDG_CONFIG_HOME}"/cdui/config.yaml <<EOF
color:
  url: green italic
EOF

    CDUI_MC_HOTLIST="${XDG_CONFIG_HOME}"/test-hotlist \
    run bash -c '. ./cdui.sh; _cdui.feed "$1"' this-is-arg0 -m

    assert_success
    assert_output --partial $'\033[32;3m'"${BATS_TEST_TMPDIR}"'/unit-test'$'\033[0m'
}

# kate: hl bash;
