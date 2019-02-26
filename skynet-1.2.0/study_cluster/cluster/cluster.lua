local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local cluster = require "skynet.cluster"
local masterName = skynet.getenv "master_name"   --"chat"
local masterAddress = skynet.getenv "master_address" --"127.0.0.1:2602"
local slaveName = skynet.getenv "slave_name"
local slaveAddress = skynet.getenv "slave_address"
local logicServer = skynet.getenv "logic_server"   --"chat"

local function  serverName(name, address)
    local rServerName = name .. address
    rServerName = string.replace(rServerName, "%.", "_")
    rServerName = string.replace(rServerName, ":", "_")
    return rServerName
end

local Slave = {nodes = {}}

function  Slave.add(name, address)
    local rSlaveNode = {name = name, address = address}
    local rServerName = serverName(name, address)
    Slave.nodes[rServerName] = rSlaveNode
    log.printTable(log.fatalLevel(), {{rSlaveNode, "add rSlaveNode"}})
end

function  Slave.remove(name, address)
    local rSlaveNode = {name = name, address = address}
    local rServerName = serverName(name, address)
    Slave.nodes[rServerName] = nil
    log.printTable(log.fatalLevel(), {{rSlaveNode, "remove rSlaveNode"}})
end

function  Slave.copy()
    local rNodes = {}
    for _, _node in pairs(Slave.nodes) do
        table.insert(rNodes, _node)
    end
    return rNodes
end

--[[
local Cluster = {nodes = {}}
function  Cluster.add(name, address)
    local rClusterNode = {name = name, address = address}
    local rServerName = serverName(name, address)
    Cluster.nodes[rServerName] = {name = name, address = address}
    log.printTable(log.fatalLevel(), {{rClusterNode, "add rClusterNode"}})
end

function  Cluster.remove(name, address)
    local rClusterNode = {name = name, address = address}
    local rServerName = serverName(name, address)
    Cluster.nodes[rServerName] = nil
    log.printTable(log.fatalLevel(), {{rClusterNode, "remove rClusterNode"}})
end

function  Cluster.copy()
    local rNodes
    for _, _node in pairs(Cluster.nodes) do
        table.insert(rNodes, _node)
    end
    return rNodes
end
]]


local CMD = {}

function  CMD.openAddress(name, address, logicServer)
    local rServerName = serverName(name, address)
    local addrssTable = {}
    addrssTable[rServerName] = address
    cluster.reload(addrssTable)
    local rClusterServer = skynet.self()
    local rClusterServerName = "server"
    cluster.register(rClusterServerName, rClusterServer)
    if logicServer then
        local rLogicServer = skynet.newservice(logicServer)
        local rLogicServerName = name
        cluster.register(rLogicServerName, rLogicServer)
    end
    cluster.open(rServerName)
end

function  CMD.openServer(name, address)
    local rServerName = serverName(name, address)
    local addrssTable = {}
    addrssTable[rServerName] = address
    cluster.reload(addrssTable)

    local rProxyName = rServerName .. "@" .. "server"
    local rProxy = cluster.proxy(rProxyName)	-- cluster.proxy("switch", "@switch")
    return rProxy
end

function  CMD.openNode(name, address)
    local rServerName = serverName(name, address)
    local addrssTable = {}
    addrssTable[rServerName] = address
    cluster.reload(addrssTable)

    local rProxyName = rServerName .. "@" .. name
    local rProxy = cluster.proxy(rProxyName)	-- cluster.proxy("switch", "@switch")
    return rProxy
end

function  CMD.init()
    if slaveName and slaveAddress then
        CMD.openAddress(slaveName, slaveAddress, logicServer)
        Slave.add(masterName, masterAddress)
        local rMasterServer = CMD.openServer(masterName, masterAddress)
        CMD.slaveRegister(rMasterServer, slaveName, slaveAddress)
    else
        CMD.openAddress(masterName, masterAddress, logicServer)
    end
end

function  CMD.slaveRegister(server, name, address)
    local rSlaveRegister = {name = name, address = address}
    local rNodes = skynet.call(server, "lua", "onMasterRegister", rSlaveRegister)
    for _, _node in pairs(rNodes) do
        Slave.add(_node.name, _node.address)
    end
end

function  CMD.onMasterRegister(data)
    local rNodes = Slave.copy()
    for _, _SlaveNode in pairs(Slave.nodes) do
        log.fatal("_SlaveNode.name, _SlaveNode.address", _SlaveNode.name, _SlaveNode.address)
        local rSlaveServer = CMD.openServer(_SlaveNode.name, _SlaveNode.address)
        skynet.call(rSlaveServer, "lua", "onSlaveRegister", data)
    end
    Slave.add(data.name, data.address)
    --Cluster.add(data.name, data.address)
    return rNodes
end

function  CMD.onSlaveRegister(data)
    Slave.add(data.name, data.address)
end






function  CMD.slaveQuit(server, name, address)
    local rSlaveQuit = {name = name, address = address}
    skynet.call(server, "lua", "onMasterQuit", rSlaveQuit)
end

function  CMD.onMasterQuit(data)
    for _, _SlaveNode in pairs(Slave.nodes) do
        log.fatal("_SlaveNode.name, _SlaveNode.address", _SlaveNode.name, _SlaveNode.address)
        local rSlaveServer = CMD.openServer(_SlaveNode.name, _SlaveNode.address)
        skynet.call(rSlaveServer, "lua", "onSlaveQuit", data)
    end
    Slave.remove(data.name, data.address)
    --Cluster.remove(data.name, data.address)
end

function  CMD.onSlaveQuit(data)
    Slave.remove(data.name, data.address)
end




skynet.start(function()
    skynet.dispatch("lua", function(session, address, command, ...)
        print("session, address, command, ... = ", session, address, command, ...)
        local f = CMD[command]
        skynet.ret(skynet.pack(f(...)))

    end)
    skynet.fork(CMD.init)
end)