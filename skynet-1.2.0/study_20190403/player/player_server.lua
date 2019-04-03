local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
local cs = queue()  -- cs 是一个执行队列
local uidAgent = {}


local CMD = {}
function  CMD.getAgent(uid)
	local agent = uidAgent[uid]
	if not agent then
		agent = skynet.newservice("player_agent")
		uidAgent[uid] = agent
	end
	log.fatal("agent", agent)
	return agent
end

function  CMD.clearAgent(serverName)
	for _, agent in pairs(uidAgent) do
		skynet.send(agent, "lua", "player_agent", "clearAgent", serverName)
	end
end


local traceback = debug.traceback

local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(command, ...)
	local func =  CMD[command]
	if not cs then
		return xpcall_ret(xpcall(func, traceback, ...))
	else
		return cs(func, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		log.fatal("command, ...", command, log.getArgvData(...))
		skynet.ret(skynet.pack(callFunc(command,...)))
	end)
	skynet.register "player_server"
end)