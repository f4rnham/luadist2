-- Working with manifest and dist.info files

module ("dist.manifest", package.seeall)

local cfg = require "dist.config"
local git = require "dist.git"
local utils = require "dist.utils"
local pl = require "pl.import_into"()


-- Return the joined manifest table from 'cfg.manifest_repos' locations
local manifest = nil
function get_manifest()
    -- Download manifest if this is first time we are requesting it in this run,
    -- otherwise it is cached in memory until luadist is terminated
    if manifest == nil then
        manifest, err = download_manifest(cfg.manifest_repos)
        if not manifest then return nil, "Error when downloading manifest: " .. err end
    end

    return manifest
end

-- Download manifest from the table of git 'manifest_urls' and return manifest
-- table on success and nil and error message on error.
function download_manifest(manifest_urls)
    manifest_urls = manifest_urls or cfg.manifest_repos
    if type(manifest_urls) == "string" then manifest_urls = {manifest_urls} end

    assert(type(manifest_urls) == "table", "manifest.download_manifest: Argument 'manifest_urls' is not a table or string.")

    local temp_dir = pl.path.join(cfg.root_dir, cfg.temp_dir)

    -- Retrieve manifests from repositories and collect them into one manifest table
    local manifest = {repo_path = {}, packages = {}}

    if #manifest_urls == 0 then return nil, "No manifest url specified." end

    log:info("Downloading manifest information...")
    for k, repo in pairs(manifest_urls) do
        local clone_dir = pl.path.join(temp_dir, "manifest_" .. tostring(k))

        -- Clone the repo and add its 'manifest-file' file to the manifest table
        ok, err = git.create_repo(clone_dir)

        local sha
        if ok then sha, err = git.fetch_branch(clone_dir, repo, "master") end
        if sha then ok, err = git.checkout_sha(sha, clone_dir) end

        if not (ok and sha) then
            if not cfg.debug then
                pl.dir.rmtree(clone_dir)
            end

            return nil, "Error when downloading the manifest from repository with url: '" .. repo .. "': " .. err
        else
            local manifest_file = pl.path.join(clone_dir, cfg.manifest_filename)
            local current_manifest = load_manifest(manifest_file)

            for pkg, info in pairs(current_manifest.packages) do
                -- Keep package info from manifest earlier in 'manifest_urls' table if conflicts are found
                if manifest.packages[pkg] == nil then
                    manifest.packages[pkg] = info
                end
            end

            table.insert(manifest.repo_path, current_manifest.repo_path)
        end
        if not cfg.debug then
            pl.dir.rmtree(clone_dir)
        end
    end

    -- Save the new manifest table to file for debug purposes
    if cfg.debug then
        pl.pretty.dump(manifest, pl.path.join(temp_dir, cfg.manifest_filename))
    end

    return manifest
end

-- Load (by using provided 'load_fnc') and return table
-- from lua file 'filename', if file is not present, return nil.
local function load_file(filename, load_fnc)
    local fd, err = io.open(filename)
    if not fd then
        return nil, err
    end
    local str, err = fd:read("*all")
    fd:close()
    if not str then
        return nil, err
    end

    -- Remove "#!/usr/bin lua" like lines since they are not valid Lua
    -- but seem to be present in rockspec files
    str = str:gsub("^#![^\n]*\n", "")
    str = str:gsub("\n#![^\n]*\n", "")
    return load_fnc(str)
end

-- Load and return manifest table from the manifest file,
-- if manifest file is not present, return nil.
function load_manifest(manifest_file)
    return load_file(manifest_file, pl.pretty.read)
end

-- Load and return rockspec table from the rockspec file,
-- if rockspec file is not present, return nil.
function load_rockspec(rockspec_file)
    return load_file(rockspec_file, pl.pretty.load)
end
