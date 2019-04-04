local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local Client = dispatch.Client
local Server = dispatch.Server

local uidAgent = {}

function  Server.getAgent(uid)
	local agent = uidAgent[uid]
	if not agent then
		agent = skynet.newservice("player_agent")
		uidAgent[uid] = agent
	end
	log.fatal("agent", agent)
	return 0, agent
end

function  Server.clearAgent(serverName)
	for _, agent in pairs(uidAgent) do
		skynet.send(agent, "lua", "player_agent", "clearAgent", serverName)
	end
	return 0
end

dispatch.actionCs()
dispatch.start(function ()
	skynet.register "player_server"
end)