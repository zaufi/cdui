# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_policy(SET CMP0140 NEW)

# BEGIN Check parameters
if(NOT DEFINED INPUT_FILE)
    message(FATAL_ERROR "INPUT_FILE is not set")
endif()

if(NOT EXISTS "${INPUT_FILE}")
    message(FATAL_ERROR "Input file does not exist: ${INPUT_FILE}")
endif()

if(NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "OUTPUT_FILE is not set")
endif()
# END Check parameters

# Get config defaults as Bash functions.
execute_process(
    COMMAND "${JQ_EXECUTABLE}" -r -f "${CONFIG_DEFAULT_JQ}" "${INPUT_FILE}"
    OUTPUT_VARIABLE _generated_functions
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _error
    RESULT_VARIABLE _result
  )
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Failed to get config defaults from ${INPUT_FILE}: ${_error}")
endif()

file(WRITE "${OUTPUT_FILE}" [=[

# BEGIN `cdui` config default helper functions
]=])

string(REGEX REPLACE "\n$" "" _generated_functions "${_generated_functions}")
file(
    APPEND "${OUTPUT_FILE}"
    "${_generated_functions}\n# END `cdui` config default helper functions\n"
  )
