local skynet = require "skynet"
local cluster = require "skynet.cluster"

local function test22()
	print("cluster22.lua", pcall(cluster.call,"db", "@sdb", "GET", "a"))
	print("cluster22.lua", pcall(cluster.call,"db2", "@sdb", "GET", "b"))
	print("cluster22.lua", pcall(cluster.call,"db", "@sdb2", "GET", "a"))
	print("cluster22.lua", pcall(cluster.call,"db2", "@sdb2", "GET", "b"))
	skynet.sleep(200)
	skynet.fork(test22)
end

skynet.start(function()
	skynet.fork(test22)
end)
