local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("chat_server start")
	skynet.newservice("chat_server")
	skynet.exit()
end)
