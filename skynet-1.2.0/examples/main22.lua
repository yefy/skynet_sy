local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.doHello()
	skynet.send(".main2", "lua", "hello", "main222222222222222222")
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, command, ...)
		print("session, address, command, ... = ", session, address, command, ...)
		--[[
		local f = CMD[command]
		if not f then
			print("not find command", command)
			skynet.ret(skynet.pack(nil))
			return
		end
		skynet.ret(skynet.pack(f(...)))
		]]
	end)
	--skynet.fork(CMD.doHello)
end)
