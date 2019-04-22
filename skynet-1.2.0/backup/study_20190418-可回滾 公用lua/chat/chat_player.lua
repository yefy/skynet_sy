local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

function dispatch:stats()
    skynet.sleep(100)
    log.fatal("id, uid, statsNumber", skynet.self(), self:getKey(), self.statsNumber)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    self.statsNumber = 0
    skynet.fork(self["stats"], self)
end


function  dispatch:chat(session, data)
    self.statsNumber = self.statsNumber + 1
    log.printTable(log.allLevel(), {{data, "data"}})
    return 0, data
end

return dispatch