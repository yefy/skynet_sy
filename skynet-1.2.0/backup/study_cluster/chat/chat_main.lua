local skynet = require "skynet"

skynet.start(function()
	print("chat_server start")
	skynet.newservice("chat_cluster")
	skynet.newservice("chat_server")
	skynet.exit()
end)
