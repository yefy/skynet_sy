local skynet = require "skynet"
local cluster = require "skynet.cluster"


require "skynet.manager"	-- import skynet.register
local db = {}

local command = {}

function command.GET(key)
	print("---yefy **************simpledb.lua:GET  ", key, db[key])
	return db[key]
end

function command.SET(key, value)
	print("---yefy **************simpledb.lua:SET  ", key, value)
	local last = db[key]
	db[key] = value
	return last
end

function command.register()
	cluster.reload {
		switch = "127.0.0.1:2528",
	}
	local proxySwitch = cluster.proxy "switch@switchServer"	-- cluster.proxy("switch", "@switch")
	print(skynet.call(proxySwitch, "lua", "GET", "a"))
	print(skynet.call(proxySwitch, "lua", "GET", "b"))

	cluster.reload {
		--switch = "127.0.0.1:2528",
		chat = "127.0.0.1:2529",
	}

	--local sdb = skynet.newservice("switch_cluster_db")
	-- register name "sdb" for simpledb, you can use cluster.query() later.
	-- See cluster2.lua
	local rChat = skynet.self()
	cluster.register("chatServer", rChat)

	print(skynet.call(rChat, "lua", "SET", "a", "foobar111111111111111111"))
	print(skynet.call(rChat, "lua", "SET", "b", "foobar22222222222222222"))
	print(skynet.call(rChat, "lua", "GET", "a"))
	print(skynet.call(rChat, "lua", "GET", "b"))

	cluster.open "chat"
	print(skynet.call(proxySwitch, "lua", "ADD", "chat", "chatServer", "127.0.0.1:2529"))
	--print(skynet.call(proxySwitch, "lua", "GET", "b"))

	--[[
        local proxy = cluster.proxy "db@sdb"	-- cluster.proxy("db", "@sdb")
        print(skynet.call(proxy, "lua", "SET", "a", "foobar"))
        print(skynet.call(proxy, "lua", "SET", "b", "foobar2"))
        print(skynet.call(proxy, "lua", "GET", "a"))
        print(skynet.call(proxy, "lua", "GET", "b"))
    ]]
	--[[
        print(cluster.call("db", "@sdb", "GET", "a"))
        print(cluster.call("db", "@sdb", "SET", "a", "foobar"))
        print(cluster.call("db", "@sdb", "SET", "b", "foobar2"))
        print(cluster.call("db", "@sdb", "GET", "a"))
        print(cluster.call("db", "@sdb", "GET", "b"))
    ]]
	-- unique snax service
	--snax.uniqueservice "pingserver"
end

skynet.start(function()
	--[[
	cluster.reload {
		switch = "127.0.0.1:2528",
	}
	local proxySwitch = cluster.proxy "switch@switchServer"	-- cluster.proxy("switch", "@switch")
	print(skynet.call(proxySwitch, "lua", "GET", "a"))
	print(skynet.call(proxySwitch, "lua", "GET", "b"))
	]]

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
	skynet.dispatch("lua", function(session, address, cmd, ...)
		cmd = cmd:upper()
		if cmd == "PING" then
			assert(session == 0)
			local str = (...)
			if #str > 20 then
				str = str:sub(1,20) .. "...(" .. #str .. ")"
			end
			skynet.error(string.format("%s ping %s", skynet.address(address), str))
			return
		end
		local f = command[cmd]
		if f then
			skynet.ret(skynet.pack(f(...)))
		else
			error(string.format("Unknown command %s", tostring(cmd)))
		end
	end)
	--	skynet.traceproto("lua", false)	-- true off tracelog
	skynet.register "SIMPLEDB222"
	skynet.fork(command.register)
end)
