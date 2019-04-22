local skynet = require "skynet"

skynet.start(function()
	print("slave_server")
	skynet.newservice("slave_server")
	skynet.exit()
end)
