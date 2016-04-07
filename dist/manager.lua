module ("dist.manager", package.seeall)

local cfg = require "dist.config"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local path = require "pl.path"
local r2cmake = require "rockspec2cmake"

local pl = {}
pl.utils = require "pl.utils"

local rocksolver = {}
rocksolver.utils = require "rocksolver.utils"
local Package = require "rocksolver.Package"

-- Builds package from 'src_dir' to 'build_dir' using 'variables'.
-- Returns true on success or nil, error_message on error.
-- 'variables' is table of optional CMake variables.
function build_pkg(src_dir, build_dir, variables)
    variables = variables or {}

    assert(type(src_dir) == "string" and path.isabs(src_dir), "manager.build_pkg: Argument 'src_dir' is not an absolute path.")
    assert(type(build_dir) == "string" and path.isabs(build_dir), "manager.build_pkg: Argument 'build_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.build_pkg: Argument 'variables' is not a table.")

    -- Create cmake cache
    local cache_file = io.open(path.join(build_dir, "cache.cmake"), "w")
    if not cache_file then
        return nil, "Error creating CMake cache file in '" .. build_dir .. "'", 401
    end

    -- Fill in cache variables
    for k, v in pairs(variables) do
        cache_file:write("SET(" .. k .. " " .. utils.quote(v):gsub("\\+", "/") .. " CACHE STRING \"\" FORCE)\n")
    end

    cache_file:close()

    print("Building " .. path.basename(src_dir) .. "...")

    -- Set cmake cache command
    local cache_command = cfg.cache_command
    if cfg.debug then
        cache_command = cache_command .. " " .. cfg.cache_debug_options
    end

    -- Set cmake build command
    local build_command = cfg.build_command
    if cfg.debug then
        build_command = build_command .. " " .. cfg.build_debug_options
    end

    -- Set the cmake cache
    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. cache_command .. " " .. utils.quote(src_dir))
    if not ok then
        return nil, "Error preloading the CMake cache script '" .. path.join(build_dir, "cmake.cache") .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr, 402
    end

    -- Build with cmake
    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. build_command)
    if not ok then
        return nil, "Error building with CMake in directory '" .. build_dir .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr,403
    end

    return true
end

-- Installs package 'pkg' from 'pkg_dir' to 'deploy_dir', using optional CMake 'variables'.
function install_pkg(pkg, pkg_dir, deploy_dir, variables)
    deploy_dir = deploy_dir or cfg.root_dir
    variables = variables or {}

    assert(getmetatable(pkg) == Package, "manager.install_pkg: Argument 'pkg' is not a Package instance.")
    assert(type(pkg_dir) == "string" and path.isabs(pkg_dir), "manager.install_pkg: Argument 'pkg_dir' is not not an absolute path.")
    assert(type(deploy_dir) == "string" and path.isabs(deploy_dir), "manager.install_pkg: Argument 'deploy_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.install_pkg: Argument 'variables' is not a table.")

    local rockspec_file = path.join(pkg_dir, pkg.name .. "-" .. tostring(pkg.version) .. ".rockspec")

    -- Check if we have cmake
    -- FIXME reintroduce in other place?
    -- ok = utils.system_dependency_available("cmake", "cmake --version")
    -- if not ok then return nil, "Error when installing: Command 'cmake' not available on the system.", 503 end

    -- Set cmake variables
    local cmake_variables = {}

    -- Set variables from config file
    for k, v in pairs(cfg.variables) do
        cmake_variables[k] = v
    end

    -- Set variables specified as argument (possibly overwriting config)
    for k, v in pairs(variables) do
        cmake_variables[k] = v
    end

    cmake_variables.CMAKE_INCLUDE_PATH = table.concat({cmake_variables.CMAKE_INCLUDE_PATH or "", path.join(deploy_dir, "include")}, ";")
    cmake_variables.CMAKE_LIBRARY_PATH = table.concat({cmake_variables.CMAKE_LIBRARY_PATH or "", path.join(deploy_dir, "lib"), path.join(deploy_dir, "bin")}, ";")
    cmake_variables.CMAKE_PROGRAM_PATH = table.concat({cmake_variables.CMAKE_PROGRAM_PATH or "", path.join(deploy_dir, "bin")}, ";")

    cmake_variables.CMAKE_INSTALL_PREFIX = deploy_dir

    -- Load rockspec file
    if not path.exists(rockspec_file) then
        return nil, "Error installing: Could not find rockspec for package " .. pkg .. ", expected location: " .. rockspec_file, 501
    end

    local rockspec, err = mf.load_rockspec(rockspec_file)
    if not rockspec then
        return nil, "Error installing: Cound not load rockspec for package " .. pkg .. " from " .. rockspec_file .. ": " .. err, 502
    end

    local cmake_commands, err = r2cmake.process_rockspec(rockspec, pkg_dir)
    if not cmake_commands then
        return nil, "Error installing: Cound not generate cmake commands for package" .. pkg .. ": " .. err, 503
    end

    -- Build the package
    local build_dir = path.join(deploy_dir, cfg.temp_dir, pkg .. "-build")
    path.mkdir(build_dir)
    local ok, err, status = build_pkg(pkg_dir, build_dir, cmake_variables)
    if not ok then
        return nil, err, status
    end

    -- Table to collect installed files
    pkg.files = {}

    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. cfg.cmake .. " -P cmake_install.cmake")

    if not ok then
        return nil, "Error installing: Cound not install package " .. pkg .. " from directory '" .. build_dir .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr, 504
    end

    local install_mf = path.join(build_dir, "install_manifest.txt")

    -- Collect installed files
    if path.exists(install_mf) then
        local mf, err = io.open(install_mf, "r")
        if not mf then
            return nil, "Error installing: Could not open CMake installation manifest '" .. install_mf .. "': " .. err, 302
        end

        for line in mf:lines() do
            print("> " .. line)
            --line = sys.check_separators(line)
            --local file = line:gsub(utils.escape_magic(deploy_dir .. sys.path_separator()), "")
            --table.insert(pkg.files, file)
        end
        mf:close()
    end

    -- Cleanup
    if not cfg.debug then
        path.rmdir(pkg_dir)
        path.rmdir(build_dir)
    end

    return true
end

-- Return manifest consisting of packages installed in specified deploy_dir directory
function get_installed(deploy_dir)
    local lua = {packages = {lua = {[cfg.lua_version] = {}}}}

    lua = rocksolver.utils.load_manifest(lua, true)

    if true then return lua end
end
