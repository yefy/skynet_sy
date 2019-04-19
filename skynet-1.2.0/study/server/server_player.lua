local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local harbor = require("skynet.harbor")
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
    commonConfig = require(commonConfig)
end

function dispatch:stats()
    skynet.sleep(100)
    log.fatal("id, uid, sumStatsNumber, statsNumber", skynet.self(), self:getKey(), self.sumStatsNumber, self.statsNumber)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    self.statsNumber = 0
    self.sumStatsNumber = 0
    skynet.fork(self["stats"], self)
    self.server = {}
end

function dispatch:register(serverName)
    local server = self.server[serverName]
    if not server then
        server = {server = nil, agent = nil, callNumber = 0, isNew = true, newCS = queue()}
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

function dispatch:checkAgent(server, serverName)
    server.newCS(function ()
        if server.isNew then
            local sleepNumber = 0
            while server.callNumber > 0 do
                skynet.sleep(5)
                sleepNumber = sleepNumber + 5
                if sleepNumber > 100 * 3 then
                    break
                end
            end
            if server.callNumber > 0 then
                log.error("强制接入服务 serverName, uid", serverName, self:getKey())
            end
            server.isNew = false
            server.callNumber = 0
            server.server = harbor.queryname(serverName)
            _, server.agent = skynet.call(server.server, "lua", "getAgent", self:getKey())
            if not server.agent then
                log.error("not agent  serverName, uid", serverName, self:getKey())
            end
        end
    end)
end

function dispatch:sendClient(serverName, command, pack)
    local server = self.server[serverName]
    if not server then
        log.error("not serverName", serverName)
        return systemError.invalidServer
    end
    self:checkAgent(server, serverName)

    server.callNumber = server.callNumber + 1
    local error, data =  skynet.call(server.agent, "client", command, pack)
    server.callNumber = server.callNumber - 1

    self.statsNumber = self.statsNumber + 1
    self.sumStatsNumber = self.sumStatsNumber + 1
    return error, data
end

function dispatch:callClient(session, pack)
    if commonConfig.serverAgentBenchmark == "server_agent_ping" then
        self.statsNumber = self.statsNumber + 1
        self.sumStatsNumber = self.sumStatsNumber + 1
        return systemError.invalid
    end

    local head = self:getHead(session)
    log.printTable(log.allLevel(), {{head, "head"}})
    return self:sendClient(head.server, head.command, pack)
end

function dispatch:callServer(serverName, ...)
    local server = self.server[serverName]
    self:checkAgent(server, serverName)
    server.callNumber = server.callNumber + 1
    local ret = {skynet.call(server.agent, "lua",  ...)}
    server.callNumber = server.callNumber - 1
    return table.unpack(ret)
end


return dispatch