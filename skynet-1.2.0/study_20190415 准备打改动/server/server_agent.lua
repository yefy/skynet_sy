local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server


local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end

math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local serverName = "server_server"
local AgentMap = {}
local csMap = {
	server_server = {
		client = queue(),
		server = queue(),
	},
}

local statsNumber = 0
local function stats()
	skynet.sleep(100)
	log.fatal("id, statsNumber", skynet.self(), statsNumber)
	statsNumber = 0
	skynet.fork(stats)
end

function  server.registerMap(source, serverNameMap)
	log.fatal("registerMap source, serverNameMap", source, serverNameMap)
	for serverName, lock in pairs(serverNameMap) do
		log.fatal("registerMap serverName, lock", serverName, lock)
		csMap[serverName] = {}
		if lock == "lock" then
			csMap[serverName].client = queue()
			csMap[serverName].server = queue()
		end
	end
	return 0
end

function  server.register(source, serverName, lock)
	log.fatal("register serverName, lock", serverName, lock)
	AgentMap[serverName] = nil
	csMap[serverName] = csMap[serverName] or {}
	if lock == "lock" then
		csMap[serverName].client = csMap[serverName].client or queue()
		csMap[serverName].server = csMap[serverName].server or queue()
	else
		csMap[serverName].client = nil
		csMap[serverName].server = nil
	end
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

local function  callServer(typeName, server, command, pack)
	log.trace("typeName, server, command", typeName, server, command)
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
	return skynet.call(agentArr[rand], typeName, command, pack)
end

local function xpcall_ret(typeName, server, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, server, command", typeName, server, command)
		error = systemError.invalid
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, server, command", typeName, server, command)
		error = systemError.invalidRet
	end
	return error, ...
end

local function callFunc(typeName, server, command, ...)
	log.trace("typeName, server, command", typeName, server, command)
	if not csMap[server] then
		log.error("not csMap[server]")
		return systemError.invalidServer
	end

	local cs = csMap[server][typeName]

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

function  dispatch.toClient(session, source, pack)
	log.trace("source, pack", source, pack)
	log.trace("commonConfig.serverAgentBenchmark", commonConfig.serverAgentBenchmark)
	if commonConfig.serverAgentBenchmark == "server_agent_ping" then
		skynet.ret(skynet.pack(systemError.invalid))
		return
	end

	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if head then
		log.printTable(log.allLevel(), {{head, "head"}})
		--log.fatal("start head.session", head.session)
		skynet.ret(skynet.pack(callFunc("client", head.server, head.command, pack)))
		--log.fatal("end head.session", head.session)
	else
		log.error("parse head nil")
		skynet.ret(skynet.pack(systemError.invalid))
	end
	statsNumber = statsNumber + 1
end

function  dispatch.toServer(session, source, ...)
	skynet.ret(skynet.pack(callFunc("server", ...)))
end

dispatch.start(nil, function ()
	skynet.fork(stats)
end)