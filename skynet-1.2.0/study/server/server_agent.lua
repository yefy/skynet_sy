local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local csMap = {
	client = {
	},
	server = {
	},
}

local serverName = "server_server"
local AgentMap = {}

function  server.registerMap(source, serverNameMap)
	for serverName, _ in pairs(serverNameMap) do
		if not csMap.client[serverName] then
			csMap.client[serverName] = queue()
		end
		if not csMap.server[serverName] then
			csMap.server[serverName] = queue()
		end
	end
	return 0
end

function  server.register(source, serverName)
	log.fatal("register serverName", serverName)
	AgentMap[serverName] = nil
	local serverNameMap = {}
	serverNameMap[serverName] = true
	server.registerMap(source, serverNameMap)
	return 0
end


local function  callPlayer(typeName, serverName, command, ...)
	local func
	if typeName == "client" then
		func = client[command]
	else
		func = server[command]
	end
	return func(skynet.self(),  ...)
end

local function  callServer(typeName, server, command, ...)
	log.fatal("typeName, server, command", typeName, server, command)
	if typeName == "client" then
		typeName = "client"
	else
		typeName = "lua"
	end
	local agentArr = AgentMap[server]
	if not agentArr then
		_, agentArr = skynet.call(server, "lua", "getAgent")
		AgentMap[server] = agentArr
	end
	local rand = math.random(1, #agentArr)
	return skynet.call(agentArr[rand], typeName, command, ...)
end

local function xpcall_ret(typeName, server, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, server, command", typeName, server, command)
		error = -1
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, server, command", typeName, server, command)
		error = -1
	end
	return error, ...
end

local function callFunc(typeName, server, command, ...)
	log.fatal("typeName, server, command", typeName, server, command)
	local cs = csMap[typeName][server]
	local func
	if server == serverName then
		func = callPlayer
	else
		func = callServer
	end
	if not cs then
		return xpcall_ret(typeName, server, command, xpcall(func, function() print(debug.traceback()) end, typeName, server, command, ...))
	else
		return cs(func, typeName, server, command, ...)
	end
end

function  client.client(source, msg)
	log.fatal("source, msg", source, msg)
	local rHeadMessage, rHeadSize, rMsg = string.unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	log.fatal("rHeadData.server, rHeadData.command", rHeadData.server, rHeadData.command)
	local serverConfig = serverConfig[rHeadData.server]
	if not serverConfig then
		log.error("not serverConfig")
		rHeadData.error = -1
		local rHeadMessage = protobuf.encode("base.Head",rHeadData)
		local rHeadPackage = string.pack_package(rHeadMessage)
		local pa = string.pack_package(rHeadPackage)
		print("pa", pa)
		skynet.ret(skynet.pack(pa))
		return
	end
	local cmdConfig = serverConfig[rHeadData.command]
	if not cmdConfig then
		log.error("not cmdConfig")
		rHeadData.error = -2
		local rHeadMessage = protobuf.encode("base.Head",rHeadData)
		local rHeadPackage = string.pack_package(rHeadMessage)
		local pa = string.pack_package(rHeadPackage)
		print("pa", pa)
		skynet.ret(skynet.pack(pa))
		return
	end

	local rMessage, rMessageSize, rMsg = string.unpack_package(rMsg)
	local rData = protobuf.decode(cmdConfig.request, rMessage)
	rHeadData["request"] = rData

	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})

	local ret, data = callFunc("client", rHeadData.server, rHeadData.command, rHeadData)
	rHeadData.error = 0
	rHeadData["request"] = nil
	local rHeadMessage = protobuf.encode("base.Head",rHeadData)
	local rHeadPackage = string.pack_package(rHeadMessage)
	local rDataPackage = ""
	if ret == 0 and data then
		local rDataMessage = protobuf.encode(cmdConfig.respond, data)
		rDataPackage = string.pack_package(rDataMessage)
	end
	print("pa1111", rHeadPackage .. rDataPackage)
	local pa = string.pack_package(rHeadPackage .. rDataPackage)
	print("pa", pa)
	return 0, pa
end

function  server.server(source, ...)
	return callFunc("server", ...)
end

dispatch.start()