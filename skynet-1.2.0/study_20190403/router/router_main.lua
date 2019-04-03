local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("router_server start")
	--skynet.newservice("chat_cluster")
	skynet.newservice("router_server")
	--skynet.newservice("chat_server_harbor")
	skynet.exit()
end)
