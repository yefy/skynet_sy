local skynet = require "skynet"
local cluster = require "skynet.cluster"

skynet.start(function()
	cluster.reload {
		db = "127.0.0.1:25280",
		db2 = "127.0.0.1:25290",
	}

	skynet.newservice("cluster22")
	print("cluster2.lua", pcall(cluster.call,"db", "@sdb", "GET", "a"))
	print("cluster2.lua", pcall(cluster.call,"db2", "@sdb", "GET", "b"))
	print("cluster2.lua", pcall(cluster.call,"db", "@sdb2", "GET", "a"))
	print("cluster2.lua", pcall(cluster.call,"db2", "@sdb2", "GET", "b"))

	skynet.sleep(1)
	cluster.reload {
		db = false,	-- db is down
	}

	print("cluster2.lua", pcall(cluster.call,"db", "@sdb", "GET", "a"))
	print("cluster2.lua", pcall(cluster.call,"db2", "@sdb", "GET", "b"))
	print("cluster2.lua", pcall(cluster.call,"db", "@sdb2", "GET", "a"))
	print("cluster2.lua", pcall(cluster.call,"db2", "@sdb2", "GET", "b"))
	--[[
	local proxy = cluster.proxy "db@sdb"	-- cluster.proxy("db", "@sdb")
	---yefy
	--local largekey = string.rep("X", 128*1024)
	--local largevalue = string.rep("R", 100 * 1024)
	local largekey = string.rep("X", 3)
	local largevalue = string.rep("R", 5)
	skynet.call(proxy, "lua", "SET", largekey, largevalue)
	local v = skynet.call(proxy, "lua", "GET", largekey)
	assert(largevalue == v)
	skynet.send(proxy, "lua", "PING", "proxy")


	skynet.fork(function()
		skynet.trace("cluster")
		print(cluster.call("db", "@sdb", "GET", "a"))
		print(cluster.call("db2", "@sdb", "GET", "b"))
		cluster.send("db2", "@sdb", "PING", "db2:longstring" .. largevalue)
	end)


skynet.sleep(500)
	-- test snax service
	skynet.timeout(300,function()
		cluster.reload {
			db = false,	-- db is down
			db3 = "127.0.0.1:2529"
		}
		print(pcall(cluster.call, "db", "@sdb", "GET", "a"))	-- db is down
		print(cluster.call("db3", "@sdb", "GET", "b"))
	end)


	skynet.sleep(500)

	cluster.reload { __nowaiting = false }
	local pingserver = cluster.snax("db3", "pingserver")
	print(pingserver.req.ping "hello")
	]]
end)
