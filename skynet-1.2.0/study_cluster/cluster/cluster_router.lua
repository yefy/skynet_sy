local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local cluster = require "skynet.cluster"
local masterName = skynet.getenv "master_name"   --"chat"
local masterAddress = skynet.getenv "master_address" --"127.0.0.1:2602"

math.randomseed(tostring(os.time()):reverse():sub(1, 7)) --设置时间种子

local function  nodeName(name, address)
    local rNodeName = name .. address
    rNodeName = string.replace(rNodeName, "%.", "_")
    rNodeName = string.replace(rNodeName, ":", "_")
    return rNodeName
end

local SlaveNodes = {}
local Slave = {}

function  Slave.add(name, address)
    local rSlaveNodes = SlaveNodes[name]
    if not rSlaveNodes then
        rSlaveNodes = {}
        SlaveNodes[name] = rSlaveNodes
    end

    local rSlaveNode = {name = name, address = address}
    local rSlaveNodeName = nodeName(name, address)
    rSlaveNodes[rSlaveNodeName] = rSlaveNode
    log.printTable(log.fatalLevel(), {{rSlaveNode, "add rSlaveNode"}})
end

function  Slave.get(name)
    local rSlaveNodes = SlaveNodes[name]
    return rSlaveNodes
end

function  Slave.remove(name, address)
    local rSlaveNode = {name = name, address = address}
    log.printTable(log.fatalLevel(), {{rSlaveNode, "remove rSlaveNode"}})

    local rSlaveNodes = SlaveNodes[name]
    if not rSlaveNodes then
        return
    end

    local rSlaveNodeName = nodeName(name, address)
    rSlaveNodes[rSlaveNodeName] = nil
end

function  Slave.copy()
    local rSlaveNodes = {}
    for _, _slaveNodes in pairs(SlaveNodes) do
        for _, _slaveNode in pairs(_slaveNodes) do
            table.insert(rSlaveNodes, _slaveNode)
        end
    end
    return rSlaveNodes
end

local CMD = {}

function  CMD.add(name, address)
    Slave.add(name, address)
end

function  CMD.remove(name, address)
    local rNodeName = nodeName(name, address)
    local rNodes = {}
    rNodes[rNodeName] = nil
    cluster.reload(rNodes)
    return Slave.remove(name, address)
end

function  CMD.copy()
    return Slave.copy()
end

function  CMD.nodeName(name, address)
    return nodeName(name, address)
end


function  CMD.openAddress(name, address, serverName, server)
    local rNodeName = nodeName(name, address)
    local rNodes = {}
    rNodes[rNodeName] = address
    cluster.reload(rNodes)
    local rServerName = serverName
    local rServer = server
    cluster.register(rServerName, rServer)
    cluster.open(rNodeName)
end

function  CMD.register(name, addr)
    cluster.register(name, addr)
end


function  CMD.openMaster()
    local rNodeName = nodeName(masterName, masterAddress)
    local rNodes = {}
    rNodes[rNodeName] = masterAddress
    cluster.reload(rNodes)

    local rProxyName = rNodeName .. "@" .. "master"
    local rProxy = cluster.proxy(rProxyName)	-- cluster.proxy("switch", "@switch")
    return rProxy
end

function  CMD.openSlave(name, address)
    local rNodeName = nodeName(name, address)
    local rNodes = {}
    rNodes[rNodeName] = address
    cluster.reload(rNodes)

    local rProxyName = rNodeName .. "@" .. "slave"
    local rProxy = cluster.proxy(rProxyName)	-- cluster.proxy("switch", "@switch")
    return rProxy
end

function  CMD.openRandSlave(name)
    local rSlaveNodes = Slave.get(name)

    while not rSlaveNodes do
        log.error("is null : name", name)
        skynet.sleep(100)
        rSlaveNodes = Slave.get(name)
    end

    local rTmpSlaveNodes = {}
    for _, _slaveNode in pairs(rSlaveNodes) do
        table.insert(rTmpSlaveNodes, _slaveNode)
    end

    local rIndex = math.random(1, #rTmpSlaveNodes)
    local rSlaveNode = rTmpSlaveNodes[rIndex]

    return CMD.openSlave(rSlaveNode.name, rSlaveNode.address)
end

function  CMD.send(address, funcName, ...)
    skynet.send("system_slave", "lua", "routerRequest", address, funcName, ...)
end

function  CMD.call(address, funcName, ...)
    return skynet.call("system_slave", "lua", "routerRequest", address, funcName, ...)
end


return CMD