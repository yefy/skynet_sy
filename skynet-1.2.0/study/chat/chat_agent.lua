local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
--dispatch.actionClass("chat_player")
function dispatch.aaa(...)
    log.fatal("aaa ...", log.getArgvData(...))
    return 0
end
dispatch.start(function ()
end)