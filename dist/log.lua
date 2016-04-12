module("dist.log", package.seeall)

local cfg = require "dist.config"
local logging = require "logging"
require "logging.file"
require "logging.console"

local logger_console = logging.console("%level %message\n")
local logger_file = logging.file(cfg.logging.file)

if cfg.logging.print_log_level then
    logger_console:setLevel(cfg.logging.print_log_level)
else
    logger_console = nil
end

if cfg.logging.write_log_level then
    logger_file:setLevel(cfg.logging.write_log_level)
else
    logger_file = nil
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

return logger
