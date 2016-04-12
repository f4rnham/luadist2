module("dist.log", package.seeall)

local cfg = require "dist.config"
local logging = require "logging"
require "logging.file"
require "logging.console"

local logger_console
local logger_file

function reload_config()
    logger_console = logging.console("%level %message\n")
    logger_file = logging.file(cfg.log_file_abs)

    if cfg.logging.print_log_level then
        logger_console:setLevel(cfg.print_log_level)
    else
        logger_console = nil
    end

    if cfg.logging.write_log_level then
        logger_file:setLevel(cfg.write_log_level)
    else
        logger_file = nil
    end
end

reload_config()

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

return logger
