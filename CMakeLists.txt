# Generated Cmake file begin
cmake_minimum_required(VERSION 3.1)

project(luadist2 C CXX)
set(luadist2_VERSION 0.5-1)

set(ENV{LUA_DIR} ${CMAKE_INSTALL_PREFIX})
find_package(Lua REQUIRED)

## INSTALL DEFAULTS (Relative to CMAKE_INSTALL_PREFIX)
# Primary paths
set(INSTALL_BIN bin CACHE PATH "Where to install binaries to.")
set(INSTALL_LIB lib CACHE PATH "Where to install libraries to.")
set(INSTALL_ETC etc CACHE PATH "Where to store configuration files")
set(INSTALL_SHARE share CACHE PATH "Directory for shared data.")

set(INSTALL_LMOD ${INSTALL_LIB}/lua/${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR} CACHE PATH "Directory to install Lua modules.")
set(INSTALL_CMOD ${INSTALL_LIB}/lua/${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR} CACHE PATH "Directory to install Lua binary modules.")

set(luadist_SOURCES luadist.lua)
set(dist.manager_SOURCES dist/manager.lua)
set(dist.init_SOURCES dist/init.lua)
set(dist.log_SOURCES dist/log.lua)
set(dist.git_SOURCES dist/git.lua)
set(dist.utils_SOURCES dist/utils.lua)
set(dist.manifest_SOURCES dist/manifest.lua)
set(dist.downloader_SOURCES dist/downloader.lua)

install(DIRECTORY ${BUILD_COPY_DIRECTORIES} DESTINATION ${INSTALL_SHARE}/luadist2)

function(build_install KEYS DIR)
    list(REMOVE_DUPLICATES KEYS)

    foreach(KEY ${${KEYS}})
        set(BASE_NAME ${KEYS}_${KEY})
        install(FILES ${${BASE_NAME}_SRC} DESTINATION ${DIR}/${${BASE_NAME}_DST} RENAME ${${BASE_NAME}_RENAME})
    endforeach(KEY)
endfunction(build_install)

build_install(BUILD_INSTALL_lua ${INSTALL_LMOD})
build_install(BUILD_INSTALL_lib ${INSTALL_LIB})
build_install(BUILD_INSTALL_conf ${INSTALL_ETC})
build_install(BUILD_INSTALL_bin ${INSTALL_BIN})

install(FILES ${luadist_SOURCES} DESTINATION ${INSTALL_LMOD}/ RENAME luadist.lua)
install(FILES ${dist.manifest_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME manifest.lua)
install(FILES ${dist.log_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME log.lua)
install(FILES ${dist.manager_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME manager.lua)
install(FILES ${dist.utils_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME utils.lua)
install(FILES ${dist.downloader_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME downloader.lua)
install(FILES ${dist.init_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME init.lua)
install(FILES ${dist.git_SOURCES} DESTINATION ${INSTALL_LMOD}/dist RENAME git.lua)
install(FILES dist/ordered.lua DESTINATION ${INSTALL_LMOD}/dist)

## Platform detection
# By default use system name
set(DETECTED_PLATFORM ${CMAKE_SYSTEM_NAME})
string(TOLOWER ${DETECTED_PLATFORM} DETECTED_PLATFORM)

# Overrides for more specific platforms
if (DETECTED_PLATFORM STREQUAL "darwin")
    set(DETECTED_PLATFORM macosx)
elseif (MINGW)
    set(DETECTED_PLATFORM mingw32)
elseif (MSYS)
    set(DETECTED_PLATFORM msys)
elseif (CYGWIN)
    set(DETECTED_PLATFORM cygwin)
elseif (WIN32)
    set(DETECTED_PLATFORM win32)
elseif (UNIX)
    set(DETECTED_PLATFORM unix)
endif()

# Convert detected platform into lua array of strings
string(REPLACE ";" "\", \"" _TMP_PLATFORM "${DETECTED_PLATFORM}")
string(CONCAT PLATFORM "{\"" "${_TMP_PLATFORM}" "\"}")

# Configure
configure_file(dist/config.in.lua dist/config.lua @ONLY)
install(FILES ${CMAKE_BINARY_DIR}/dist/config.lua DESTINATION ${INSTALL_LMOD}/dist)
