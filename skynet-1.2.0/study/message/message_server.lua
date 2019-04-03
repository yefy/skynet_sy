local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local cs
local AgentArr = {}

local CMD = {}

function  CMD.getAgent()
	return AgentArr
end

local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(command, ...)
	local func =  CMD[command]
	if not cs then
		return xpcall_ret(xpcall(func, function() print(debug.traceback()) end, ...))
	else
		return cs(func, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		skynet.ret(skynet.pack(callFunc(command,...)))
	end)
	for i = 1, 3 do
		local agent = skynet.newservice("message_agent")
		table.insert(AgentArr, agent)
	end
	skynet.register "message_server"
	skynet.send("player_server", "lua", "clearAgent", "chat_server")
end)