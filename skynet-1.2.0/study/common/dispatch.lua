local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
require "common/system_error"

local dispatchClassName   --需要生成类
local dispatchPlayer = {}

local dispatchConfig  		--需要解析body
local dispatchClientCS
local dispatchServerCS
local dispatchClientCSUid = {}
local dispatchServerCSUid = {}

local dispatch = {}

function dispatch.actionConfig(configArr)
	dispatchConfig = {}
	for _, v in pairs(configArr) do
		local config = require(v)
		if dispatchConfig[config.server] then
			log.error("exist config.server", config.server)
		else
			dispatchConfig[config.server] = config
		end
	end
end

function dispatch.actionClass(className)
	dispatchClassName = className
end

function dispatch.actionClientCS()
	dispatchClientCS = queue()
end

function dispatch.actionServerCS()
	dispatchServerCS = queue()
end

function dispatch.newClass(key)
	local player = dispatchPlayer[key]
	if not player then
		player = require(dispatchClassName).new()
		player:setKey(key)
		dispatchPlayer[key] = player

		if dispatchClientCS then
			dispatchClientCSUid[key] = queue()
		end
		if dispatchServerCS then
			dispatchServerCSUid[key] = queue()
		end
	end
	return player
end










--[[

function dispatch.client(session, source, command, head, ...)
	return dispatch[command](session,source, head, ...)
end

function dispatch.server(session, source, command, ...)
	return dispatch[command](...)
end

function dispatch.clientClass(session, source, command, head, ...)
	local uid = head.sourceUid
	local player = dispatch.newClass(uid)
	if not player then
		log.error("not player uid", uid)
		return systemError.invalidCommand
	end
	player:addSession(session, source, head)
	local error, data = player[command](player, session, ...)
	player:clearSession(session)
	return error, data
end

function dispatch.serverClass(session, source, command, uid, ...)
	if not dispatchClassName then
		return dispatch[command](uid, ...)
	end

	if uid == 0 then
		return dispatch[command]( ...)
	end

	local player = dispatch.newClass(uid)
	return player[command](player, ...)
end

local function callFunc(typeName, session, source, command, ...)
	if not dispatchClassName then
		local func
		if typeName == "client" then
			func = dispatch.client
		elseif typeName == "server" then
			func = dispatch.server
		end

		local cs = dispatchCS[typeName]

		if not cs then
			return xpcall_ret(typeName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, ...))
		else
			return cs(func, session, source, command, ...)
		end
	end
end

local function callClient(session, source, head, pack)
	local serverConfig = dispatchConfig[head.server]
	if not serverConfig then
		log.error("not serverConfig head.server", head.server)
		return systemError.invalidServer
	end

	local cmdConfig = serverConfig[head.command]
	if not cmdConfig then
		log.error("not cmdConfig head.command", head.command)
		return systemError.invalidCommand
	end
	local requestMsg, requestSize
	requestMsg, requestSize, pack = string.unpack_package(pack)
	local request = protobuf.decode(cmdConfig.request, requestMsg)
	log.printTable(log.allLevel(), {{request, "request"}})
	local ret, respond = callFunc("client", session, source, head.command, head, request)
	local respondPack
	if respond then
		local respondMsg = protobuf.encode(cmdConfig.respond, respond)
		respondPack = string.pack_package(respondMsg)
	end
	return ret, respondPack
end

]]


function  dispatch.client(session, source, command, head, pack, ...)
	if dispatchClientCS then
		return dispatchClientCS(dispatch[command], session, source, head, pack, ...)
	else
		return dispatch[command](session, source, head, pack, ...)
	end
end

function  dispatch.clientClass(session, source, command, head, pack, ...)
	local player = dispatch.newClass(head.sourceUid)
	player:addSession(session, source, head)
	local error, data
	local cs = dispatchClientCSUid[head.sourceUid]
	if cs then
		error, data = cs(player[command], player, session, pack, ...)
	else
		error, data = player[command](player, session, pack, ...)
	end
	player:clearSession(session)
	return error, data
end

function  dispatch.server(session, source, command, ...)
	if dispatchServerCS then
		return dispatchServerCS(dispatch[command], ...)
	else
		return dispatch[command](...)
	end
end

function  dispatch.serverClass(session, source, command, key, ...)
	if key == 0 then
		return dispatch.server(session, source, command, ...)
	end

	local player = dispatch.newClass(key)
	local cs = dispatchServerCSUid[key]
	if cs then
		return cs(player[command], player, ...)
	else
		return player[command](player, ...)
	end
end

local function xpcall_ret(funcName, session, source, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : funcName, session, source, command", funcName, session, source, command)
		error = systemError.invalid
	end

	if not error then
		log.error("xpcall_ret nil error : funcName, session, source, command", funcName, session, source, command)
		error = systemError.invalidRet
	end
	return error, ...
end

function  dispatch.toClient(session, source, command, pack, ...)
	log.all("session, source, command, pack, ...", session, source, command, pack, log.getArgvData(...))
	local headMsg, headSize, packBody = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return systemError.invalid
	end
	head.error = systemError.success
	log.printTable(log.allLevel(), {{head, "head"}})
	local func
	local funcName
	if dispatchClassName then
		func = dispatch.clientClass
		funcName = "dispatch.clientClass"
	else
		func = dispatch.client
		funcName = "dispatch.clientClass"
	end
	return xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, head, pack, ...))
end

function  dispatch.toClientBody(session, source, command, pack, ...)
	log.all("session, source, command, pack, ...", session, source, command, pack, log.getArgvData(...))
	local headMsg, headSize, packBody = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return systemError.invalid
	end
	head.error = systemError.success
	log.printTable(log.allLevel(), {{head, "head"}})

	local serverConfig = dispatchConfig[head.server]
	if not serverConfig then
		log.error("not serverConfig head.server", head.server)
		return systemError.invalidServer
	end

	local cmdConfig = serverConfig[head.command]
	if not cmdConfig then
		log.error("not cmdConfig head.command", head.command)
		return systemError.invalidCommand
	end

	local requestMsg, requestSize
	requestMsg, requestSize, _ = string.unpack_package(packBody)
	local request = protobuf.decode(cmdConfig.request, requestMsg)
	log.printTable(log.allLevel(), {{request, "request"}})

	local func
	local funcName
	if dispatchClassName then
		func = dispatch.clientClass
		funcName = "dispatch.clientClass"
	else
		func = dispatch.client
		funcName = "dispatch.clientClass"
	end
	local respond
	head.error, respond = xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, head, request, ...))

	local respondPack
	if respond then
		local respondMsg = protobuf.encode(cmdConfig.respond, respond)
		respondPack = string.pack_package(respondMsg)
	end

	headMsg = protobuf.encode("base.Head",head)
	local headPack = string.pack_package(headMsg)
	local dataMsg
	if respondPack then
		dataMsg = headPack .. respondPack
	else
		dataMsg = headPack
	end
	local dataPack = string.pack_package(dataMsg)
	return systemError.success, dataPack
end

function  dispatch.toServer(session, source, command, ...)
	log.all("session, source, command, ...", session, source, command, log.getArgvData(...))
	local func
	local funcName
	if dispatchClassName then
		func = dispatch.serverClass
		funcName = "dispatch.serverClass"
	else
		func = dispatch.server
		funcName = "dispatch.server"
	end
	return func(session, source, command, ...)
end


function  dispatch.toClient_xpcall(session, source, command, ...)
	local func
	local funcName
	if dispatchConfig then
		func = dispatch.toClientBody
		funcName = "dispatch.toClientBody"
	else
		func = dispatch.toClient
		funcName = "dispatch.toClient"
	end
	skynet.ret(skynet.pack(xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, ...))))
end

function  dispatch.toServer_xpcall(session, source, command, ...)
	skynet.ret(skynet.pack(xpcall_ret("dispatch.toServer", session, source, command, xpcall(dispatch.toServer, function() print(debug.traceback()) end, session, source, command, ...))))
end

function  dispatch.start(func)
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		pack = skynet.pack,
		unpack = skynet.unpack,
		dispatch = dispatch.toClient_xpcall,
	}

	skynet.start(function()
		skynet.dispatch("lua", function(session, source, command, ...)
			dispatch.toServer_xpcall(session, source, command, ...)
		end)
		if func then
			xpcall(func, function() print(debug.traceback()) end)
		end
	end)
end

return dispatch