local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
dispatch.actionConfig({"cmd/message_agent_cmd"})
dispatch.actionClass("message_player")
dispatch.start(function ()
end)