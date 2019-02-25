local skynet = require "skynet"

skynet.start(function()
	print("master_server")
	skynet.newservice("master_server")
	skynet.exit()
end)
