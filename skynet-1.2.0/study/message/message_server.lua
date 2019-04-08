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
		local agent = skynet.newservice("message_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "message_server"
	skynet.send("server_server", "lua", "register", "message_server")
end)