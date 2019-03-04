local skynet = require "skynet"

skynet.start(function()
	print("chat_server start")
	--skynet.newservice("chat_cluster")
	--skynet.newservice("chat_server")
	skynet.newservice("chat_server_harbor")
	skynet.exit()
end)
