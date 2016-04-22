#!/usr/bin/env lua

-- Command line interface to Luadist.

local dist = require "dist"
local utils = require "dist.utils"
local mf = require "dist.manifest"
local cfg = require "dist.config"
local pl = require "pl.import_into"()
local rocksolver = {}
rocksolver.DependencySolver = require "rocksolver.DependencySolver"
rocksolver.utils = require "rocksolver.utils"


-- CLI commands of Luadist.
local commands
commands = {

    -- Print help for this command line interface.
    ["help"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] <COMMAND> [ARGUMENTS...] [-VARIABLES...]

    Commands:

        help      - print this help
        install   - install modules
        remove    - remove modules
        list      - list installed modules
        info      - show information about modules
        search    - search repositories for modules
        depends   - print dependencies of a module
        fetch     - fetch source repository of a module

    To get help on specific command, run:

        luadist help <COMMAND>
        ]],
        run = function (deploy_dir, help_item)
            help_item = help_item or {}
            assert(type(help_item) == "table", "luadist.help: Argument 'help_item' is not a table.")

            if not help_item or not commands[help_item[1]] then
                help_item = "help"
            else
                help_item = help_item[1]
            end

            print_info()
            print(commands[help_item].help)
            return 0
        end
    },

    -- Install modules.
    ["install"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] install MODULES... [-VARIABLES...]

    The 'install' command will install specified MODULES to
    DEPLOYMENT_DIRECTORY. LuaDist will also automatically resolve, download
    and install all dependencies.

    If DEPLOYMENT_DIRECTORY is not specified, the deployment directory
    of LuaDist is used.

    Optional CMake VARIABLES in -D format (e.g. -Dvariable=value) or LuaDist
    configuration VARIABLES (e.g. -variable=value) can be specified.
        ]],

        run = function (deploy_dir, modules, cmake_variables)
            deploy_dir = deploy_dir or cfg.root_dir
            if type(modules) == "string" then modules = {modules} end
            cmake_variables = cmake_variables or {}

            assert(type(deploy_dir) == "string", "luadist.install: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.install: Argument 'modules' is not a string or table.")
            assert(type(cmake_variables) == "table", "luadist.install: Argument 'cmake_variables' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            if #modules == 0 then
                print("No modules to install specified.")
                return 0
            end

            local ok, err, status = dist.install(modules, deploy_dir, cmake_variables)
            if not ok then
                print(err)
                os.exit(status)
            else
                print("Installation successful.")
                return 0
            end
        end
    },

    -- Remove modules.
    ["remove"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] remove MODULES... [-VARIABLES...]

    The 'remove' command will remove specified MODULES from
    DEPLOYMENT_DIRECTORY. If no module is specified, all modules
    will be removed.

    If DEPLOYMENT_DIRECTORY is not specified, the deployment directory
    of LuaDist is used.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.

    WARNING: dependencies between modules are NOT taken into account when
    removing modules!
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or cfg.root_dir
            if type(modules) == "string" then modules = {modules} end

            assert(type(deploy_dir) == "string", "luadist.remove: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.remove: Argument 'modules' is not a string or table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            -- If no module is specified, all modules will be removed
            if #modules == 0 then
                modules = dist.get_installed(deploy_dir)
            end

            local num, err = dist.remove(modules, deploy_dir)
            if not num then
                print(err)
                os.exit(1)
            else
               print("Removed modules: " .. num)
               return 0
            end
        end
    },

    -- List installed modules.
    ["list"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] list [STRINGS...] [-VARIABLES...]

    The 'list' command will list all modules installed in specified
    DEPLOYMENT_DIRECTORY, which contain one or more optional STRINGS.

    If DEPLOYMENT_DIRECTORY is not specified, the deployment directory
    of LuaDist is used. If STRINGS are not specified, all installed modules
    are listed.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.
        ]],

        run = function (deploy_dir, strings)
            deploy_dir = deploy_dir or cfg.root_dir
            strings = strings or {}

            assert(type(deploy_dir) == "string", "luadist.list: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.list: Argument 'strings' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local deployed = dist.get_installed(deploy_dir)

            print("\nInstalled modules:")
            print("==================\n")
            for _, pkg in pairs(deployed) do
                if utils.name_matches(pkg, strings) then
                    print("  " .. pkg)
                end
            end
            return 0
        end
    },

    -- Search for modules in repositories.
    ["search"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] search [STRINGS...] [-VARIABLES...]

    The 'search' command will list all modules from repositories, which contain
    one or more STRINGS.

    If no STRINGS are specified, all available modules are listed.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.
        ]],

        run = function (deploy_dir, strings)
            deploy_dir = deploy_dir or cfg.root_dir
            strings = strings or {}

            assert(type(deploy_dir) == "string", "luadist.search: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.search: Argument 'strings' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local manifest, err = mf.get_manifest()
            if not manifest then
                print(err)
                os.exit(1)
            end

            print("\nModules found:")
            print("==============\n")
            for _, pkg in pairs(manifest) do
                if utils.name_matches(pkg, strings) then
                    print("  " .. pkg.name)
                end
            end
            return 0
        end
    },

    -- Show information about modules.
    ["info"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] info [MODULES...] [-VARIABLES...]

    The 'info' command shows information about specified modules from
    repositories. This command also shows whether modules are installed
    in DEPLOYMENT_DIRECTORY.

    If no MODULES are specified, all available modules are shown.
    If DEPLOYMENT_DIRECTORY is not specified, the deployment directory
    of LuaDist is used.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or cfg.root_dir
            modules = modules or {}
            assert(type(deploy_dir) == "string", "luadist.info: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.info: Argument 'modules' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local manifest, err = mf.get_manifest()
            if not manifest then
                print(err)
                os.exit(1)
            end

            -- If no packages specified explicitly, show just list all packages from manifest
            if #modules == 0 then
                for _, pkg in pairs(manifest.packages) do
                    print("  " .. pkg.name)
                end
                return 0
            -- If some packages explicitly specified, retrieve and show detailed info about them
            else
                if #modules > 5 then
                    print("NOTE: More than 5 modules specified - operation may take a longer time.")
                end

                local installed = dist.get_installed(deploy_dir)
                local rockspecs, err = dist.get_rockspec(deploy_dir, modules)
                if not rockspecs then
                    print(err)
                    os.exit(1)
                end

                for pkg, rockspec in pairs(rockspecs) do
                    print("  " .. pkg)
                    print("  Description: " .. ((rockspec.description and rockspec.description.summary) or "N/A"))
                    print("  Homepage: " .. ((rockspec.description and rockspec.description.homepage) or "N/A"))
                    print("  License: " .. ((rockspec.description and rockspec.description.license) or "N/A"))
                    print("  Repository url: " .. ((rockspec.source and rockspec.source.url) or "N/A"))
                    print("  Maintainer: " .. ((rockspec.description and rockspec.description.maintainer) or "N/A"))
                    if rockspec.dependencies then print("  Dependencies: " .. table.concat(rockspec.dependencies, "\n                ")) end
                    print("  State: " .. (installed[pkg.name] and "installed as version" .. installed[pkg.name] or "not installed"))
                    print()
                end
                return 0
            end
        end
    },

    -- Print dependencies.
    ["depends"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] depends [MODULES...] [-VARIABLES...]

    The 'depends' command prints dependencies for specified modules.

    If no MODULES are specified, dependencies for all available modules are printed.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.
        ]],

        run = function (deploy_dir, modules)
            deploy_dir = deploy_dir or cfg.root_dir
            modules = modules or {}
            assert(type(deploy_dir) == "string", "luadist.info: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.info: Argument 'modules' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local manifest, err = mf.get_manifest()
            if not manifest then
                print(err)
                os.exit(1)
            end

            -- If no modules specified explicitly, assume all modules
            if #modules == 0 then modules = manifest.packages end

            local solver = rocksolver.DependencySolver(manifest, cfg.platform)

            for k, module in pairs(modules) do
                -- If all modules are being queried, extract the name
                if type(module) == "table" then module = k end

                local dependencies, err = solver:resolve_dependencies(module, {})
                if not dependencies then
                    print(err)
                    os.exit(1)
                else
                    -- Print the dependencies
                    local heading = "Dependencies for '" .. module .. "' (on " .. table.concat(cfg.platform, ", ") .. "):"
                    print("\n" .. heading .. "")
                    print(string.rep("=", #heading) .. "\n")

                    for _, pkg in pairs(dependencies) do
                        print("  " .. pkg)
                    end
                end
            end
            return 0
        end
    },

   ["fetch"] = {
        help = [[
Usage: luadist [DOWNLOAD_DIRECTORY] fetch [MODULES...] [-VARIABLES...]

    The 'fetch' command downloads source repositories of specified modules
    into provided DOWNLOAD_DIRECTORY.

    If no DOWNLOAD_DIRECTORY is provided, modules are downloaded to
    temp directory of current LuaDist installation.

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.
        ]],

        run = function (download_dir, modules)
            download_dir = download_dir or cfg.temp_dir_abs
            modules = modules or {}

            assert(type(download_dir) == "string", "luadist.fetch: Argument 'download_dir' is not a string.")
            assert(type(modules) == "table", "luadist.fetch: Argument 'modules' is not a table.")
            download_dir = pl.path.abspath(download_dir)

            if #modules == 0 then
                print("No modules to fetch specified")
            else
                local downloads, err = dist.fetch(download_dir, modules)
                if downloads then
                    print("Fetched modules:")
                    for pkg, path in pairs(downloads) do
                        print(pkg .. ": " .. path)
                    end
                else
                    print(err)
                    os.exit(1)
                end
            end
            return 0
        end
    },
}

-- Run the functionality of LuaDist 'command' in the 'deploy_dir' with other items
-- or settings/variables starting at 'other_idx' index of special variable 'arg'.
local function run_command(deploy_dir, command, other_idx)
    assert(not deploy_dir or type(deploy_dir) == "string", "luadist.run_command: Argument 'deploy_dir' is not a string.")
    assert(type(command) == "string", "luadist.run_command: Argument 'command' is not a string.")
    assert(not other_idx or type(other_idx) == "number", "luadist.run_command: Argument 'other_idx' is not a number.")

    local items = {}
    local cmake_variables = {}

    -- Parse items after the command (and LuaDist or CMake variables)
    if other_idx then
        for i = other_idx, #arg do

            -- CMake variable
            if arg[i]:match("^%-D(.-)=(.*)$") then
                local variable, value = arg[i]:match("^%-D(.-)=(.*)$")
                cmake_variables[variable] = value

            -- LuaDist variable
            elseif arg[i]:match("^%-(.-)=(.*)$") then
                local variable, value = arg[i]:match("^%-(.-)=(.*)$")
                apply_settings(variable, value)

            -- LuaDist boolean variable with implicit 'true' value
            elseif arg[i]:match("^%-(.-)$") then
                local variable, value = arg[i]:match("^%-(.-)$")
                apply_settings(variable, "true")

            -- Not a LuaDist or CMake variable
            else
                table.insert(items, arg[i])
            end
        end
    end

    -- Run the required LuaDist functionality
    return commands[command].run(deploy_dir, items, cmake_variables)
end

-- Print information about Luadist (version, license, etc.).
function print_info()
    print([[
Luadist2 ]].. cfg.version .. [[ - Lua package manager for the LuaDist deployment system.
Released under the MIT License. See FIXME
          ]])
    return 0
end

-- Convenience function for printing the main luadist help.
function print_help()
    return run_command(nil, "help")
end

-- Set the LuaDist 'variable' to the 'value'.
-- See available settings in 'dist.config' module.
function apply_settings(variable, value)
    assert(type(variable) == "string", "luadist.apply_settings: Argument 'variable' is not a string.")
    assert(type(value) == "string", "luadist.apply_settings: Argument 'value' is not a string.")

    -- check whether the settings variable exists
    if cfg[variable] == nil then
        print("Unknown LuaDist configuration option: '" .. variable .. "'.")
        os.exit(1)

    -- ensure the right type

    elseif type(cfg[variable]) == "boolean" then
        value = value:lower()
        if value == "true" or value == "yes" or value == "on" or value == "1" then
            value = true
        elseif value == "false" or value == "no" or value == "off" or value == "0" then
            value = false
        else
            print("Value of LuaDist option '" .. variable .. "' must be a boolean.")
            os.exit(1)
        end

    elseif type(cfg[variable]) == "number" then
        value = tonumber(value)
        if not value then
            print("Value of LuaDist option '" .. variable .. "' must be a number.")
            os.exit(1)
        end

    elseif type(cfg[variable]) == "table" then
        local err
        value, err = utils.make_table(value, ",")
        if not value then
            print("Error when parsing the LuaDist variable '" .. variable .. "': " .. err)
            os.exit(1)
        end
    end

    -- set the LuaDist variable
    cfg[variable] = value

end

-- Parse command line input and run the required command.
if not commands[arg[1]] and commands[arg[2]] then
    -- deploy_dir specified
    return run_command(arg[1], arg[2], 3)
elseif commands[arg[1]] then
    -- deploy_dir not specified
    return run_command(nil, arg[1], 2)
else
    -- unknown command
    if arg[1] then
        print("Unknown command '" .. arg[1] .. "'. Printing help...\n")
        print_help()
        os.exit(1)
    end
    return print_help()
end
