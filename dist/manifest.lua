-- Working with manifest and dist.info files

module ("dist.manifest", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local utils = require "dist.utils"
local pretty = require "pl.pretty"
local path = require "pl.path"

local rocksolver = {}
rocksolver.utils = require "rocksolver.utils"

-- Return the joined manifest table from 'cfg.manifest_repos' locations
function get_manifest()
    -- Download new manifest
    local manifest, err = download_manifest(cfg.manifest_repos)
    if not manifest then return nil, "Error when downloading manifest: " .. err end

    return manifest
end

-- Download manifest from the table of git 'repository_urls' and return manifest
-- table on success and nil and error message on error.
function download_manifest(repository_urls)
    repository_urls = repository_urls or cfg.manifest_repos
    if type(repository_urls) == "string" then repository_urls = {repository_urls} end

    assert(type(repository_urls) == "table", "manifest.download_manifest: Argument 'repository_urls' is not a table or string.")

    local temp_dir = path.join(cfg.root_dir, cfg.temp_dir)

    -- Retrieve manifests from repositories and collect them into one manifest table
    local manifest = {repo_path = {}, packages = {}}

    if #repository_urls == 0 then return nil, "No repository url specified." end

    print("Downloading repository information...")
    for k, repo in pairs(repository_urls) do
        local clone_dir = path.join(temp_dir, "repository_" .. tostring(k))

        -- Clone the repo and add its 'manifest-file' file to the manifest table
        ok, err = git.create_repo(clone_dir)

        local sha
        if ok then sha, err = git.fetch_branch(clone_dir, repo, "master") end
        if sha then ok, err = git.checkout_sha(sha, clone_dir) end

        if not (ok and sha) then
            if not cfg.debug then path.rmdir(clone_dir) end
            return nil, "Error when downloading the manifest from repository with url: '" .. repo .. "': " .. err
        else
            local manifest_file = path.join(clone_dir, cfg.manifest_filename)
            local current_manifest = load_manifest(manifest_file)

            for pkg, info in pairs(current_manifest.packages) do
                -- Keep package info from manifest earlier in 'repository_urls' table if conflicts are found
                if manifest.packages[pkg] == nil then
                    manifest.packages[pkg] = info
                end
            end

            table.insert(manifest.repo_path, current_manifest.repo_path)
        end
        if not cfg.debug then path.rmdir(clone_dir) end
    end

    -- Save the new manifest table to file for debug purposes
    if cfg.debug then
        pretty.dump(manifest, path.join(temp_dir, cfg.manifest_filename))
    end

    return manifest
end

-- Load and return manifest table from the manifest file.
-- If manifest file not present, return nil.
function load_manifest(manifest_file)
    local fd, err = io.open(manifest_file)
    if not fd then
        return nil, err
    end
    local str, err = fd:read("*all")
    fd:close()
    if not str then
        return nil, err
    end
    str = str:gsub("^#![^\n]*\n", "")
     return pretty.read(str)
end
