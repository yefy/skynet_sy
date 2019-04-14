local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
require "common/system_error"

local dispatchClientPlayer = {}
local dispatchServerPlayer = {}

local dispatchConfig = {}
local dispatchClass = {
	client = nil,
	server = nil,
}

local dispatchCS = {
	client = nil,
	server = nil,
}

local dispatch = {}

function dispatch.actionConfig(configArr)
	for _, v in pairs(configArr) do
		local config = require(v)
		if dispatchConfig[config.server] then
			log.error("exist config.server", config.server)
		else
			dispatchConfig[config.server] = config
		end
	end
end

function dispatch.actionClientClass(className)
	dispatchClass.client = dispatchClass.client or className
end

function dispatch.actionServerClass(className)
	dispatchClass.server = dispatchClass.server or className
end

function dispatch.actionClientCS()
	dispatchCS.client = dispatchCS.client or queue()
end

function dispatch.actionServerCS()
	dispatchCS.server = dispatchCS.server or queue()
end

function dispatch.client(session, source, command, uid, head, ...)
	local player = dispatchClientPlayer[uid]
	if not player then
		local playerClassName = dispatchClass.client
		if not playerClassName then
			log.error("not dispatchClass.client", playerClassName)
			return systemError.invalidCommand
		end
		player = require(playerClassName).new()
		player:setUid(uid)
		player:addSession(session, source, head)
		dispatchClientPlayer[uid] = player
	end
	return player[command](player, uid, session, ...)
end

function dispatch.server(session, source, command, uid, ...)
	local player = dispatchServerPlayer[uid]
	if not player then
		local playerClassName = dispatchClass.server
		if not playerClassName then
			log.error("not dispatchClass.client", playerClassName)
			return systemError.invalidCommand
		end
		player = require(playerClassName).new()
		player:setUid(uid)
		dispatchServerPlayer[uid] = player
	end
	return player[command](player, uid, ...)
end

local dispatchFunc = {
	client = dispatch.client,
	server = dispatch.server,
}



local function xpcall_ret(typeName, session, source, command, uid, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, session, source, command, uid", typeName, session, source, command, uid)
		error = systemError.invalid
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, session, source, command, uid", typeName, session, source, command, uid)
		error = systemError.invalidRet
	end
	return error, ...
end

local function callFunc(typeName, session, source, command, uid, ...)
	local func =  dispatchFunc[typeName]
	local cs = dispatchCS[typeName]
	if not cs then
		return xpcall_ret(typeName, session, source, command, uid, xpcall(func, function() print(debug.traceback()) end, session, source, command, uid, ...))
	else
		return cs(func, session, source, command, uid, ...)
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
	local ret, respond = callFunc("client", session, source, head.command, head.sourceUid, head, request)
	local respondPack
	if respond then
		local respondMsg = protobuf.encode(cmdConfig.respond, respond)
		respondPack = string.pack_package(respondMsg)
	end
	return ret, respondPack
end

function  dispatch.toClient(session, source, command, pack)
	log.all("session, source, command, pack", session, source, command, pack)
	local headMsg, headSize
	headMsg, headSize, pack = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		skynet.ret(skynet.pack(systemError.invalid))
		return
	end
	head.error = systemError.success
	log.printTable(log.allLevel(), {{head, "head"}})
	local ok, ret, respondPack = xpcall(callClient, function() print(debug.traceback()) end, session, source, head, pack)
	if not ok then
		head.error = systemError.invalid
	else
		head.error = ret
	end
	headMsg = protobuf.encode("base.Head",head)
	local headPack = string.pack_package(headMsg)
	local dataMsg
	if respondPack then
		dataMsg = headPack .. respondPack
	else
		dataMsg = headPack
	end
	skynet.ret(skynet.pack(systemError.success, string.pack_package(dataMsg)))
end

function  dispatch.toServer(session, source, command, uid, ...)
	log.all("session, source, command, uid, ...", session, source, command, uid, log.getArgvData(...))
	skynet.ret(skynet.pack(callFunc("server", session, source, command, uid, ...)))
end


function  dispatch.start(func)
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		pack = skynet.pack,
		unpack = skynet.unpack,
		dispatch = dispatch.toClient,
	}

	skynet.start(function()
		skynet.dispatch("lua", function(session, source, command, uid, ...)
			dispatch.toServer(session, source, command, uid, ...)
		end)
		if func then
			func()
		end
	end)
end

return dispatch