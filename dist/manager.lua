local log = require "dist.log".logger
local cfg = require "dist.config"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local r2cmake = require "rockspec2cmake"
local pl = require "pl.import_into"()
local rocksolver = {}
rocksolver.utils = require "rocksolver.utils"
rocksolver.Package = require "rocksolver.Package"
rocksolver.const = require "rocksolver.constraints"

local manager = {}

-- Builds package from 'src_dir' to 'build_dir' using CMake variables 'variables'
-- Returns true on success or nil, error_message on error
function manager.build_pkg(src_dir, build_dir, variables)
    variables = variables or {}

    assert(type(src_dir) == "string" and pl.path.isabs(src_dir), "manager.build_pkg: Argument 'src_dir' is not an absolute path.")
    assert(type(build_dir) == "string" and pl.path.isabs(build_dir), "manager.build_pkg: Argument 'build_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.build_pkg: Argument 'variables' is not a table.")

    -- Create cmake cache
    local cache_file = io.open(pl.path.join(build_dir, "cache.cmake"), "w")
    if not cache_file then
        return nil, "Could not create CMake cache file in '" .. build_dir .. "'"
    end

    -- Fill in cache variables
    for k, v in pairs(variables) do
        cache_file:write("SET(" .. k .. " " .. utils.quote(v):gsub("\\+", "/") .. " CACHE STRING \"\" FORCE)\n")
    end

    cache_file:close()

    log:info("Building '%s'", pl.path.basename(src_dir))

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
        return nil, "Could not preload the CMake cache script '" .. pl.path.join(build_dir, "cmake.cache") .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr
    end

    -- Build with cmake
    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. build_command)
    if not ok then
        return nil, "Could not build with CMake in directory '" .. build_dir .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr
    end

    return true
end

-- Installs package 'pkg' from 'pkg_dir' using optional CMake 'variables'.
function manager.install_pkg(pkg, pkg_dir, variables)
    variables = variables or {}

    assert(getmetatable(pkg) == rocksolver.Package, "manager.install_pkg: Argument 'pkg' is not a Package instance.")
    assert(type(pkg_dir) == "string" and pl.path.isabs(pkg_dir), "manager.install_pkg: Argument 'pkg_dir' is not not an absolute path.")
    assert(type(variables) == "table", "manager.install_pkg: Argument 'variables' is not a table.")

    local rockspec_file = pl.path.join(pkg_dir, pkg.name .. "-" .. tostring(pkg.version) .. ".rockspec")

    -- Check if we have cmake
    -- FIXME reintroduce in other place?
    -- ok = utils.system_dependency_available("cmake", "cmake --version")
    -- if not ok then return nil, "Error when installing: Command 'cmake' not available on the system." end

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

    cmake_variables.CMAKE_INCLUDE_PATH = table.concat({cmake_variables.CMAKE_INCLUDE_PATH or "", pl.path.join(cfg.root_dir_abs, "include")}, ";")
    cmake_variables.CMAKE_LIBRARY_PATH = table.concat({cmake_variables.CMAKE_LIBRARY_PATH or "", pl.path.join(cfg.root_dir_abs, "lib"), pl.path.join(cfg.root_dir_abs, "bin")}, ";")
    cmake_variables.CMAKE_PROGRAM_PATH = table.concat({cmake_variables.CMAKE_PROGRAM_PATH or "", pl.path.join(cfg.root_dir_abs, "bin")}, ";")

    cmake_variables.CMAKE_INSTALL_PREFIX = cfg.root_dir_abs

    -- Load rockspec file
    if not pl.path.exists(rockspec_file) then
        return nil, "Could not find rockspec for package '" .. pkg .. "', expected location: '" .. rockspec_file .. "'"
    end

    local rockspec, err = mf.load_rockspec(rockspec_file)
    if not rockspec then
        return nil, "Cound not load rockspec for package '" .. pkg .. "' from '" .. rockspec_file .. "': " .. err
    end

    pkg.spec = rockspec

    -- Check if rockspec provides additional cmake variables
    if rockspec.build and rockspec.build.type == "cmake" and type(rockspec.build.variables) == "table" then
        for k, v in pairs(rockspec.build.variables) do
            -- FIXME Should this overwrite cmake variables set by config?
            if not cmake_variables[k] then
                cmake_variables[k] = v
            end
        end
    end

    local cmake_commands, err = r2cmake.process_rockspec(rockspec, pkg_dir)
    if not cmake_commands then
        -- Could not generate cmake commands, but there can be cmake attached
        if not rockspec.build or rockspec.build.type ~= "cmake" or not pl.path.exists(pl.path.join(pkg_dir, "CMakeLists.txt")) then
            return nil, "Cound not generate cmake commands for package '" .. pkg .. "': " .. err
        else
            log:info("Package '%s': using CMakeLists.txt provided by package itself", tostring(pkg))
        end
    end

    -- Build the package
    local build_dir = pl.path.join(cfg.temp_dir_abs, pkg .. "-build")
    pl.dir.makepath(build_dir)
    local ok, err = manager.build_pkg(pkg_dir, build_dir, cmake_variables)
    if not ok then
        return nil, "Error building package '" .. pkg .. "': " .. err
    end

    local ok, status, stdout, stderr = pl.utils.executeex("cd " .. utils.quote(build_dir) .. " && " .. cfg.cmake .. " -P cmake_install.cmake")

    if not ok then
        return nil, "Cound not install package '" .. pkg .. "' from directory '" .. build_dir .. "'\nstdout:\n" .. stdout .. "\nstderr:\n" .. stderr
    end

    -- Table to collect installed files
    pkg.files = {}
    local install_mf = pl.path.join(build_dir, "install_manifest.txt")

    -- Collect installed files
    local mf, err = io.open(install_mf, "r")
    if not mf then
        return nil, "Could not open CMake installation manifest '" .. install_mf .. "': " .. err
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

-- Remove package 'pkg'.
function manager.remove_pkg(pkg)
    assert(getmetatable(pkg) == rocksolver.Package, "manager.remove_pkg: Argument 'pkg' is not a Package instance.")

    if not pkg.files then
        return nil, "Could not remove package '" .. pkg .. "', specified package does not contain installation info"
    end

    -- Table to store directories which were affected by package removal,
    -- if they are empty after package removal, they will be removed too
    local affected_dirs = {}

    -- Remove installed files
    for _, file in pairs(pkg.files) do
        if pl.path.exists(file) then
            pl.file.delete(file)

            local dir = pl.path.splitpath(file)
            if dir then
                affected_dirs[dir] = true
            end
        else
            log:error("Error removing file '%s', not found", file)
        end
    end

    -- Remove all directories which are now empty
    for dir, _ in pairs(affected_dirs) do
        -- Only remove directories while we are inside of current root
        -- Also stops removal of directories if we for some reason installed package files outside of root
        while pl.path.exists(dir) and pl.path.common_prefix(cfg.root_dir_abs, dir) == cfg.root_dir_abs do
            -- Non empty directory
            if #pl.dir.getallfiles(dir) ~= 0 or #pl.dir.getdirectories(dir) ~= 0 then
                break
            end

            -- Remove directory and move one level higher
            pl.path.rmdir(dir)
            dir = pl.path.dirname(dir:gsub(pl.path.sep .. "$", ""))
        end
    end

    return true
end

function manager.save_installed(manifest)
    assert(type(manifest) == "table", "manager.save_installed: Argument 'manifest' is not a table.")

    return pl.pretty.dump(manifest, cfg.local_manifest_file_abs)
end

-- Return manifest consisting of installed packages
function manager.get_installed()
    local manifest, err = mf.load_manifest(cfg.local_manifest_file_abs)

    -- Assume no packages were installed, create default manifest with just lua
    if not manifest then
        log:info("Install manifest not found in current root directory '%s', generating new empty one (%s)", cfg.root_dir_abs, err)

        manifest = {}
        manager.save_installed(manifest)
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

return manager
