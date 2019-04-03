local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("player start")
	--skynet.newservice("chat_cluster")
	skynet.newservice("player_server")
	--skynet.newservice("chat_server_harbor")
	skynet.exit()
end)
