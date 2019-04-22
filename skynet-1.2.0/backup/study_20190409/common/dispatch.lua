local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
require "common/system_error"

local dispatch = {}
local client = {}
local server = {}
dispatch.client = client
dispatch.server = server

local typeNames = {
	client = client,
	server = server,
}

local serverConfig = {}

local cs

local function xpcall_ret(typeName, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, command", typeName, command)
		error = systemError.invalid
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, command", typeName, command)
		error = systemError.invalidRet
	end
	return error, ...
end

local function callFunc(typeName, source, command, ...)
	local server =  typeNames[typeName]
	local func = server[command]
	if not cs then
		return xpcall_ret(typeName, command, xpcall(func, function() print(debug.traceback()) end, source, ...))
	else
		return cs(func, source, ...)
	end
end


local function callClient(source, head, pack)
	local serverConfig = serverConfig[head.server]
	if not serverConfig then
		log.error("not serverConfig")
		return systemError.invalidServer
	end

	local cmdConfig = serverConfig[head.command]
	if not cmdConfig then
		log.error("not cmdConfig")
		return systemError.invalidCommand
	end
	local requestMsg, requestSize
	requestMsg, requestSize, pack = string.unpack_package(pack)
	local request = protobuf.decode(cmdConfig.request, requestMsg)
	log.printTable(log.fatalLevel(), {{request, "request"}})
	local ret, respond = callFunc("client", source, head.command, request)
	local respondPack
	if respond then
		local respondMsg = protobuf.encode(cmdConfig.respond, respond)
		respondPack = string.pack_package(respondMsg)
	end

	return ret, respondPack
end


function  dispatch.actionCs()
	cs = queue()
end


function  dispatch.toClient(session, source, command, pack)
	log.fatal("source, pack", source, pack)
	local headMsg, headSize
	headMsg, headSize, pack = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		skynet.ret(skynet.pack(systemError.invalid))
		return
	end
	head.error = systemError.success
	log.printTable(log.fatalLevel(), {{head, "head"}})
	local ok, ret, respondPack = xpcall(callClient, function() print(debug.traceback()) end, source, head, pack)
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

function  dispatch.toServer(session, source, command, ...)
	skynet.ret(skynet.pack(callFunc("server", source, command, ...)))
end


function  dispatch.start(configPathArr, func)
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		pack = skynet.pack,
		unpack = skynet.unpack,
		dispatch = dispatch.toClient,
	}

	skynet.start(function()
		skynet.dispatch("lua", function(session, source, command, ...)
			dispatch.toServer(session, source, command, ...)
		end)
		if configPathArr then
			for _, v in pairs(configPathArr) do
				local config = require(v)
				if serverConfig[config.server] then
					log.error("exist config.server", config.server)
				else
					serverConfig[config.server] = config
				end
			end
		end

		if func then
			func()
		end
	end)
end

return dispatch