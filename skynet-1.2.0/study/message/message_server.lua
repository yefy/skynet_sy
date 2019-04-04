local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local Client = dispatch.Client
local Server = dispatch.Server

local AgentArr = {}

function  Server.getAgent()
	return 0, AgentArr
end

dispatch.start(function ()
	for i = 1, 3 do
		local agent = skynet.newservice("message_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "message_server"
	skynet.send("player_server", "lua", "clearAgent", "chat_server")
end)