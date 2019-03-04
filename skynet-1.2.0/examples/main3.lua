local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.doHello()
	print("doHello")
	local rRet = skynet.call("main2", "lua", "hello", "main3")
	print("rRet = ", rRet)
end

function CMD.hello(...)
	print("main2.lua : hello = ", ...)
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, command, ...)
		print("session, address, command, ... = ", session, address, command, ...)
		local f = CMD[command]
		if not f then
			print("not find command", command)
			skynet.ret(skynet.pack(nil))
			return
		end
		skynet.ret(skynet.pack(f(...)))
	end)
	skynet.register("main3")
	skynet.register(".main3")
	skynet.fork(CMD.doHello)
	--skynet.fork(CMD.doHello2)
	--skynet.fork(CMD.doHello3)
	--skynet.monitor("main22", true)
end)
