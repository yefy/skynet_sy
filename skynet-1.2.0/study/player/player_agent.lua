local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
dispatch.actionConfig({"cmd/player_agent_cmd"})
dispatch.actionClass("player_player")
dispatch.actionParseRouter()
dispatch.actionServerCS()
dispatch.actionClientCS()
dispatch.start(function ()
end)