local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local thread = skynet.getenv "thread"

local _AgentArr = {}
function  dispatch.getAgent(uid)
	local index = uid % #_AgentArr + 1
	return 0, _AgentArr[index]
end

dispatch.start(function ()
	for i = 1, thread * 3 do
		local agent = skynet.newservice("chat_agent")
		table.insert(_AgentArr, agent)
	end
	skynet.register "chat_server"
	skynet.send("server_server", "lua", "register", "chat_server")
end)

