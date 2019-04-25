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
local dispatchParseRouter
local dispatchClientCS
local dispatchServerCS
local dispatchRouteCS
local dispatchClientCSUid = {}
local dispatchServerCSUid = {}
local dispatchRouterCSUid = {}

local dispatch = {}

function dispatch.close(key)
	--dispatchPlayer[key] = nil
	--dispatchClientCSUid[key] = nil
	--dispatchServerCSUid[key] = nil
end

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

function dispatch.actionParseRouter()
	dispatchParseRouter = true
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

function dispatch.actionRouterCS()
	dispatchRouteCS = queue()
end

function dispatch.newClass(key)
	local player = dispatchPlayer[key]
	if not player then
		player = require(dispatchClassName).new()
		player:setDispatch(dispatch)
		player:setKey(key)
		dispatchPlayer[key] = player

		if dispatchClientCS then
			dispatchClientCSUid[key] = queue()
		end
		if dispatchServerCS then
			dispatchServerCSUid[key] = queue()
		end

		if dispatchRouteCS then
			dispatchRouterCSUid[key] = queue()
		end
	end
	return player
end

function dispatch.parseHead(pack)
	local headMsg, headSize, bodyPack = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	return head
end

function dispatch.parsePack(pack, dispatchConfig)
	local headMsg, headSize, bodyPack = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	return head
end

function  dispatch.client(session, source, command, head, pack, ...)
	if dispatchClientCS then
		return dispatchClientCS(dispatch[command], session, source, head, pack, ...)
	else
		return dispatch[command](session, source, head, pack, ...)
	end
end

function  dispatch.clientClass(session, source, command, head, pack, ...)
	local player = dispatch.newClass(head.sourceUid)
	local token = session .. source
	--log.fatal("addToken player, token, session, source, head, head.sourceUid", player, token, session, source, head, head.sourceUid)
	player:addToken(token, session, source, head)
	local error, data
	local cs = dispatchClientCSUid[head.sourceUid]
	if cs then
		error, data = cs(player[command], player, token, pack, ...)
	else
		error, data = player[command](player, token, pack, ...)
	end
	--log.fatal("clearToken player, token, session, source, head, head.sourceUid", player, token, session, source, head, head.sourceUid)
	player:clearToken(token, session, source, head)
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


function  dispatch.getRouterData(pack, ...)
	if dispatchParseRouter then
		local bodyPack, bodySize = string.unpack_package(pack)
		return skynet.unpack(bodyPack, bodySize), ...
	else
		return pack, ...
	end
end

function  dispatch.router(session, source, command, head, pack, ...)
	if dispatchRouteCS then
		return dispatchRouteCS(dispatch[command], session, source, head, dispatch.getRouterData(pack, ...))
	else
		return dispatch[command](session, source, head, dispatch.getRouterData(pack, ...))
	end
end

function  dispatch.routerClass(session, source, command, head, pack, ...)
	local player = dispatch.newClass(head.sourceUid)
	local token = session .. source
	--log.fatal("addToken player, token, session, source, head, head.sourceUid", player, token, session, source, head, head.sourceUid)
	player:addToken(token, session, source, head)
	local cs = dispatchRouterCSUid[head.sourceUid]
	local ret
	if cs then
		ret = {cs(player[command], player, token, dispatch.getRouterData(pack, ...))}
	else
		ret = {player[command](player, token, dispatch.getRouterData(pack, ...))}
	end
	--log.fatal("clearToken player, token, session, source, head, head.sourceUid", player, token, session, source, head, head.sourceUid)
	player:clearToken(token, session, source, head)
	return table.unpack(ret)
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
		funcName = "dispatch.client"
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
		funcName = "dispatch.client"
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

function  dispatch.toRouter(session, source, command, pack, ...)
	log.all("session, source, command, pack, ...", session, source, command, pack, log.getArgvData(...))
	local headMsg, headSize, bodyPack = string.unpack_package(pack)
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
		funcName = "dispatch.routerClass"
	else
		func = dispatch.client
		funcName = "dispatch.router"
	end
	if dispatchParseRouter then
		return xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, head, bodyPack, ...))
	else
		return xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, head, pack, ...))
	end
end


function  dispatch.toClient_xpcall(session, source, type, command, ...)
	--log.fatal("toClient_xpcall session, source", session, source)
	local func
	local funcName
	if type == "client" then
		if dispatchConfig then
			func = dispatch.toClientBody
			funcName = "dispatch.toClientBody"
		else
			func = dispatch.toClient
			funcName = "dispatch.toClient"
		end
	elseif type == "router" then
		func = dispatch.toRouter
		funcName = "dispatch.toRouter"
	end

	if session > 0 then
		skynet.ret(skynet.pack(xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, ...))))
	else
		xpcall_ret(funcName, session, source, command, xpcall(func, function() print(debug.traceback()) end, session, source, command, ...))
	end
end

function  dispatch.toServer_xpcall(session, source, command, ...)
	if session > 0 then
		skynet.ret(skynet.pack(xpcall_ret("dispatch.toServer", session, source, command, xpcall(dispatch.toServer, function() print(debug.traceback()) end, session, source, command, ...))))
	else
		xpcall_ret("dispatch.toServer", session, source, command, xpcall(dispatch.toServer, function() print(debug.traceback()) end, session, source, command, ...))
	end
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