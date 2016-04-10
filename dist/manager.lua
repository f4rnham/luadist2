module ("dist.manager", package.seeall)

local cfg = require "dist.config"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local r2cmake = require "rockspec2cmake"
local pl = require "pl.import_into"()
local rocksolver = {}
rocksolver.utils = require "rocksolver.utils"
rocksolver.Package = require "rocksolver.Package"
rocksolver.const = require "rocksolver.constraints"


-- Builds package from 'src_dir' to 'build_dir' using 'variables'.
-- Returns true on success or nil, error_message on error.
-- 'variables' is table of optional CMake variables.
function build_pkg(src_dir, build_dir, variables)
    variables = variables or {}

    assert(type(src_dir) == "string" and pl.path.isabs(src_dir), "manager.build_pkg: Argument 'src_dir' is not an absolute path.")
    assert(type(build_dir) == "string" and pl.path.isabs(build_dir), "manager.build_pkg: Argument 'build_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.build_pkg: Argument 'variables' is not a table.")

    -- Create cmake cache
    local cache_file = io.open(pl.path.join(build_dir, "cache.cmake"), "w")
    if not cache_file then
        return nil, "Error creating CMake cache file in '" .. build_dir .. "'", 401
    end

    -- Fill in cache variables
    for k, v in pairs(variables) do
        cache_file:write("SET(" .. k .. " " .. utils.quote(v):gsub("\\+", "/") .. " CACHE STRING \"\" FORCE)\n")
    end

    cache_file:close()

    print("Building " .. pl.path.basename(src_dir) .. "...")

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
        return nil, "Error preloading the CMake cache script '" .. pl.path.join(build_dir, "cmake.cache") .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr, 402
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

    assert(getmetatable(pkg) == rocksolver.Package, "manager.install_pkg: Argument 'pkg' is not a Package instance.")
    assert(type(pkg_dir) == "string" and pl.path.isabs(pkg_dir), "manager.install_pkg: Argument 'pkg_dir' is not not an absolute path.")
    assert(type(deploy_dir) == "string" and pl.path.isabs(deploy_dir), "manager.install_pkg: Argument 'deploy_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.install_pkg: Argument 'variables' is not a table.")

    local rockspec_file = pl.path.join(pkg_dir, pkg.name .. "-" .. tostring(pkg.version) .. ".rockspec")

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

    cmake_variables.CMAKE_INCLUDE_PATH = table.concat({cmake_variables.CMAKE_INCLUDE_PATH or "", pl.path.join(deploy_dir, "include")}, ";")
    cmake_variables.CMAKE_LIBRARY_PATH = table.concat({cmake_variables.CMAKE_LIBRARY_PATH or "", pl.path.join(deploy_dir, "lib"), pl.path.join(deploy_dir, "bin")}, ";")
    cmake_variables.CMAKE_PROGRAM_PATH = table.concat({cmake_variables.CMAKE_PROGRAM_PATH or "", pl.path.join(deploy_dir, "bin")}, ";")

    cmake_variables.CMAKE_INSTALL_PREFIX = deploy_dir

    -- Load rockspec file
    if not pl.path.exists(rockspec_file) then
        return nil, "Error installing: Could not find rockspec for package " .. pkg .. ", expected location: " .. rockspec_file, 501
    end

    local rockspec, err = mf.load_rockspec(rockspec_file)
    if not rockspec then
        return nil, "Error installing: Cound not load rockspec for package " .. pkg .. " from " .. rockspec_file .. ": " .. err, 502
    end

    pkg.spec = rockspec

    local cmake_commands, err = r2cmake.process_rockspec(rockspec, pkg_dir)
    if not cmake_commands then
        return nil, "Error installing: Cound not generate cmake commands for package " .. pkg .. ": " .. err, 503
    end

    -- Build the package
    local build_dir = pl.path.join(deploy_dir, cfg.temp_dir, pkg .. "-build")
    pl.path.mkdir(build_dir)
    local ok, err, status = build_pkg(pkg_dir, build_dir, cmake_variables)
    if not ok then
        return nil, err, status
    end

    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. cfg.cmake .. " -P cmake_install.cmake")

    if not ok then
        return nil, "Error installing: Cound not install package " .. pkg .. " from directory '" .. build_dir .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr, 504
    end

    -- Table to collect installed files
    pkg.files = {}
    local install_mf = pl.path.join(build_dir, "install_manifest.txt")

    -- Collect installed files
    local mf, err = io.open(install_mf, "r")
    if not mf then
        return nil, "Error installing: Could not open CMake installation manifest '" .. install_mf .. "': " .. err, 302
    end

    for line in mf:lines() do
        table.insert(pkg.files, line)
    end
    mf:close()

    -- Cleanup
    if not cfg.debug then
        pl.dir.rmtree(pkg_dir)
        pl.dir.rmtree(build_dir)
    end

    return true
end

function save_installed(deploy_dir, manifest)
    assert(type(deploy_dir) == "string" and pl.path.isabs(deploy_dir), "manager.save_installed: Argument 'deploy_dir' is not an absolute path.")
    assert(type(manifest) == "table", "manager.save_installed: Argument 'manifest' is not a table.")

    local manifest_file = pl.path.join(deploy_dir, cfg.local_manifest_file)
    return pl.pretty.dump(manifest, manifest_file)
end

-- Return manifest consisting of packages installed in specified deploy_dir directory
function get_installed(deploy_dir)
    assert(type(deploy_dir) == "string" and pl.path.isabs(deploy_dir), "manager.get_installed: Argument 'deploy_dir' is not an absolute path.")

    local manifest_file = pl.path.join(deploy_dir, cfg.local_manifest_file)
    local manifest, err = mf.load_manifest(manifest_file)

    -- Assume no packages were installed, create default manifest with just lua
    if not manifest then
        manifest = {packages = {lua = {[cfg.lua_version] = {}}}}
        manifest = rocksolver.utils.load_manifest(manifest, true)
        save_installed(deploy_dir, manifest)
        return manifest
    end

    -- Restore meta tables for loaded packages
    for _, pkg in pairs(manifest) do
        setmetatable(pkg, rocksolver.Package)
        -- Re-parse version just to recreate meta table
        pkg.version = rocksolver.const.parseVersion(pkg.version.string)
    end

    return manifest
end
