local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"

local _AgentArr = {}

function  dispatch.getAgent(uid)
	local index = uid % #_AgentArr
	return 0, _AgentArr[index]
end

dispatch.start(function ()
	for i = 1, 3 do
		local agent = skynet.newservice("player_agent")
		table.insert(_AgentArr, agent)
	end
	skynet.register "player_server"
	skynet.call("server_server", "lua", "register", "player_server")
end)