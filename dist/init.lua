-- main API of LuaDist

module ("dist", package.seeall)

local log = require "dist.log"
local cfg = require "dist.config"
local git = require "dist.git"
local mf = require "dist.manifest"
local utils = require "dist.utils"
local mgr = require "dist.manager"
local downloader = require "dist.downloader"
local pl = require "pl.import_into"()
local DependencySolver = require "rocksolver.DependencySolver"


-- Installs 'package_names' to 'deploy_dir', using optional CMake 'variables'.
function install(package_names, deploy_dir, variables)
    if not package_names then return true end
    if type(package_names) == "string" then package_names = {package_names} end
    deploy_dir = deploy_dir or cfg.root_dir

    assert(type(package_names) == "table", "dist.install: Argument 'package_names' is not a table or string.")
    assert(type(deploy_dir) == "string", "dist.install: Argument 'deploy_dir' is not a string.")
    deploy_dir = pl.path.abspath(deploy_dir)

    -- Get installed packages
    local installed = mgr.get_installed(deploy_dir)

    -- Get manifest
    local manifest, err = mf.get_manifest()
    if not manifest then
        return nil, "Error getting manifest: " .. err, 101
    end


    local solver = DependencySolver(manifest, cfg.platform)
    local dependencies = {}

    for _, package_name in pairs(package_names) do
        -- Resolve dependencies
        local new_dependencies, err = solver:resolve_dependencies(package_name, installed)

        if err then
            return nil, err, 102
        end

        -- Update dependencies to install with currently found ones and update installed packages
        -- for next dependency resolving as if previously found dependencies were already installed
        for _, dependency in pairs(new_dependencies) do
            dependencies[dependency] = dependency
            installed[dependency] = dependency
        end
    end

    -- Fetch the packages from repository
    local dirs, err = downloader.fetch_pkgs(dependencies, pl.path.join(deploy_dir, cfg.temp_dir), manifest.repo_path)
    if not dirs then
        return nil, err
    end

    -- Get installed packages again, now we will modify and save them after each successful
    -- package installation
    local installed = mgr.get_installed(deploy_dir)

    -- Install fetched packages
    for pkg, dir in pairs(dirs) do
        ok, err = mgr.install_pkg(pkg, dir, deploy_dir, variables)
        if not ok then
            return nil, err, 103
        end

        -- If installation was successful, update local manifest
        table.insert(installed, pkg)
        mgr.save_installed(deploy_dir, installed)
    end

    return true
end
