local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

local uidAgent = {}
local serverMap = {}

function  server.getAgent(uid)
	local agent = uidAgent[uid]
	if not agent then
		agent = skynet.newservice("server_agent")
		skynet.call(agent, "lua", "server_server", "registerMap", serverMap)
		uidAgent[uid] = agent
	end
	log.trace("agent", agent)
	return 0, agent
end

function  server.register(source, serverName, unLock)
	log.fatal("register source, serverName, unLock", source, serverName, unLock)
	serverMap[serverName] = unLock and "" or "lock"
	for _, agent in pairs(uidAgent) do
		skynet.call(agent, "lua", "server_server", "register", serverName, serverMap[serverName])
	end
	return 0
end

dispatch.start(function ()
	skynet.register "server_server"
end)