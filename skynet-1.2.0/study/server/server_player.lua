local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
    commonConfig = require(commonConfig)
end



function dispatch:stats()
    skynet.sleep(100)
    log.fatal("id, uid, statsNumber", skynet.self(), self:getUid(), self.statsNumber)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
    self.server = {}
end

function dispatch:register(serverName)
    local server = self.server[serverName]
    if not server then
        server = {agent = nil, callNumber = 0, isNew = false, cs = queue()}
        self.server[serverName] = server
    else
        server.isNew = true
    end
    return 0
end

function dispatch:registerMap(serverNameMap)
    for _serverName, _ in pairs(serverNameMap) do
        self:register(_serverName)
    end
    return 0
end

function dispatch:doCallClient(serverName, command, pack)
    local server = self.server[serverName]
    if not server then
        log.error("not serverName", serverName)
        return systemError.invalidServer
    end

    server.cs(function ()
        if server.isNew then
            local sleepNumber = 0
            if server.callNumber > 0 then
                skynet.sleep(100 * 3)
            end
            if server.callNumber > 0 then
                log.error("强制接入服务 serverName, uid", serverName, self:getUid())
            end
            server.isNew = false
            server.agent = nil
            server.callNumber = 0
        end
    end)


    if not server.agent then
        _, server.agent = skynet.call(serverName, "lua", "getAgent", self:getUid())
    end

    if not server.agent then
        log.error("not agent  serverName, command, uid, pack", serverName, command, self:getUid(), pack)
        return systemError.invalidServer
    end
    server.callNumber = server.callNumber + 1
    local error, data =  skynet.call(server.agent, "client", command, pack)
    server.callNumber = server.callNumber - 1
    return error, data
end

function dispatch:callClient(pack)
    self.statsNumber = self.statsNumber + 1
    if commonConfig.serverAgentBenchmark == "server_agent_ping" then
        return systemError.invalid
    end

    local headMsg, headSize, _ = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if head then
        log.printTable(log.allLevel(), {{head, "head"}})
        return self:doCallClient(head.server, head.command, pack)
    else
        log.error("parse head nil")
        return systemError.invalid
    end
end

return dispatch