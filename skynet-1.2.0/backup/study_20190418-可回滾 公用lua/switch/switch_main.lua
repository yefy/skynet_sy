local skynet = require "skynet"
local log = require "common/log"

skynet.start(function()
	log.fatal("switch_listen start")
	skynet.newservice("switch_listen")
end)