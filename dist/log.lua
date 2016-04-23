local logging = require "logging"
require "logging.file"
require "logging.console"

local logger_console = nil
local logger_file = nil
local logger_hook = nil

function reload_config(cfg, hook)
    logger_console = logging.console("%level %message\n")
    logger_file = logging.file(cfg.log_file_abs)

    if cfg.print_log_level then
        logger_console:setLevel(cfg.print_log_level)
    else
        logger_console = nil
    end

    if cfg.write_log_level then
        logger_file:setLevel(cfg.write_log_level)
    else
        logger_file = nil
    end

    logger_hook = hook
end

local logger = logging.new(
function(self, level, message)
    if logger_console then
        logger_console:log(level, message)
    end

    if logger_file then
        logger_file:log(level, message)
    end

    if logger_hook then
        logger_hook(level, message)
    end

    return true
end)

return {logger = logger, reload_config = reload_config}
