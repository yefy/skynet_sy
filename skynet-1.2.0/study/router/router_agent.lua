local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local socket = require "skynet.socket"
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"
local mysql = require "skynet.db.mysql"
local _CS = queue()




local _DB

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

function dispatch.router(sourceUid, handle, session, pack)
    local token = handle..session
    if  _RouterMap[token] then
        log.error("exit token, handle, session", token, handle, session)
        skynet.exit()
        return
    end
    _RouterMap[token] = true
    log.trace("destUid, handle, session, pack", sourceUid, handle, session, pack)
    log.trace("pack", pack)
    skynet.fork(recvRequest, pack)
    return 0
end






















function dispatch.getSocket()
    --[[
    if not _FD then
        _FD = socket.open(requestAddr)
    end
    return _FD
    ]]
end

function dispatch.writeSocket(pack)
    --[[
    local fd = dispatch.getSocket()
    socket.write(fd, pack)
    ]]
end

function dispatch.readSocket(sessionStr)
    local head = {
        ver = 1,
        session = sessionStr,
        server = "router_service",
        command = "request",
        type = "respond",
        error = 0,
    }

    local headMsg = protobuf.encode("base.Head", head)
    return string.pack_package(headMsg)
end


function dispatch.addPack(sessionStr, pack)
    if _PackMap[sessionStr] then
        log.error("_PackMap[sessionStr]", sessionStr)
    end
    _PackMap[sessionStr] = pack
end

function dispatch.delPack(sessionStr)
    if not _PackMap[sessionStr] then
        log.error("not _PackMap[sessionStr]", sessionStr)
    end
    _PackMap[sessionStr] = nil
end


function dispatch.server_router(sourceUid, sessionStr, serverName, dataPack)
    return dispatch.saveToRequestDB("TopicTest", sourceUid, serverName, dataPack)
    --dispatch.sendRequestPack(sourceUid, sessionStr, pack)
    --dispatch.recvRespondPack(sessionStr)
end

function dispatch.saveToRequestDB(regionName, sourceUid, serverName, dataPack)
    log.fatal("saveToRequestDB regionName, sourceUid, serverName, pack", regionName, sourceUid, serverName, dataPack)
    _CS(function ()
        local res = _DB:query("insert into rocketmqRouter_request (regionName, serverName, userId, body) "
                .. "values (\'" .. regionName .. "\', \'" .. serverName .. "\'," ..sourceUid ..", \'" .. dataPack .."\')")
        if res.errno then
            log.printTable(log.fatalLevel(), {{res, "saveToRequestDB error res"}})
        end
    end)
    return 0
end

function dispatch.saveToRespondDB(regionName, sourceUid, serverName, pack)
    log.fatal("saveToRespondDB regionName, sourceUid, serverName, pack", regionName, sourceUid, serverName, pack)
    _CS(function ()
        local res = _DB:query("insert into rocketmqrouter_respond (regionName, serverName, userId, body) "
                .. "values (\'" .. regionName .. "\', \'" .. serverName .. "\'," ..sourceUid ..", \'" .. pack .."\')")
        if res.errno then
            log.printTable(log.fatalLevel(), {{res, "saveToRespondDB error res"}})
        end
    end)
    return 0
end

local requesToRespondDBId = 0
function dispatch.requesToRespondDB()
    local res
    _CS(function ()
        res = _DB:query("select id, regionName, serverName, userId, body from rocketmqRouter_request where id > " .. requesToRespondDBId .." order by id ASC  limit 1")
        if res.errno then
            log.printTable(log.fatalLevel(), {{res, "requesToRespondDB error res"}})
        end
    end)
    if res and #res > 0 then
        for _, _data in ipairs(res) do
            log.printTable(log.fatalLevel(), {{_data, "requesToRespondDB _data"}})
            dispatch.saveToRespondDB(_data.regionName, _data.userId, _data.serverName, _data.body)
            requesToRespondDBId = _data.id
        end
    else
        skynet.sleep(10)
    end
    skynet.fork(dispatch.requesToRespondDB)
end


local loadRespondDBId = 0
function dispatch.loadRespondDB()
    local res
    _CS(function ()
        res = _DB:query("select id, regionName, serverName, userId, body from rocketmqrouter_respond where id > " .. loadRespondDBId .." order by id ASC  limit 1")
        if res.errno then
            log.printTable(log.fatalLevel(), {{res, "loadRespondDB error res"}})
        end
    end)
    if res and #res > 0 then
        for _, _data in ipairs(res) do
            log.printTable(log.fatalLevel(), {{_data, "loadRespondDB _data"}})
            loadRespondDBId = _data.id
            dispatch.request(_data.body)
        end
    else
        skynet.sleep(10)
    end
    skynet.fork(dispatch.loadRespondDB)
end


function dispatch.sendRequestPack(sourceUid, sessionStr, serverName, pack)
    local head = {
        ver = 1,
        session = sessionStr,
        server = "router_service",
        command = "request",
        type = "request",
        sourceUid = sourceUid,
        error = 0,
    }

    local headMsg = protobuf.encode("base.Head", head)
    local headPack = string.pack_package(headMsg)
    local dataPack = string.pack_package(headPack .. pack)
    dispatch.addPack(sessionStr, dataPack)
    dispatch.writeSocket(dataPack)
    skynet.fork(dispatch.getRequestPack, dataPack)
end

function dispatch.recvRespondPack(sessionStr)
    local pack = dispatch.readSocket(sessionStr)
    local headMsg, headSize, _ = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if not head then
        log.error("parse head nil")
        return
    end
    dispatch.delPack(head.session)
end

function dispatch.getRequestPack(pack)
    local head = {
        ver = 1,
        session = sessionStr,
        server = "router_service",
        command = "request",
        type = "request",
        sourceUid = sourceUid,
        error = 0,
    }

    local headMsg = protobuf.encode("base.Head", head)
    local headPack = string.pack_package(headMsg)
    local dataPack = string.pack_package(headPack .. pack)
end


function dispatch.parsePack(pack)
    local headMsg, headSize, bodyPack = string.unpack_package(pack)
    local head = protobuf.decode("base.Head", headMsg)
    if not head then
        log.error("parse head nil")
        return
    end
    if head.type == "respond" then
        dispatch.respond(head)
    elseif head.type == "request" then
        dispatch.request(bodyPack)
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
        dispatch.routerCall(head, pack)
    elseif head.type == "send" then
        dispatch.routerSend(head, pack)
    elseif head.type == "ret" then
        dispatch.routerRet(head, bodyPack)
    end
end

function dispatch.routerCall(head, pack)
    local _, agent = skynet.call("server_server", "lua", "getAgent", head.sourceUid)
    local retMsg, retSz = skynet.pack(skynet.call(agent, "client", "router", "callRouter", pack))
    head.type = "ret"
    local headMsg = protobuf.encode("base.Head",head)
    local headPack = string.pack_package(headMsg)
    local bodyStr = skynet.tostring(retMsg, retSz)
    skynet.trash(retMsg, retSz)
    local bodyPack = string.pack_package(bodyStr)
    local pack = string.pack_package(headPack..bodyPack)
    log.trace("pack = ", pack)
    dispatch.saveToRequestDB("TopicTest", head.destUid, head.server, pack)
    --dispatch.writeSocket(pack)
end

function dispatch.routerSend(head, pack)
    local _, agent = skynet.call("server_server", "lua", "getAgent", head.sourceUid)
    skynet.call(agent, "client", "router", "callRouter", pack)
end

function dispatch.routerRet(head, bodyPack)
    local bodyMsg, bodySz, _ = string.unpack_package(bodyPack)
    local spritArr = string.split(head.session, "_")
    local handle = spritArr[1]
    local session = spritArr[2]
    skynet.resume(handle, session, skynet.unpack(bodyMsg, bodySz))
end

dispatch.start(function ()
    local function on_connect(db)
        db:query("set charset utf8");
    end
    local db=mysql.connect({
        host="192.168.123.213",
        port=3306,
        database="skynet_sy",
        user="yfy",
        password="yfysina@389",
        max_packet_size = 1024 * 1024,
        on_connect = on_connect
    })
    if not db then
        print("failed to connect")
    end
    _DB = db
    print("testmysql success to connect to mysql server")
    skynet.fork(stats)
    skynet.fork(dispatch.requesToRespondDB)
    skynet.fork(dispatch.loadRespondDB)
end)