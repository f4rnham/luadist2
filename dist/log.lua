local logging = require "logging"
require "logging.file"
require "logging.console"

local logger_console = nil
local logger_file = nil

function reload_config(cfg, hook)
    if cfg.print_log_level then
        logger_console = logging.console("%level %message\n")
        -- Hack to prevent "changling loglevel..." message
        logger_console.level = nil
        logger_console:setLevel(cfg.print_log_level)
    else
        logger_console = nil
    end

    if cfg.write_log_level then
        logger_file = logging.file(cfg.log_file_abs)
        -- Hack to prevent "changling loglevel..." message
        logger_file.level = nil
        logger_file:setLevel(cfg.write_log_level)
    else
        logger_file = nil
    end
end

local logger = logging.new(
function(self, level, message)
    if logger_console then
        logger_console:log(level, message)
    end

    if logger_file then
        logger_file:log(level, message)
    end

    return true
end)

return {logger = logger, reload_config = reload_config}
