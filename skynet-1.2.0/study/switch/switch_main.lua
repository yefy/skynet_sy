local skynet = require "skynet"
local log = require "common/log"
--[[
local max_client = 64

skynet.start(function()
	log.fatal("switch start")
	skynet.newservice("debug_console", 8000)
	local watchdog = skynet.newservice("switch_watchdog")
	skynet.call(watchdog, "lua", "start", {
		port = 8888,
		maxclient = max_client,
		nodelay = true,
	})
	log.fatal("Watchdog listen on", 8888)
end)
]]

skynet.start(function()
	log.fatal("switch_listen start")
	skynet.newservice("switch_listen")
end)