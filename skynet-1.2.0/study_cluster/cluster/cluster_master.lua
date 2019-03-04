local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local router = require "cluster/cluster_router"

local CMD = {}

function  CMD.init(slaveName, slaveAddress, logicServer)
    local rServer = skynet.newservice("cluster_slave")
    router.register("slave", rServer)
    skynet.send(rServer, "lua", "init", slaveName, slaveAddress, logicServer)
end

function  CMD.onMasterRegister(data)
    local rSlaveNodes = router.copy()
    for _, _SlaveNode in pairs(rSlaveNodes) do
        local rSlaveServer = router.openSlave(_SlaveNode.name, _SlaveNode.address)
        skynet.call(rSlaveServer, "lua", "onSlaveRegister", data)
    end
    log.fatal("onMasterRegister")
    router.add(data.name, data.address)
    return rSlaveNodes
end

function  CMD.onMasterQuit(data)
    local rQuitSlaveNodeName = router.nodeName(data.name, data.address)
    local rSlaveNodes = router.copy()
    for _, _SlaveNode in pairs(rSlaveNodes) do
        local rSlaveNodeName = router.nodeName(_SlaveNode.name, _SlaveNode.address)
        if rSlaveNodeName ~= rQuitSlaveNodeName then
            local rSlaveServer = router.openSlave(_SlaveNode.name, _SlaveNode.address)
            skynet.call(rSlaveServer, "lua", "onSlaveQuit", data)
        end
    end
    router.remove(data.name, data.address)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, command, ...)
        print("session, address, command, ... = ", session, address, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
end)