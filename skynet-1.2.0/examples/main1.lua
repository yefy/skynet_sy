local skynet = require "skynet"
require "skynet.manager"

local CMD = {}

function CMD.hello(...)
	while true do
		skynet.sleep(100)
	end
	print("main1.lua : hello = ", ...)
	skynet.send("main2", "lua", "hello", "main11111")
	return "main1"
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
	skynet.register("main1")
end)
