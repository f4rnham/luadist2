-- System functions

module ("dist.utils", package.seeall)

local path = require "pl.path"

-- Obtain LuaDist location by checking available package locations
function get_luadist_location()
  local paths = {}
  local path = package.path:gsub("([^;]+)", function(c) table.insert(paths, c) end)

  for _, path in pairs(paths) do
    if (sys.is_abs(path) and path:find("[/\\]lib[/\\]lua[/\\]%?.lua$")) then
      -- Remove path to lib/lua
      path = path:gsub("[/\\]lib[/\\]lua[/\\]%?.lua$", "")
      -- Clean the path up a bit
      path = path:gsub("[/\\]bin[/\\]%.[/\\]%.%.", "")
      path = path:gsub("[/\\]bin[/\\]%.%.", "")
      return path
    end
  end
  return nil
end

-- Return string argument quoted for a command line usage.
function quote(argument)
    assert(type(argument) == "string", "utils.quote: Argument 'argument' is not a string.")

    -- replace '/' path separators for '\' on Windows
    if path.is_windows() and argument:match("^[%u%U.]?:?[/\\].*") then
        argument = argument:gsub("//","\\"):gsub("/","\\")
    end

    -- Windows doesn't recognize paths starting with two slashes or backslashes
    -- so we double every backslash except for the first one
    if path.is_windows() and argument:match("^[/\\].*") then
        local prefix = argument:sub(1,1)
        argument = argument:sub(2):gsub("\\",  "\\\\")
        argument = prefix .. argument
    else
        argument = argument:gsub("\\",  "\\\\")
    end
    argument = argument:gsub('"',  '\\"')

    return '"' .. argument .. '"'
end

-- Print elements of table in a structured way, for debugging only
function print_table(tbl, indent)
  if not indent then indent = 0 end
  for k, v in pairs(tbl) do
    formatting = string.rep("  ", indent) .. k .. ": "
    if type(v) == "table" then
      print(formatting)
      print_table(v, indent + 1)
    else
      print(formatting .. tostring(v))
    end
  end
end
