local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("player_server start")
	skynet.newservice("player_server")
	skynet.exit()
end)
