local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"

local AgentArr = {}

local CMD = {}

function  CMD.getAgent()
	return AgentArr
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, commond)
		skynet.ret(skynet.pack(CMD[commond]()))
	end)
	for i = 1, 3 do
		local agent = skynet.newservice("router_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "router_server"
	skynet.send("player_server", "lua", "clearAgent", "chat_server")
end)