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
local DependencySolver = require "rocksolver.DependencySolver"

-- Installs 'package_names' using optional CMake 'variables'
local function _install(package_names, variables)
    -- Get installed packages
    local installed = mgr.get_installed()

    -- Get manifest
    local manifest, err = mf.get_manifest()
    if not manifest then
        return nil, err
    end

    local solver = DependencySolver(manifest, cfg.platform)
    local dependencies = {}

    for _, package_name in pairs(package_names) do
        -- Resolve dependencies
        local new_dependencies, err = solver:resolve_dependencies(package_name, installed)

        if err then
            return nil, err
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
        return nil, "Error downloading packages: " .. err
    end

    -- Get installed packages again, now we will modify and save them after each successful
    -- package installation
    local installed = mgr.get_installed()

    -- Install fetched packages
    for pkg, dir in pairs(dirs) do
        ok, err = mgr.install_pkg(pkg, dir, variables)
        if not ok then
            return nil, "Error installing: " ..err
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
    local result, err = _install(package_names, variables)
    if deploy_dir then cfg.revert_root_dir() end

    return result, err
end

-- Remove 'package_names'
local function _remove(package_names)
    local not_found = 0
    for _, pkg_name in pairs(package_names) do
        local installed = mgr.get_installed()
        local found_pkg = nil

        for i, pkg in pairs(installed) do
            if pkg_name == tostring(pkg) then
                found_pkg = table.remove(installed, i)
                break
            end
        end

        if found_pkg == nil then
            log:error("Could not remove package '%s', no records of its installation were found", pkg_name)
            not_found = not_found + 1
        else
            ok, err = mgr.remove_pkg(found_pkg)
            if not ok then
                return nil, "Error removing: " .. err
            end

            -- If removal was successful, update local manifest
            mgr.save_installed(installed)
        end
    end

    return not_found
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
