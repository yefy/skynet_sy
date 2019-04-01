local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
local cs = queue()  -- cs 是一个执行队列

local CMD = {}
local uidAgent = {}

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
		skynet.send(agent, "lua", "clearAgent", serverName)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		log.fatal("command, ...", command, log.getArgvData(...))
		local func = CMD[command]
		if not func then
			log.error("nil func command", command)
			skynet.ret()
			return
		else
			skynet.ret(skynet.pack(cs(func,...)))
		end
	end)
	skynet.register "player_server"
end)