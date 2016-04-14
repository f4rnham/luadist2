module ("dist.downloader", package.seeall)

local log = require "dist.log".logger
local cfg = require "dist.config"
local git = require "dist.git"
local pl = require "pl.import_into"()
local Package = require "rocksolver.Package"


-- Fetches packages (table 'packages') to 'download_dir' from 'repo_paths'
-- Returns table of <Package, path to download directory> or nil and an error message on error
function fetch_pkgs(packages, download_dir, repo_paths)
    assert(type(packages) == "table", "downloader.fetch_pkgs: Argument 'packages' is not a table.")
    assert(type(download_dir) == "string" and pl.path.isabs(download_dir), "downloader.fetch_pkgs: Argument 'download_dir' is not an absolute path.")
    assert(type(repo_paths) == "table", "downloader.fetch_pkgs: Argument 'repo_paths' is not a table.")

    local fetched_dirs = {}

    for _, pkg in pairs(packages) do
        assert(getmetatable(pkg) == Package, "downloader.fetch_pkgs: Argument 'packages' does not contain Package instances.")

        local clone_dir = pl.path.join(download_dir, tostring(pkg))

        -- Delete clone_dir if it already exists
        if pl.path.exists(clone_dir) then
            pl.dir.rmtree(clone_dir)
        end

        -- Init the git repository
        local ok, err = git.create_repo(clone_dir)
        if not ok then
            return nil, err
        end

        log:info("Downloading '%s'...", pkg)

        -- Search repo_paths for one containing requested package
        local sha = nil
        for _, repo_path in pairs(repo_paths) do
            repo_url = string.format(repo_path, pkg.name)

            -- Fetch tag matching the desired package version
            sha, err = git.fetch_tag(clone_dir, repo_url, tostring(pkg.version))

            -- FIXME Handle real errors (ignore not found ones)

            if sha ~= nil then
                ok, err = git.checkout_sha(sha, clone_dir)

                if ok then
                    break
                else
                    return nil, "Could not fetch package '" .. pkg .. "' from repository '" .. repo_url "' to '" .. clone_dir .. "': " .. err
                end
            end
        end

        if not sha then
            return nil, "Package '" .. pkg .. "' not found in provided repositories " .. table.concat(repo_paths, ", ")
        end

        -- Delete '.git' directory
        if not cfg.debug then
            pl.dir.rmtree(pl.path.join(clone_dir, ".git"))
        end

        fetched_dirs[pkg] = clone_dir
    end

    return fetched_dirs
end
