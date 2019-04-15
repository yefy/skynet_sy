local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)


local statsNumber = 0
local function stats()
    skynet.sleep(100)
    log.fatal("id, statsNumber", skynet.self(), statsNumber)
    statsNumber = 0
    skynet.fork(stats)
end

function dispatch:ctor(...)
    self.super:ctor(...)
    skynet.fork(stats)
end


function  dispatch.chat(session, data)
    statsNumber = statsNumber + 1
    local rChatRequest = data
    log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
    log.fatal("start messageTest")
    return 0, rChatRequest
end




function dispatch:aaa(...)
    statsNumber = statsNumber + 1
    log.fatal("uid", self:getUid())
    log.fatal("aaa ...", log.getArgvData(...))
    return 0
end

return dispatch