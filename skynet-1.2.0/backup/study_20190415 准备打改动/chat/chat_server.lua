local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"

local AgentArr = {}
function  dispatch.getAgent()
	return 0, AgentArr
end

dispatch.start(function ()
	--[[
	for i = 1, 3 do
		local agent = skynet.newservice("chat_agent")
		log.fatal("chat_server.lua agent", agent)
		table.insert(AgentArr, agent)
	end
	skynet.register "chat_server"
	skynet.send("server_server", "lua", "register", "chat_server")
	]]
	local agent = skynet.newservice("chat_agent")
	skynet.call(agent, "lua", "aaa", 123, 987)
end)

