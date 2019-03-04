local skynet = require "skynet"
local cluster = require "skynet.cluster"
local snax = require "skynet.snax"

skynet.start(function()
	cluster.reload {
		db = "127.0.0.1:2528",
		db2 = "127.0.0.1:2529",
	}

	local sdb = skynet.newservice("simpledb")
	local sdb2 = skynet.newservice("simpledb")
	-- register name "sdb" for simpledb, you can use cluster.query() later.
	-- See cluster2.lua
	cluster.register("sdb", sdb)
	cluster.register("sdb2", sdb2)

	print(skynet.call(sdb, "lua", "SET", "a", "sdb1_1"))
	print(skynet.call(sdb, "lua", "SET", "b", "sdb1_2"))
	print(skynet.call(sdb, "lua", "GET", "a"))
	print(skynet.call(sdb, "lua", "GET", "b"))
	print(skynet.call(sdb2, "lua", "SET", "a", "sdb2_1"))
	print(skynet.call(sdb2, "lua", "SET", "b", "sdb2_s2"))
	print(skynet.call(sdb2, "lua", "GET", "a"))
	print(skynet.call(sdb2, "lua", "GET", "b"))


	cluster.open "db"
	cluster.open "db2"
	-- unique snax service
	snax.uniqueservice "pingserver"
end)
