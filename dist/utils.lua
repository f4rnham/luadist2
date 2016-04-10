-- System functions

module ("dist.utils", package.seeall)

local pl = require "pl.import_into"()


-- Obtain LuaDist location by checking available package locations
function get_luadist_location()
  local paths = {}
  package.path:gsub("([^;]+)", function(c) table.insert(paths, c) end)

  for _, curr_path in pairs(paths) do
    if (pl.path.isabs(curr_path) and curr_path:find("[/\\]lib[/\\]lua[/\\]%?.lua$")) then
      -- Remove path to lib/lua
      curr_path = curr_path:gsub("[/\\]lib[/\\]lua[/\\]%?.lua$", "")
      -- Clean the path up a bit
      curr_path = curr_path:gsub("[/\\]bin[/\\]%.[/\\]%.%.", "")
      curr_path = curr_path:gsub("[/\\]bin[/\\]%.%.", "")
      return curr_path
    end
  end
  return nil
end

-- Return string argument quoted for a command line usage.
function quote(argument)
    assert(type(argument) == "string", "utils.quote: Argument 'argument' is not a string.")

    -- replace '/' path separators for '\' on Windows
    if pl.path.is_windows and argument:match("^[%u%U.]?:?[/\\].*") then
        argument = argument:gsub("//","\\"):gsub("/","\\")
    end

    -- Windows doesn't recognize paths starting with two slashes or backslashes
    -- so we double every backslash except for the first one
    if pl.path.is_windows and argument:match("^[/\\].*") then
        local prefix = argument:sub(1,1)
        argument = argument:sub(2):gsub("\\",  "\\\\")
        argument = prefix .. argument
    else
        argument = argument:gsub("\\",  "\\\\")
    end
    argument = argument:gsub('"',  '\\"')

    return '"' .. argument .. '"'
end

-- Concatenates string values from table into single space separated string
-- If argument is nil, returns empty string
-- If arguments is string itself, returns it
function table_concat(tbl)
    if type(tbl) == "string" then
        return tbl
    end

    res = ""
    for _, v in pairs(tbl or {}) do
        if res == "" then
            res = v
        else
            res = res .. " " .. v
        end
    end

    return res
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
