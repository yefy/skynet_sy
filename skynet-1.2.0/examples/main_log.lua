local skynet = require "skynet"
local harbor = require "skynet.harbor"
require "skynet.manager"	-- import skynet.monitor

local function monitor_master()
	harbor.linkmaster()
	print("master is down")
	skynet.exit()
end


local function monitor_master222()
	skynet.newservice("testharborlink")
end

skynet.start(function()
	print("Log server start")
	skynet.monitor "simplemonitor"
	local log = skynet.newservice("globallog")
	skynet.fork(monitor_master)
	skynet.fork(monitor_master222)
end)

