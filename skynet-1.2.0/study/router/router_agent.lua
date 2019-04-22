local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"

local _RouterMap = {}

local _StatsNumber = 0
local _SumStatsNumber = 0

local function stats()
    skynet.sleep(1000)
    log.fatal("_sumStatsNumber, _statsNumber", _SumStatsNumber, _StatsNumber)
    _StatsNumber = 0
    skynet.fork(stats)
end

local function recvRespond(pack)
    local dataMsg, dataSz, _ = string.unpack_package(pack)
    local headMsg, headSz, bodyPack = string.unpack_package(dataMsg)
    local handle, routerSession = skynet.unpack(headMsg, headSz)
    local bodyMsg, bodySz, _ = string.unpack_package(bodyPack)
    local token = handle..routerSession
    if not _RouterMap[token] then
        log.error("not token, handle, routerSession", token, handle, routerSession)
        skynet.exit()
        return
    end

    log.trace("handle, routerSession, headMsg, bodyMsg = ", handle, routerSession, headMsg, bodyMsg)
    skynet.resume(handle, routerSession, skynet.unpack(bodyMsg, bodySz))
    _RouterMap[token] = false
    _StatsNumber =  _StatsNumber + 1
    _SumStatsNumber = _SumStatsNumber + 1
end

local function recvRequest(pack)
    local dataMsg, dataSz, _ = string.unpack_package(pack)
    local headMsg, headSz, bodyPack = string.unpack_package(dataMsg)
    local handle, routerSession, serverName, command, sourceUid, destUid = skynet.unpack(headMsg, headSz)
    log.trace("handle, routerSession, serverName, command, sourceUid, destUid", handle, routerSession, serverName, command, sourceUid, destUid)
    local bodyMsg, bodySz, _ = string.unpack_package(bodyPack)

    local _, agent = skynet.call("server_server", "lua", "getAgent", destUid)

    local retMsg, retSz = skynet.pack(skynet.call(agent, "lua", "callServer", destUid, serverName, command, destUid, skynet.unpack(bodyMsg, bodySz)))
    ---todo
    if true then
        local headMsg, headSz = skynet.pack(handle, routerSession)
        local headStr = skynet.tostring(headMsg, headSz)
        skynet.trash(headMsg, headSz)
        local headPack = string.pack_package(headStr)
        local bodyStr = skynet.tostring(retMsg, retSz)
        skynet.trash(retMsg, retSz)
        local bodyPack = string.pack_package(bodyStr)
        local pack = string.pack_package(headPack..bodyPack)
        log.trace("pack = ", pack)
        skynet.fork(recvRespond, pack)
    end
end

function dispatch.router(destUid, handle, session, pack)
    local token = handle..session
    if  _RouterMap[token] then
        log.error("exit token, handle, session", token, handle, session)
        skynet.exit()
        return
    end
    _RouterMap[token] = true
    log.trace("destUid, handle, session, pack", destUid, handle, session, pack)
    log.trace("pack", pack)
    skynet.fork(recvRequest, pack)
    return 0
end

dispatch.start(function ()
    skynet.fork(stats)
end)