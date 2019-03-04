local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local masterName = skynet.getenv "master_name"   --"chat"
local masterAddress = skynet.getenv "master_address" --"127.0.0.1:2602"
local slaveName = skynet.getenv "slave_name"
local slaveAddress = skynet.getenv "slave_address"
local logicServer = skynet.getenv "logic_server"
local router = require "cluster/cluster_router"

skynet.start(function()
    if slaveName and slaveAddress then
        local rServer = skynet.newservice("cluster_slave")
        router.openAddress(slaveName, slaveAddress,"slave", rServer)
        skynet.send(rServer, "lua", "init", slaveName, slaveAddress, logicServer)
    else
        local rServer = skynet.newservice("cluster_master")
        router.openAddress(masterName, masterAddress, "master", rServer)
        skynet.send(rServer, "lua", "init", masterName, masterAddress, logicServer)
    end
    skynet.exit()
end)