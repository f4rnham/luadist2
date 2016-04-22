-- Main API of LuaDist

module ("dist", package.seeall)

local log = require "dist.log".logger
local cfg = require "dist.config"
local git = require "dist.git"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local mgr = require "dist.manager"
local downloader = require "dist.downloader"
local pl = require "pl.import_into"()
local rocksolver = {}
rocksolver.DependencySolver = require "rocksolver.DependencySolver"
rocksolver.Package = require "rocksolver.Package"
rocksolver.const = require "rocksolver.constraints"

-- Installs 'package_names' using optional CMake 'variables',
-- returns true on success and nil, error_message, error_code on error
-- Error codes:
-- 1 - manifest retrieval failed
-- 2 - dependency resolving failed
-- 3 - package download failed
-- 4 - installation of requested package failed
-- 5 - installation of dependency failed
local function _install(package_names, variables)
    -- Get installed packages
    local installed = mgr.get_installed()

    -- Get manifest
    local manifest, err = mf.get_manifest()
    if not manifest then
        return nil, err, 1
    end

    local solver = rocksolver.DependencySolver(manifest, cfg.platform)
    local dependencies = {}

    for _, package_name in pairs(package_names) do
        -- Resolve dependencies
        local new_dependencies, err = solver:resolve_dependencies(package_name, installed)

        if err then
            return nil, err, 2
        end

        -- Update dependencies to install with currently found ones and update installed packages
        -- for next dependency resolving as if previously found dependencies were already installed
        for _, dependency in pairs(new_dependencies) do
            dependencies[dependency] = dependency
            installed[dependency] = dependency
        end
    end

    -- Fetch the packages from repository
    local dirs, err = downloader.fetch_pkgs(dependencies, cfg.temp_dir_abs, manifest.repo_path)
    if not dirs then
        return nil, "Error downloading packages: " .. err, 3
    end

    -- Get installed packages again, now we will modify and save them after each successful
    -- package installation
    local installed = mgr.get_installed()

    -- Install fetched packages
    for pkg, dir in pairs(dirs) do
        ok, err = mgr.install_pkg(pkg, dir, variables)
        if not ok then
            return nil, "Error installing: " ..err, (utils.name_matches(pkg, package_names, true) and 4) or 5
        end

        -- If installation was successful, update local manifest
        table.insert(installed, pkg)
        mgr.save_installed(installed)
    end

    return true
end

-- Public wrapper for 'install' functionality, ensures correct setting of 'deploy_dir'
-- and performs argument checks
function install(package_names, deploy_dir, variables)
    if not package_names then return true end
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(deploy_dir and type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")

    if deploy_dir then cfg.update_root_dir(deploy_dir) end
    local result, err, status = _install(package_names, variables)
    if deploy_dir then cfg.revert_root_dir() end

    return result, err, status
end

-- Removes 'package_names' and returns amount of removed modules
--
-- In constrast to cli remove command, this one doesn't remove all packages
-- when supplied argument is empty table (to prevent possible mistakes),
-- to achieve such functionality use remove(get_installed(DIR))
local function _remove(package_names)
    local installed = mgr.get_installed()
    local removed = 0
    for _, pkg_name in pairs(package_names) do
        local name, version = rocksolver.const.split(tostring(pkg_name))
        local found_pkg = nil

        for i, pkg in pairs(installed) do
            if name == pkg.name and (not version or version == tostring(pkg.version)) then
                found_pkg = table.remove(installed, i)
                break
            end
        end

        if found_pkg == nil then
            log:error("Could not remove package '%s', no records of its installation were found", pkg_name)
        else
            ok, err = mgr.remove_pkg(found_pkg)
            if not ok then
                return nil, "Error removing: " .. err
            end

            -- If removal was successful, update local manifest
            mgr.save_installed(installed)
            removed = removed + 1
        end
    end

    return removed
end

-- Public wrapper for 'remove' functionality, ensures correct setting of 'deploy_dir'
-- and performs argument checks
function remove(package_names, deploy_dir)
    if type(package_names) == "string" then package_names = {package_names} end

    assert(type(package_names) == "table", "dist.remove: Argument 'package_names' is not a string or table.")
    assert(deploy_dir and type(deploy_dir) == "string", "dist.remove: Argument 'deploy_dir' is not a string.")

    if deploy_dir then cfg.update_root_dir(deploy_dir) end
    local result, err = _remove(package_names)
    if deploy_dir then cfg.revert_root_dir() end

    return result, err
end

-- Returns list of installed packages from provided 'deploy_dir'
function get_installed(deploy_dir)
    assert(deploy_dir and type(deploy_dir) == "string", "dist.get_installed: Argument 'deploy_dir' is not a string.")

    if deploy_dir then cfg.update_root_dir(deploy_dir) end
    local result, err = mgr.get_installed()
    if deploy_dir then cfg.revert_root_dir() end

    return result, err
end

-- Downloads packages specified in 'package_names' into 'download_dir' and
-- returns table <package, package_download_dir>
function fetch(download_dir, package_names)
    download_dir = download_dir or cfg.temp_dir_abs

    assert(type(download_dir) == "string", "dist.fetch: Argument 'download_dir' is not a string.")
    assert(type(package_names) == "table", "dist.fetch: Argument 'package_names' is not a table.")
    download_dir = pl.path.abspath(download_dir)

    local packages = {}
    local manifest, err = mf.get_manifest()
    if not manifest then
        return nil, err
    end

    for _, pkg_name in pairs(package_names) do
        -- If Package instances were provided (through Lua interface), just use them
        if getmetatable(pkg_name) == rocksolver.Package then
            table.insert(packages, pkg_name)
        -- Find best matching package instance for user provided name
        else
            assert(type(pkg_name) == "string", "dist.fetch: Elements of argument 'package_names' are not package instances or strings.")

            local name, version = rocksolver.const.split(pkg_name)

            -- If version was provided, use it
            if version ~= nil then
                table.insert(packages, rocksolver.Package(name, version, {}, false))
            -- Else fetch most recent one
            else
                if manifest.packages[name] ~= nil then
                    local latest_pkg = nil

                    for version, _ in pairs(manifest.packages[name]) do
                        if not latest_pkg or latest_pkg < rocksolver.Package(name, version, {}, false) then
                            latest_pkg = rocksolver.Package(name, version, {}, false)
                        end
                    end

                    assert(latest_pkg ~= nil)
                    table.insert(packages, latest_pkg)
                    log:info("Could not determine version of package '%s' to fetch from provided input, getting latest one '%s'", name, tostring(latest_pkg))
                else
                    return nil, "Could not find any information about package '" .. name .. "', please verify that it exists in manifest repositories"
                end
            end
        end
    end

    return downloader.fetch_pkgs(packages, download_dir, manifest.repo_path)
end

-- Downloads packages specified in 'package_names' into 'download_dir',
-- loads their rockspec files and returns table <package, rockspec>
function get_rockspec(download_dir, package_names)
    download_dir = download_dir or cfg.temp_dir_abs

    assert(type(download_dir) == "string", "dist.get_rockspec: Argument 'download_dir' is not a string.")
    assert(type(package_names) == "table", "dist.get_rockspec: Argument 'package_names' is not a table.")
    download_dir = pl.path.abspath(download_dir)

    local downloads, err = fetch(download_dir, package_names)
    if not downloads then
        return nil, "Could not download packages: " .. err
    end

    local rockspecs = {}
    for pkg, dir in pairs(downloads) do
        local rockspec_file = pl.path.join(dir, pkg.name .. "-" .. tostring(pkg.version) .. ".rockspec")
        local rockspec, err = mf.load_rockspec(rockspec_file)
        if not rockspec then
            return nil, "Cound not load rockspec for package '" .. pkg .. "' from '" .. rockspec_file .. "': " .. err
        end

        rockspecs[pkg] = rockspec
    end

    return rockspecs
end
