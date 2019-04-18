local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("message_server start")
	skynet.newservice("message_server")
	skynet.exit()
end)
