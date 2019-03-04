local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		log.print(log.fatalLevel(), command, log.getArgvData(...))
		skynet.ret(skynet.pack(""))
	end)
	skynet.register "switch_harbor"
end)
