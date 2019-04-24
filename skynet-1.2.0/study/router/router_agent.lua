local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local socket = require "skynet.socket"
local dispatch = require "common/dispatch"
local requestAddr = skynet.getenv("requestAddr")
local _FD

local _RouterMap = {}

local _StatsNumber = 0
local _SumStatsNumber = 0
local _PackMap = {}

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
    _RouterMap[token] = nil
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
--[[
    if true then
        _RouterMap[handle..session] = nil
        return
    end
]]
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

function dispatch.getSocket()
    if not _FD then
        _FD = socket.open(requestAddr)
    end
    return _FD
end

function dispatch.writeSocket(pack)
    local fd = dispatch.getSocket()
    socket.write(fd, pack)
end

function dispatch.addPack(sessionStr, pack)
    if _PackMap[sessionStr] then
        log.error("_PackMap[session]", sessionStr)
    end
    _PackMap[sessionStr] = pack
end

function dispatch.delPack(sessionStr)
    if not _PackMap[sessionStr] then
        log.error("not _PackMap[session]", sessionStr)
    end
    _PackMap[sessionStr] = nil
end

function dispatch.sendPack(destUid, sessionStr, pack)
    local head = {
        ver = 1,
        session = sessionStr,
        server = "router_service",
        command = "request",
        type = "request",
        destUid = destUid,
        error = 0,
    }

    local headMsg = protobuf.encode("base.Head",head)
    local headPack = string.pack_package(headMsg)

    local dataPack = string.pack_package(headPack .. pack)
    dispatch.addPack(sessionStr, dataPack)
    dispatch.writeSocket(dataPack)
end
function dispatch.recvPack()
end

function dispatch.parsePack(pack)
    local headMsg, headSize, _ = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if not head then
        log.error("parse head nil")
        return
    end
    if head.type == "respond" then

    end
end

function dispatch.respond(head)
    dispatch.delPack(head.sessionStr)
end

function dispatch.request(dataPack)
    local pack, packSize, _ = string.unpack_package(dataPack)
    local headMsg, headSize, bodyPack = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if not head then
        log.error("parse head nil")
        return
    end

    if head.type == "call" then
        dispatch.routerCall(dataPack)
    elseif head.type == "send" then
        dispatch.routerSend(dataPack)
    elseif head.type == "ret" then
        dispatch.routerRet(dataPack)
    end
end

function dispatch.routerCall(dataPack)

end

function dispatch.routerSend(dataPack)

end

function dispatch.routerRet(head, bodyPack)
    local bodyMsg, bodySz, _ = string.unpack_package(bodyPack)
    local handle = 0
    local session = 0
    skynet.resume(handle, session, skynet.unpack(bodyMsg, bodySz))
end

dispatch.start(function ()
    skynet.fork(stats)
end)