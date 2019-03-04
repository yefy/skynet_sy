local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local router = require "cluster/cluster_router"

local CMD = {}
local LogicServer

function  CMD.init(slaveName, slaveAddress, logicServer)
    if logicServer then
        LogicServer = skynet.newservice(logicServer)
        --LogicServer = require(logicServer)
    end
    CMD.slaveRegister(slaveName, slaveAddress)
    --CMD.router("init")
end

function  CMD.slaveRegister(name, address)
    local server = router.openMaster()
    local rSlaveRegister = {name = name, address = address}
    local rNodes = skynet.call(server, "lua", "onMasterRegister", rSlaveRegister)
    log.fatal("slaveRegister")
    for _, _node in pairs(rNodes) do
        router.add(_node.name, _node.address)
    end
    CMD.onSlaveRegister(rSlaveRegister)
end

function  CMD.onSlaveRegister(data)
    log.fatal("onSlaveRegister")
    router.add(data.name, data.address)
end


function  CMD.slaveQuit(name, address)
    local server = router.openMaster()
    local rSlaveQuit = {name = name, address = address}
    skynet.call(server, "lua", "onMasterQuit", rSlaveQuit)
    CMD.onSlaveQuit(rSlaveQuit)
end

function  CMD.onSlaveQuit(data)
    router.remove(data.name, data.address)
end

function  CMD.routerRespond(funcName, ...)
    if LogicServer then
        return skynet.call(LogicServer, "lua", funcName, ...)
    end
end

function  CMD.routerRequest(address, funcName, ...)
    local rSlaveServer = router.openRandSlave(address)
    return skynet.call(rSlaveServer, "lua", "routerRespond", funcName, ...)
end

skynet.start(function()
    skynet.dispatch("lua", function(session, address, command, ...)
        print("session, address, command, ... = ", session, address, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))
    end)
    skynet.register("system_slave")
end)