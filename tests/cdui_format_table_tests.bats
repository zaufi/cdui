# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

setup() {
    bats_load_library bats-support
    bats_load_library bats-assert

    export HOME="${BATS_FILE_TMPDIR}"/"${BATS_TEST_NAME}"/home
    mkdir -p "${HOME}"
}

@test 'format table aligns paths when plain entries have entry colors' {
    local green=$'\033[32m'
    local reset=$'\033[0m'
    local formatted

    formatted=$(
        jq -n --arg green "${green}" '
            [
              {"origin":"G","entry":"short","url":"../short","entry_color":$green},
              {"origin":"G","entry":"much-longer","url":"../much-longer","entry_color":$green}
            ]
          ' \
          | jq \
            --arg pwd "${PWD}" \
            --arg home "${HOME}" \
            --arg current_url_color "" \
            --arg missed_url_color "" \
            --arg url_color_prefix "" \
            --arg reset_color "${reset}" \
            -ref "${BATS_TEST_DIRNAME}"/../cdui-format-table.jq
      )

    assert_equal "${formatted}" \
        $'G\t\033[32mshort      \033[0m\t../short\t../short\nG\t\033[32mmuch-longer\033[0m\t../much-longer\t../much-longer'
}

# kate: hl bash;
