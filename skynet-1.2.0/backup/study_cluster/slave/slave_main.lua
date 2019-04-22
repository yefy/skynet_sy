local skynet = require "skynet"
local log = require "common/log"
local router = require "cluster/cluster_router"

local CMD = {}

function CMD.helloMaster()
	local rRet = router.call("master", "hello", "i am slave")
	log.fatal("slave_main.lua : rRet", rRet)
	rRet = router.call("slave", "helloSelf", "i am self")
	log.fatal("slave_main.lua : rRet", rRet)
end

function CMD.helloSelf(...)
	log.fatal("slave_main.lua : helloSelf", ...)
	return "i am self"
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
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.fork( CMD.helloMaster)
end)