local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"
local Client = dispatch.Client
local Server = dispatch.Server

math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local csMap = {
	Client = {
		player_agent = queue(),
		chat_server = queue(),
		message_server = queue(),
	},
	Server = {
		player_agent = queue(),
		chat_server = queue(),
		message_server = queue(),
	},
}

local ServerConfig = {}
local ServerConfigPath = {"cmd/player_agent_cmd", "cmd/chat_agent_cmd", "cmd/message_agent_cmd"}
for _, v in pairs(ServerConfigPath) do
	local config = require(v)
	ServerConfig[config.server] = config
end

local ServerName = "player_agent"
local AgentMap = {}

function  Client.login(source, data)
	local rLoginRequest = data.request
	log.printTable(log.fatalLevel(), {{rLoginRequest, "rLoginRequest"}})
	return 0, rLoginRequest
end

function  Server.clearAgent(source, serverName)
	log.fatal("clearAgent serverName", serverName)
	AgentMap[serverName] = nil
	return 0
end


local function  callPlayer(typeName, server, command, ...)
	local func
	if typeName == "Client" then
		func = Client[command]
	else
		func = Server[command]
	end
	return func(skynet.self(),  ...)
end

local function  callServer(typeName, server, command, ...)
	log.fatal("typeName, server, command", typeName, server, command)
	if typeName == "Client" then
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
	if server == ServerName then
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

function  Client.client(source, msg)
	log.fatal("source, msg", source, msg)
	local rHeadMessage, rHeadSize, rMsg = string.unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	log.fatal("rHeadData.server, rHeadData.command", rHeadData.server, rHeadData.command)
	local serverConfig = ServerConfig[rHeadData.server]
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

	local ret, data = callFunc("Client", rHeadData.server, rHeadData.command, rHeadData)
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

function  Server.server(source, ...)
	return callFunc("Server", ...)
end

dispatch.start()