local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("master start")
	skynet.newservice("debug_console", 8000)
end)