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
		local agent = skynet.newservice("router_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "router_server"
	skynet.call("server_server", "lua", "register", "router_server")
end)