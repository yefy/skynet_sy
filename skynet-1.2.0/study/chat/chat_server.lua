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
		local agent = skynet.newservice("chat_agent")
		log.fatal("chat_server.lua agent", agent)
		table.insert(AgentArr, agent)
	end
	skynet.register "chat_server"
	skynet.send("player_server", "lua", "clearAgent", "chat_server")
end)

