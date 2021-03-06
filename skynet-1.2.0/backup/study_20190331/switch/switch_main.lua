local skynet = require "skynet"

local max_client = 64

skynet.start(function()
	print("Server start")
	--[[
	skynet.newservice("debug_console", 8000)
	skynet.newservice("switch_cluster")
	local watchdog = skynet.newservice("switch_watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	print("Watchdog listen on", 8888)
	]]
	skynet.newservice("switch_server_harbor")
	skynet.exit()
end)
