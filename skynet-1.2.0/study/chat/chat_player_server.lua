local skynet = require "skynet"
local log = require "common/log"
local dispatchServer = require ("common/dispatch_server")
local server = class("server", dispatchServer)


local statsNumber = 0
local function stats()
    skynet.sleep(100)
    log.fatal("id, statsNumber", skynet.self(), statsNumber)
    statsNumber = 0
    skynet.fork(stats)
end

function server:ctor(...)
    self.super:ctor(...)
    skynet.fork(stats)
end

function server:aaa(...)
    statsNumber = statsNumber + 1
    log.fatal("...", log.getArgvData(...))
    return 0
end

return server