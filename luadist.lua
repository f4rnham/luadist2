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
        tree      - print dependency tree of a module

    To get help on specific command, run:

        luadist help <COMMAND>
        ]],
        run = function (deploy_dir, help_item)
            deploy_dir = deploy_dir or cfg.root_dir
            help_item = help_item or {}
            assert(type(deploy_dir) == "string", "luadist.help: Argument 'deploy_dir' is not a string.")
            assert(type(help_item) == "table", "luadist.help: Argument 'help_item' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

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

    You can use * (an asterisk sign) in the name of the module as a wildcard
    with the meaning 'any symbols' (in most shells, the module name then must
    be quoted to prevent the expansion of asterisk by the shell itself).

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

            local ok, err = dist.install(modules, deploy_dir, cmake_variables)
            if not ok then
                print(err)
                os.exit(1)
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
    of LuaDist is used. If no MODULES are specified, all installed modules
    will be removed.

    You can use * (an asterisk sign) in the name of the module as a wildcard
    with the meaning 'any symbols' (in most shells, the module name then must
    be quoted to prevent the expansion of asterisk by the shell itself).

    Optional LuaDist configuration VARIABLES (e.g. -variable=value) can be
    specified.

    WARNING: dependencies between modules are NOT taken into account when
    removing modules!
        ]],

        run = function (deploy_dir, modules)
            error("NYI")
        --[[
            deploy_dir = deploy_dir or cfg.root_dir
            if type(modules) == "string" then modules = {modules} end
            assert(type(deploy_dir) == "string", "luadist.remove: Argument 'deploy_dir' is not a string.")
            assert(type(modules) == "table", "luadist.remove: Argument 'modules' is not a string or table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local num, err = dist.remove(modules, deploy_dir)
            if not num then
                print(err)
                os.exit(1)
            else
               print("Removed modules: " .. num)
               return 0
            end
        ]]
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
            error("NYI")
        --[[
            deploy_dir = deploy_dir or cfg.root_dir
            strings = strings or {}
            assert(type(deploy_dir) == "string", "luadist.list: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.list: Argument 'strings' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local deployed = dist.get_deployed(deploy_dir)
            deployed  = depends.filter_packages_by_strings(deployed, strings)

            print("\nInstalled modules:")
            print("==================\n")
            for _, pkg in pairs(deployed) do
                print("  " .. pkg.name .. "-" .. pkg.version .. "\t(" .. pkg.arch .. "-" .. pkg.type .. ")" .. (pkg.provided_by and "\t [provided by " .. pkg.provided_by .. "]" or ""))
            end
            print()
            return 0
        ]]
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
            error("NYI")
        --[[
            deploy_dir = deploy_dir or cfg.root_dir
            strings = strings or {}
            assert(type(deploy_dir) == "string", "luadist.search: Argument 'deploy_dir' is not a string.")
            assert(type(strings) == "table", "luadist.search: Argument 'strings' is not a table.")
            deploy_dir = pl.path.abspath(deploy_dir)

            local available, err = mf.get_manifest()
            if not available then
                print(err)
                os.exit(1)
            end

            available = depends.filter_packages_by_strings(available, strings)
            available = depends.sort_by_names(available)

            print("\nModules found:")
            print("==============\n")
            for _, pkg in pairs(available) do
                print("  " .. pkg.name)
            end
            print()
            return 0
        ]]
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
            error("NYI")
        --[[
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

            -- if no packages specified explicitly, show just info from .gitmodules for all packages available
            if #modules == 0 then

                modules = manifest
                modules = depends.sort_by_names(modules)
                local deployed = dist.get_deployed(deploy_dir)

                print("")
                for _, pkg in pairs(modules) do
                    print("  " .. pkg.name)
                    print("  Repository url: " .. (pkg.path or "N/A"))
                    print()
                end
                return 0

            -- if some packages explicitly specified, retrieve and show detailed info about them
            else

                if #modules > 5 then
                    print("NOTE: More than 5 modules specified - operation may take a longer time.")
                end

                local deployed = dist.get_deployed(deploy_dir)

                for _, module in pairs(modules) do
                    manifest, err = package.get_versions_info(module, manifest, deploy_dir, deployed)
                    if not manifest then
                        print(err)
                        os.exit(1)
                    end
                end

                modules = depends.find_packages(modules, manifest)
                modules = depends.sort_by_names(modules)

                print("")
                for _, pkg in pairs(modules) do
                    print("  " .. pkg.name .. "-" .. pkg.version .. "  (" .. pkg.arch .. "-" .. pkg.type ..")" .. (pkg.from_installed and "  [info taken from installed version]" or ""))
                    print("  Description: " .. (pkg.desc or "N/A"))
                    print("  Author: " .. (pkg.author or "N/A"))
                    print("  Homepage: " .. (pkg.url or "N/A"))
                    print("  License: " .. (pkg.license or "N/A"))
                    print("  Repository url: " .. (pkg.path or "N/A"))
                    print("  Maintainer: " .. (pkg.maintainer or "N/A"))
                    if pkg.provides then print("  Provides: " .. utils.table_tostring(pkg.provides)) end
                    if pkg.depends then print("  Depends: " .. utils.table_tostring(pkg.depends)) end
                    if pkg.conflicts then print("  Conflicts: " .. utils.table_tostring(pkg.conflicts)) end
                    print("  State: " .. (depends.is_installed(pkg.name, deployed, pkg.version) and "installed" or "not installed"))
                    print()
                end
                return 0
            end
        ]]
        end
    },

    -- Print dependency tree.
    ["tree"] = {
        help = [[
Usage: luadist [DEPLOYMENT_DIRECTORY] tree [MODULES...] [-VARIABLES...]

    The 'tree' command prints dependency tree for specified modules.

    If no MODULES are specified, trees for all available modules are printed.

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

            local lua = {packages = {lua = {[cfg.lua_version] = {}}}}

            local solver = rocksolver.DependencySolver(manifest, cfg.platform)
            local installed = rocksolver.utils.load_manifest(lua, true)

            for k, module in pairs(modules) do
                -- If all modules are being queried, extract the name
                if type(module) == "table" then module = k end

                local dependencies, err = solver:resolve_dependencies(module, installed)
                if not dependencies then
                    print(err)
                    os.exit(1)
                else
                    -- Print the dependency tree
                    local heading = "Dependency tree for '" .. module .. "' (on " .. table.concat(cfg.platform, ", ") .. "):"
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
}

-- Run the functionality of LuaDist 'command' in the 'deploy_dir' with other items
-- or settings/variables starting at 'other_idx' index of special variable 'arg'.
local function run_command(deploy_dir, command, other_idx)
    deploy_dir = deploy_dir or cfg.root_dir
    assert(type(deploy_dir) == "string", "luadist.run_command: Argument 'deploy_dir' is not a string.")
    assert(type(command) == "string", "luadist.run_command: Argument 'command' is not a string.")
    assert(not other_idx or type(other_idx) == "number", "luadist.run_command: Argument 'other_idx' is not a number.")
    deploy_dir = pl.path.abspath(deploy_dir)

    local items = {}
    local cmake_variables = {}

    -- parse items after the command (and LuaDist or CMake variables)
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

            -- not a LuaDist or CMake variable
            else
                table.insert(items, arg[i])
            end
        end
    end

    -- run the required LuaDist functionality
    return commands[command].run(pl.path.abspath(deploy_dir), items, cmake_variables)
end

-- Print information about Luadist (version, license, etc.).
function print_info()
    print([[
FIXME ]].. cfg.version .. [[ - Lua package manager for the LuaDist deployment system.
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
    return run_command(cfg.root_dir, arg[1], 2)
else
    -- unknown command
    if arg[1] then
        print("Unknown command '" .. arg[1] .. "'. Printing help...\n")
        print_help()
        os.exit(1)
    end
    return print_help()
end
