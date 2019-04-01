local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local queue = require "skynet.queue"
--local cs = queue()  -- cs 是一个执行队列
local CsServer = {
	player_agent = queue(),
	chat_server = queue(),
}

local CmdServer = {}
local CmdServerName = {"cmd/chat_agent_cmd", "cmd/player_agent_cmd"}
for _, v in pairs(CmdServerName) do
	local serverName, value = require(v)
	CmdServer[serverName] = value
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
	local rLoginData = data["base.Login"]
	log.printTable(log.fatalLevel(), {{rLoginData, "rLoginData"}})
	return 0, rLoginData
end

function  CMD.callServer(data)
	local agentArr = Agent[data.server]
	if not agentArr then
		agentArr = skynet.call(data.server, "lua", "getAgent")
		Agent[data.server] = agentArr
	end
	local rand = math.random(1, #agentArr)
	return skynet.call(agentArr[rand], "lua", data.command, data)
end

function  CMD.clearAgent(serverName)
	log.fatal("clearAgent serverName", serverName)
	Agent[serverName] = nil
end



function  CMD.client(session, source, msg)
	print("session, source, msg, sz", session, source, msg)
	local rHeadMessage, rHeadSize, rMsg = string.unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	local proto = CmdServer[rHeadData.server][rHeadData.command]
	local rMessage, rMessageSize, rMsg = string.unpack_package(rMsg)
	local rData = protobuf.decode(proto.request, rMessage)
	rHeadData["request"] = rData

	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})

	local cs = CsServer[rHeadData.server]
	local func
	if rHeadData.server == ServerName then
		func = CMD[rHeadData.command]
	else
		func = CMD["callServer"]
	end
	local ret, data
	if not cs then
		ret, data = func(rHeadData)
		skynet.ret(skynet.pack())
	else
		ret, data = cs(func, rHeadData)
		skynet.ret(skynet.pack(cs(func, rHeadData)))
	end
	rHeadData.error = 0
	local rHeadMessage = protobuf.encode("base.Head",rHeadData)
	local rHeadPackage = string.pack_package(rHeadMessage)
	local rDataPackage = ""
	if ret == 0 and data then
		local rDataMessage = protobuf.encode(proto.request, data)
		rDataPackage = string.pack_package(rDataMessage)
	end
	skynet.ret(skynet.pack(string.pack_package(rHeadPackage .. rDataPackage)))
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	unpack = skynet.unpack,
	dispatch = function (session, source, msg, sz)
		CMD.client(session, source, msg, sz)
	end
}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, ...)
		local cs = CsServer[ServerName]
		local func = CMD[command]
		if not cs then
			skynet.ret(skynet.pack(func(...)))
		else
			skynet.ret(skynet.pack(cs(func, ...)))
		end
	end)
end)