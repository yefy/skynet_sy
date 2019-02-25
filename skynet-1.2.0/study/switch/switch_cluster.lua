local skynet = require "skynet"
local cluster = require "skynet.cluster"
local snax = require "skynet.snax"

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

function command.ADD(server, m, ip)
    skynet.fork(command.getData, server, m, ip)
    return "OK"
end

function command.getData(server, m, ip)
    print("server, m, ip", server, m, ip)

    local t = {}
    t[server] = ip
    cluster.reload(t)
    local xxx = server.."@" ..m
    print("xxx = ", xxx)
    while true do
        print("*******************proxyChat")
        local proxyChat = cluster.proxy (xxx)	-- cluster.proxy("switch", "@switch")
        print("proxyChat", proxyChat)
        if proxyChat then
            print("proxyChat", pcall(skynet.call, proxyChat, "lua", "GET", "a"))
            --print(skynet.call(proxyChat, "lua", "GET", "b"))
        end
        skynet.sleep(200)
    end
end


function command.register()

    print("********************skynet.getenv master", skynet.getenv "master")
    print("1111111111111111111111111111111111111111")
    print("********************skynet.getenv master******************8")


  cluster.reload {
      switch = "127.0.0.1:2528",
  }

    --local sdb = skynet.newservice("switch_cluster_db")
    -- register name "sdb" for simpledb, you can use cluster.query() later.
    -- See cluster2.lua
    local rSwitch = skynet.self()
    cluster.register("switchServer", rSwitch)

    print(skynet.call(rSwitch, "lua", "SET", "a", "foobar"))
    print(skynet.call(rSwitch, "lua", "SET", "b", "foobar2"))
    print(skynet.call(rSwitch, "lua", "GET", "a"))
    print(skynet.call(rSwitch, "lua", "GET", "b"))

    cluster.open "switch"

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
    skynet.register "SIMPLEDB111"

    skynet.fork(command.register)

end)
