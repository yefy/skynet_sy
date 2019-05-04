local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

function dispatch:stats()
    skynet.sleep(1000)
    log.fatal("id, uid, sumStatsNumber, statsNumber, sumStatsNumberRouter, statsNumberRouter, sumStatsNumberServer, statsNumberServer", skynet.self(), self:getKey(), self.sumStatsNumber, self.statsNumber, self.sumStatsNumberRouter, self.statsNumberRouter, self.sumStatsNumberServer, self.statsNumberServer)
    self.statsNumber = 0
    self.statsNumberRouter = 0
    self.statsNumberServer = 0
    skynet.fork(self["stats"], self)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    self.statsNumber = 0
    self.sumStatsNumber = 0
    self.statsNumberRouter = 0
    self.sumStatsNumberRouter = 0
    self.statsNumberServer = 0
    self.sumStatsNumberServer = 0
    skynet.fork(self["stats"], self)
end


function  dispatch:login(token, data)
    self.statsNumber = self.statsNumber + 1
    self.sumStatsNumber = self.sumStatsNumber + 1
    log.printTable(log.allLevel(), {{data, "data"}})
    return 0, data
end

function  dispatch:router(token, data)
    self.statsNumber = self.statsNumber + 1
    self.sumStatsNumber = self.sumStatsNumber + 1
    log.printTable(log.fatalLevel(), {{data, "router data"}})
    local error, routerData = self:callRouter(token, "player_server", "routerMessage", data.message)
    log.fatal("error, routerData", error, routerData)
    return 0, data
end

function  dispatch:routerMessage(token, message)
    self.statsNumberRouter = self.statsNumberRouter + 1
    self.sumStatsNumberRouter = self.sumStatsNumberRouter + 1
    log.fatal("key, message", self:getKey(), message)
    return 0, "routerMessage"
end

function  dispatch:isLogin(data)
    log.all("isLogin data", data)
    self.statsNumberServer = self.statsNumberServer + 1
    self.sumStatsNumberServer = self.sumStatsNumberServer + 1
    return 0, 1, 2, 3, "123"
end

return dispatch