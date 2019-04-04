local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("player start")
	skynet.newservice("player_server")
	skynet.exit()
end)
