local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
dispatch.actionConfig({"cmd/chat_agent_cmd"})
dispatch.actionClass("chat_player")
dispatch.start(function ()
end)