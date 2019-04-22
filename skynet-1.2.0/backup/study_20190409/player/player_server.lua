local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

local AgentArr = {}

function  server.getAgent(source)
	return 0, AgentArr
end

dispatch.start(nil, function ()
	for i = 1, 3 do
		local agent = skynet.newservice("player_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "player_server"
	skynet.call("server_server", "lua", "register", "player_server")
end)