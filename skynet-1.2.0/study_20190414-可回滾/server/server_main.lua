local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("server start")
	skynet.newservice("server_server")
	skynet.exit()
end)
