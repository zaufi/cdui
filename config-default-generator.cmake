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

if(NOT DEFINED TEMPLATE_FILE)
    message(FATAL_ERROR "TEMPLATE_FILE is not set")
endif()
# END Check parameters


# Get config defaults as `dot.separated.key=default-value`
execute_process(
    COMMAND "${JQ_EXECUTABLE}" -r -f "${CONFIG_DEFAULT_JQ}" "${INPUT_FILE}"
    OUTPUT_VARIABLE _schema_defaults
    OUTPUT_STRIP_TRAILING_WHITESPACE
    ERROR_VARIABLE _error
    RESULT_VARIABLE _result
  )
if(NOT _result EQUAL 0)
    message(FATAL_ERROR "Failed to get config defaults from ${INPUT_FILE}: ${_error}")
endif()

string(REPLACE "\n" ";" _schema_defaults "${_schema_defaults}")

file(READ "${TEMPLATE_FILE}" _default_fn_template)
# Remove first two lines
string(REGEX REPLACE "^# [^\n]*\n# [^\n]*\n?" "" _default_fn_template "${_default_fn_template}")

file(WRITE "${OUTPUT_FILE}" [=[

# BEGIN `cdui` config default helper functions
]=])

set(_generated_functions "")
foreach(_kvs IN LISTS _schema_defaults)
    string(REPLACE "=" ";" _kv "${_kvs}")
    list(POP_FRONT _kv config_path default_value)
    string(PREPEND config_path "cdui.config.")
    message(STATUS "Rendering config default: ${config_path}")
    string(CONFIGURE "${_default_fn_template}" _rendered_function @ONLY)
    string(APPEND _generated_functions "${_rendered_function}\n")
endforeach()

string(REGEX REPLACE "\n$" "" _generated_functions "${_generated_functions}")
file(
    APPEND "${OUTPUT_FILE}"
    "${_generated_functions}# END `cdui` config default helper functions\n"
  )
