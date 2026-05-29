# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

add_test(
    NAME "cdui shared code test"
    COMMAND "${BATS_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/cduilib_tests.bats"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  )
add_test(
    NAME "cdui feed test"
    COMMAND "${BATS_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/cdui_feed_tests.bats"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  )
add_test(
    NAME "mc-hotlist feed test"
    COMMAND "${BATS_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/cdui_feed_mc_hotlist_tests.bats"
    WORKING_DIRECTORY "${PROJECT_BINARY_DIR}"
  )
