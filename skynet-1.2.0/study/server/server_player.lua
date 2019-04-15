local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
    commonConfig = require(commonConfig)
end

require "common/proto_create"
local protobuf = require "pblib/protobuf"

function dispatch:stats()
    skynet.sleep(100)
    log.fatal("id, class, uid, statsNumber", skynet.self(), self, self:getUid(), self.statsNumber)
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
        server = {callNumber = 0, isNew = false}
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



function dispatch:doCallServer(server, command, pack)
    local  _, agent = skynet.call(server, "lua", "getAgent")
    return skynet.call(agentArr[rand], "client", command, pack)
end

function dispatch:callServer(pack)
    log.trace("pack", pack)
    log.trace("commonConfig.serverAgentBenchmark", commonConfig.serverAgentBenchmark)
    self.statsNumber = self.statsNumber + 1
    if commonConfig.serverAgentBenchmark == "server_agent_ping" then
        return systemError.invalid
    end

    local headMsg, headSize, _ = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if head then
        log.printTable(log.allLevel(), {{head, "head"}})
        return self:doCallServer(head.server, head.command, pack)
    else
        log.error("parse head nil")
        return systemError.invalid
    end
end

return dispatch