-- Luadist configuration

module ("dist.config", package.seeall)

local logging = require "logging"
local utils = require "dist.utils"
local log = require "dist.log"
local pl = require "pl.import_into"()

-- System information ------------------------------------------------
version       = "@luadist2_VERSION@"
platform      = @PLATFORM@

-- Directories (relative to root_dir) --------------------------------
root_dir      = os.getenv("DIST_ROOT") or utils.get_luadist_location() or pl.path.sep
temp_dir      = "tmp"
share_dir     = pl.path.join("share", "LuaDist")

-- Manifest information ----------------------------------------------
manifest_filename   = "manifest-file"
local_manifest_file = pl.path.join(share_dir, manifest_filename)

-- Repositories ------------------------------------------------------
manifest_repos = {
    -- Manually updated core manifest, contains lua, lua-git, zlib packages and
    -- everything other that should not go through LuaRocks management
    "git://github.com/LuaDist-core/manifest.git",
    -- Generated manifest based on LuaRocks packages
    "git://github.com/LuaDist2/manifest.git",
}

-- Settings ----------------------------------------------------------
debug         = false         -- Use debug mode (mainly does not clean temp).

-- Available log levels are: DEBUG, INFO, WARN, ERROR, FATAL
-- Minimum level for log messages to be printed (nil to disable).
print_log_level = logging.INFO
-- Minimum level for log messages to be logged (nil to disable).
write_log_level = logging.INFO
log_file = pl.path.join(share_dir, "luadist.log")

-- CMake variables ---------------------------------------------------
variables = {
    -- Install defaults
    INSTALL_BIN                        = "bin",
    INSTALL_LIB                        = "lib",
    INSTALL_ETC                        = "etc",
    INSTALL_SHARE                      = "share",
    INSTALL_LMOD                       = pl.path.join("lib", "lua"),
    INSTALL_CMOD                       = pl.path.join("lib", "lua"),

    -- RPath functionality
    CMAKE_SKIP_BUILD_RPATH             = "FALSE",
    CMAKE_BUILD_WITH_INSTALL_RPATH     = "FALSE",
    CMAKE_INSTALL_RPATH                = "$ORIGIN/../lib",
    CMAKE_INSTALL_RPATH_USE_LINK_PATH  = "TRUE",
    CMAKE_INSTALL_NAME_DIR             = "@executable_path/../lib",
}

if (variables.CMAKE_GENERATOR == "MinGW Makefiles") then
  -- Static Linking (For MinGW)
  variables.CMAKE_EXE_LINKER_FLAGS             = "-static-libgcc -static-libstdc++ -static"
  variables.CMAKE_SHARED_LINKER_FLAGS          = "-static-libgcc -static-libstdc++ -static"
  variables.CMAKE_MODULE_LINKER_FLAGS          = "-static-libgcc -static-libstdc++ -static"
end

-- Building ----------------------------------------------------------
cmake         = "cmake"

cache_command = cmake .. " -C cache.cmake"
build_command = cmake .. " --build . --clean-first"

cache_debug_options = "-DCMAKE_VERBOSE_MAKEFILE=true -DCMAKE_BUILD_TYPE=Debug"
build_debug_options = ""

-- Add -j option to make in case of unix makefiles to speed up builds
if (variables.CMAKE_GENERATOR == "Unix Makefiles") then
        build_command = build_command .. " -- -j6"
end

-- Add -j option to make in case of MinGW makefiles to speed up builds
if (variables.CMAKE_GENERATOR == "MinGW Makefiles") then
        build_command = "set SHELL=cmd.exe && " .. build_command .. " -- -j"
end

-- Update all root directory related variables, only these ones should be used in code
function update_root_dir(dir)
    old_root_dir            = root_dir_abs

    root_dir_abs            = pl.path.abspath(dir)
    temp_dir_abs            = pl.path.join(root_dir_abs, temp_dir)
    share_dir_abs           = pl.path.join(root_dir_abs, share_dir)
    local_manifest_file_abs = pl.path.join(root_dir_abs, local_manifest_file)
    log_file_abs            = pl.path.join(root_dir_abs, log_file)

    log.reload_config({
        print_log_level = print_log_level,
        write_log_level = write_log_level,
        log_file_abs = log_file_abs,
    })

    pl.dir.makepath(temp_dir_abs)
    pl.dir.makepath(share_dir_abs)
end

-- Function used when exitting from functions which allow to specify deploy directory
function revert_root_dir()
    update_root_dir(old_root_dir)
end

update_root_dir(root_dir)
