local skynet = require "skynet"
local log = require "common/log"
local router = require "cluster/cluster_router"

local CMD = {}

function CMD.hello(...)
	log.fatal("master_main.lua : hello", ...)
	return "i am master"
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, command, ...)
		print("session, address, command, ... = ", session, address, command, ...)
		local f = CMD[command]
		if not f then
			log.error("not find command", command)
			skynet.ret(skynet.pack(nil))
			return
		end
		skynet.register("master111")
		skynet.ret(skynet.pack(f(...)))
	end)
end)