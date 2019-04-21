local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

function dispatch:stats()
    skynet.sleep(1000)
    log.fatal("id, uid, sumStatsNumber, statsNumber", skynet.self(), self:getKey(), self.sumStatsNumber, self.statsNumber)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    self.statsNumber = 0
    self.sumStatsNumber = 0
    skynet.fork(self["stats"], self)
end


function  dispatch:chat(token, data)
    log.printTable(log.allLevel(), {{data, "data"}})
    local chatRet = {self:callServer(token, "player_server", "isLogin", "chat")}
    log.printTable(log.traceLevel(), {{chatRet, "chatRet"}})
    self.statsNumber = self.statsNumber + 1
    self.sumStatsNumber = self.sumStatsNumber + 1
    return 0, data
end

return dispatch