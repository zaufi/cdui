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

seed_recent_stats() {
    local -r stats_file="${XDG_CACHE_HOME}"/cdui/recent-dirs.bash

    printf 'declare -gA _CDUI_RECENT_DIRS_STATS=(\n' >"${stats_file}"
    local spec
    for spec in "$@"; do
        local path count timestamp
        IFS='|' read -r path count timestamp <<<"${spec}"
        printf '  [%q]="%s %s"\n' "${path}" "${count}" "${timestamp}" >>"${stats_file}"
    done
    printf ')\n' >>"${stats_file}"
}

@test 'recent feed keeps 25 entries by default' {
    local -a entries=()
    local -i index
    for ((index = 1; index <= 26; ++index)); do
        entries+=("/tmp/cdui-recent-${index}|1|$((1700000000 + index))")
    done
    seed_recent_stats "${entries[@]}"

    run bats_pipe bash cdui-feed.sh --recent \| jq length
    assert_success
    assert_output 25
}

@test 'recent feed sorts by timestamp, then count' {
    seed_recent_stats \
        '/tmp/older-heavy|99|1700000000' \
        '/tmp/newer-light|1|1700000100' \
        '/tmp/same-time-low|1|1700000050' \
        '/tmp/same-time-high|7|1700000050'

    run bats_pipe bash cdui-feed.sh --recent \| jq -r '.[].url'
    assert_success
    assert_output $'/tmp/newer-light\n/tmp/same-time-high\n/tmp/same-time-low\n/tmp/older-heavy'
}

# kate: hl bash;
