local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local queue = require "skynet.queue"

local CsServer = {
	player_agent = queue(),
	chat_server = queue(),
	message_server = queue(),
}

local ServerConfig = {}
local ServerConfigPath = {"cmd/player_agent_cmd", "cmd/chat_agent_cmd", "cmd/message_agent_cmd"}
for _, v in pairs(ServerConfigPath) do
	local config = require(v)
	ServerConfig[config.server] = config
end

local LoginAgent
local OtherAgentMap = {
}
math.randomseed(tostring(os.time()):reverse():sub(1, 6))
local ServerName = "player_agent"

local Agent = {

}

local CMD = {}

function  CMD.login(data)
	local rLoginRequest = data.request
	log.printTable(log.fatalLevel(), {{rLoginRequest, "rLoginRequest"}})
	return 0, rLoginRequest
end

function  CMD.clearAgent(serverName)
	log.fatal("clearAgent serverName", serverName)
	Agent[serverName] = nil
	return 0
end

local function  callServer(server, command, ...)
	local agentArr = Agent[server]
	if not agentArr then
		_, agentArr = skynet.call(server, "lua", "getAgent")
		Agent[server] = agentArr
	end
	local rand = math.random(1, #agentArr)
	return skynet.call(agentArr[rand], "client", command, ...)
end


local function xpcall_ret(typeName, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, command", typeName, command)
		error = -1
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, command", typeName, command)
		error = -1
	end
	return error, ...
end

local function callFunc(typeName, source, command, ...)
	log.trace("typeName, source, command, ...", typeName, source, command, log.getArgvData(...))
	local server =  TypeNames[typeName]
	local func = server[command]
	if not cs then
		return xpcall_ret(typeName, command, xpcall(func, function() print(debug.traceback()) end, source, ...))
	else
		return cs(func, source, ...)
	end
end



local traceback = debug.traceback
local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(server, command, ...)
	local cs = CsServer[server]
	local func
	if server == ServerName then
		func = CMD[command]
	else
		func = callServer
	end
	if not cs then
		return xpcall_ret(xpcall(func, function() print(debug.traceback()) end, ...))
	else
		return cs(func, server, command, ...)
	end
end


function  CMD.client(session, source, msg, ...)
	log.fatal("session, source, msg", session, source, msg)
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

	local ret, data = callFunc(rHeadData.server, rHeadData.command, rHeadData)
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
	skynet.ret(skynet.pack(pa))
end

skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	pack = skynet.pack,
	unpack = skynet.unpack,
	dispatch = function (session, source, msg)
		xpcall(CMD.client, function() print(debug.traceback()) end, session, source, msg)
	end
}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, server, command, ...)
		log.fatal("lua server, command", server, command)
		skynet.ret(skynet.pack(callFunc(server, command, ...)))
	end)
end)