# SPDX-FileCopyrightText: 2026 Alex Turbov <i.zaufi@gmail.com>
# SPDX-License-Identifier: GPL-3.0-or-later

#---------------------------------------------------------
# Section: Initialize CMake
#---------------------------------------------------------
cmake_minimum_required(VERSION 3.31)

project(
    cdui VERSION 0.1.0
    DESCRIPTION "Change directory UI helper for Bash"
    HOMEPAGE_URL "https://github.com/zaufi/cdui"
    LANGUAGES NONE
  )

# Setup package paths
set(CMAKE_SIZEOF_VOID_P 8)
include(GNUInstallDirs)

find_program(
    YQ_EXECUTABLE yq REQUIRED
    DOC "Portable command-line YAML, JSON, XML, CSV, TOML and properties processor"
  )
mark_as_advanced(YQ_EXECUTABLE)

find_program(
    JQ_EXECUTABLE jq REQUIRED
    DOC "Command-line JSON processor"
  )
mark_as_advanced(JQ_EXECUTABLE)

# Try to find mandatory runtime dependencies and warn if smth not found
foreach(_dep IN ITEMS sk jq grep sed bash cut sort head)
    find_program(${_dep}_EXECUTABLE ${_dep} DOC "Runtime dependency (${_dep})")
    mark_as_advanced(${_dep}_EXECUTABLE)
    if(NOT ${_dep}_EXECUTABLE)
        message(
            WARNING
            "Missed runtime dependency: `${_dep}`. "
            "It's not needed to build, but being installed this package gonna be broken!"
          )
    endif()
endforeach()

#---------------------------------------------------------
# Section: "Build" related statements
#---------------------------------------------------------

function(add_yaml2json_target input_file output_file)
    cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR yaml2json.cmake OUTPUT_VARIABLE YAML2JSON_CONVERTER)
    add_custom_command(
        OUTPUT ${output_file}
        COMMAND
            ${CMAKE_COMMAND}
            -DINPUT_FILE=${input_file}
            -DOUTPUT_FILE=${output_file}
            -DYQ_EXECUTABLE=${YQ_EXECUTABLE}
            -P ${YAML2JSON_CONVERTER}
        DEPENDS
            ${input_file}
            ${YAML2JSON_CONVERTER}
        COMMENT "Generating $<PATH:GET_FILENAME,${output_file}> from $<PATH:GET_FILENAME,${input_file}>"
        VERBATIM
      )
endfunction()

# BEGIN Render charmaps.yaml -> charmaps.json -> charmaps.sh
cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR charmaps.yaml OUTPUT_VARIABLE CHARMAPS_YAML)
cmake_path(APPEND CMAKE_CURRENT_BINARY_DIR charmaps.json OUTPUT_VARIABLE CHARMAPS_JSON)
add_yaml2json_target(${CHARMAPS_YAML} ${CHARMAPS_JSON})

cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR charmap.bash.in OUTPUT_VARIABLE CHARMAP_BASH_TEMPLATE)
cmake_path(APPEND CMAKE_CURRENT_BINARY_DIR charmaps.sh OUTPUT_VARIABLE CHARMAPS_BASH)
cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR charmaps-generator.cmake OUTPUT_VARIABLE CHARMAPS_GENERATOR)
add_custom_command(
    OUTPUT ${CHARMAPS_BASH}
    COMMAND
        ${CMAKE_COMMAND}
        -DINPUT_FILE=${CHARMAPS_JSON}
        -DOUTPUT_FILE=${CHARMAPS_BASH}
        -DTEMPLATE_FILE=${CHARMAP_BASH_TEMPLATE}
        -P ${CHARMAPS_GENERATOR}
    DEPENDS
        ${CHARMAPS_JSON}
        ${CHARMAP_BASH_TEMPLATE}
        ${CHARMAPS_GENERATOR}
    COMMENT "Generating bash helper functions from $<PATH:GET_FILENAME,${CHARMAPS_JSON}>"
    VERBATIM
  )
# END Render charmaps.yaml -> charmaps.json -> charmaps.sh

# BEGIN Render config.schema.yaml -> config.schema.json -> config.defaults.sh
cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR config.schema.yaml OUTPUT_VARIABLE CONFIG_SCHEMA_YAML)
cmake_path(APPEND CMAKE_CURRENT_BINARY_DIR config.schema.json OUTPUT_VARIABLE CONFIG_SCHEMA_JSON)
add_yaml2json_target(${CONFIG_SCHEMA_YAML} ${CONFIG_SCHEMA_JSON})

cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR config-default.bash.in OUTPUT_VARIABLE CONFIG_DEFAULT_BASH_TEMPLATE)
cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR config-default.jq OUTPUT_VARIABLE CONFIG_DEFAULT_JQ)
cmake_path(APPEND CMAKE_CURRENT_BINARY_DIR config-default.bash OUTPUT_VARIABLE CONFIG_DEFAULT_BASH)
cmake_path(APPEND CMAKE_CURRENT_SOURCE_DIR config-default-generator.cmake OUTPUT_VARIABLE CONFIG_DEFAULT_GENERATOR)
add_custom_command(
    OUTPUT ${CONFIG_DEFAULT_BASH}
    COMMAND
        ${CMAKE_COMMAND}
        -DINPUT_FILE=${CONFIG_SCHEMA_JSON}
        -DOUTPUT_FILE=${CONFIG_DEFAULT_BASH}
        -DTEMPLATE_FILE=${CONFIG_DEFAULT_BASH_TEMPLATE}
        -DJQ_EXECUTABLE=${JQ_EXECUTABLE}
        -DCONFIG_DEFAULT_JQ=${CONFIG_DEFAULT_JQ}
        -P ${CONFIG_DEFAULT_GENERATOR}
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    DEPENDS
        ${CONFIG_SCHEMA_JSON}
        ${CONFIG_DEFAULT_BASH_TEMPLATE}
        ${CONFIG_DEFAULT_GENERATOR}
        ${CMAKE_SOURCE_DIR}/config-default.jq
    COMMENT "Generating bash helper functions from $<PATH:GET_FILENAME,${CONFIG_SCHEMA_JSON}>"
    VERBATIM
  )
# END Render config.schema.yaml -> config.schema.json -> config.defaults.sh

# BEGIN Render the final cduilib.sh
cmake_path(APPEND CMAKE_CURRENT_BINARY_DIR cduilib.sh OUTPUT_VARIABLE CDUILIB_BASH)
add_custom_command(
    OUTPUT ${CDUILIB_BASH}
    COMMAND
        ${CMAKE_COMMAND} -E cat --
            ${PROJECT_SOURCE_DIR}/cduilib.sh
            ${CHARMAPS_BASH}
            ${CONFIG_DEFAULT_BASH}
        > "${CDUILIB_BASH}"
    DEPENDS
        ${CHARMAPS_BASH}
        ${CONFIG_DEFAULT_BASH}
        ${PROJECT_SOURCE_DIR}/cduilib.sh
    COMMENT "Render cduilib.sh"
    VERBATIM
  )

add_custom_target(render-cduilib ALL DEPENDS "${CDUILIB_BASH}")
# END Render the final cduilib.sh

#---------------------------------------------------------
# Section: Install project files
#---------------------------------------------------------

install(
    FILES
        build-index.jq
        cdui-feed.sh
        validate-manifest.jq
        "${CDUILIB_BASH}"
    DESTINATION "${CMAKE_INSTALL_LIBEXECDIR}/${PROJECT_NAME}"
  )

install(
    DIRECTORY cdui.d
    DESTINATION "${CMAKE_INSTALL_LIBEXECDIR}/${PROJECT_NAME}"
  )

#---------------------------------------------------------
# Section: Testing
#---------------------------------------------------------
set(CTEST_NEW_FORMAT TRUE)
include(CTest)

if(BUILD_TESTING)
    find_program(
        BATS_EXECUTABLE bats REQUIRED
        DOC "Bash Automated Testing System"
      )

    add_test(
        NAME cduilib_test
        COMMAND "${BATS_EXECUTABLE}" "${PROJECT_SOURCE_DIR}/tests/cduilib_tests.bats"
        WORKING_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}"
      )
endif()

#---------------------------------------------------------
# Section: Configure package options
#---------------------------------------------------------
set(CPACK_PACKAGE_RELOCATABLE OFF)
set(CPACK_SET_DESTDIR ON)
set(CPACK_PACKAGING_INSTALL_PREFIX "/usr")

# "Binary" package settings
cmake_host_system_information(RESULT DISTRIB_ID QUERY DISTRIB_ID)
if(DISTRIB_ID STREQUAL "ubuntu")
    set(CPACK_GENERATOR DEB)
endif()
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_VENDOR "Alex Turbov")
set(CPACK_PACKAGE_CONTACT "i.zaufi@gmail.com")
set(CPACK_RESOURCE_FILE_LICENSE "${PROJECT_SOURCE_DIR}/LICENSE")

# Source tarball settings
set(CPACK_SOURCE_PACKAGE_FILE_NAME ${PROJECT_NAME}-${PROJECT_VERSION})
set(CPACK_SOURCE_GENERATOR TGZ)

# The following components are regex's to match anywhere (unless anchored)
# in absolute path + filename to find files or directories to be excluded
# from source tarball.
set(CPACK_SOURCE_IGNORE_FILES
    "\\\\.gitignore$"
    "\\\\.kate-swp$"
    "\\\\.tar\\\\.gz$"
    "^.*/\\\\.git.*$"
    "^.*/build/.*$"
  )

list(APPEND _deb_aux_deps git)
list(APPEND _rpm_aux_deps git)

# TODO Any distro has `skim` packaged? Need to add a dependency on it.

list(JOIN _deb_aux_deps ", " _deb_aux_deps)
list(JOIN _rpm_aux_deps ", " _rpm_aux_deps)

if(_deb_aux_deps)
    string(PREPEND _deb_aux_deps ", ")
endif()
if(_rpm_aux_deps)
    string(PREPEND _rpm_aux_deps ", ")
endif()

# RPM specific settings
set(CPACK_RPM_PACKAGE_GROUP "System Environment/Shells")
set(CPACK_RPM_PACKAGE_RELOCATABLE OFF)
set(CPACK_RPM_PACKAGE_RELEASE_DIST ON)
set(CPACK_RPM_PACKAGE_RELEASE "1")
set(CPACK_RPM_PACKAGE_LICENSE "GPL3")
set(CPACK_RPM_FILE_NAME "RPM-DEFAULT")
set(CPACK_RPM_PACKAGE_ARCHITECTURE "noarch")
set(CPACK_RPM_PACKAGE_REQUIRES "bash, coreutils, grep, procps-ng, sed, util-linux${_rpm_aux_deps}")
# ALERT The tag `Suggests:` doesn't supported (properly) by `rpmbuild` shipped in CentOS
#set(CPACK_RPM_PACKAGE_SUGGESTS "fontconfig, iproute, jq, kmod, systemd, usbutils")
set(CPACK_RPM_PACKAGE_DESCRIPTION [[A small TUI for `cd`.]])

# DEB specific settings
set(CPACK_DEBIAN_PACKAGE_SECTION "shells")
set(CPACK_DEBIAN_FILE_NAME "DEB-DEFAULT")
set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "all")
set(CPACK_DEBIAN_PACKAGE_DEPENDS "bash, coreutils, grep, jq, sed${_deb_aux_deps}")
set(CPACK_DEBIAN_PACKAGE_SUGGESTS "")
set(
    CPACK_DEBIAN_PACKAGE_DESCRIPTION
    "${CPACK_PACKAGE_DESCRIPTION_SUMMARY}\n${CPACK_RPM_PACKAGE_DESCRIPTION}"
)

include(CPack)
