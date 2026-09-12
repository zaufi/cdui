# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    # NOTE CTest will run this from the CMake's build directory
    # with rendered `cduilib.sh` and the copy of `cdui.sh`
    if [[ -f cdui.sh ]]; then
        CDUI_UNDER_TEST=${PWD}/cdui.sh
    else
        # Otherwise, use the assembled scripts from the build directory
        CDUI_UNDER_TEST="${BATS_TEST_DIRNAME}"/../build/cdui.sh
    fi
}

@test 'source cdui.sh twice in the same shell' {
    # A login shell may evaluate `/etc/profile` (and hence the installed
    # `/etc/profile.d/cdui.sh`) more than once -- sourcing this script
    # repeatedly must stay silent.
    run bash -c ". '${CDUI_UNDER_TEST}'; . '${CDUI_UNDER_TEST}'"
    assert_success
    assert_output ''
}
