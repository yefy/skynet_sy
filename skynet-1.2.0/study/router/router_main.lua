local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("router_server start")
	skynet.newservice("router_server")
	skynet.exit()
end)
