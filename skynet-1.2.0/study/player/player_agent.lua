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
	return
end

function  CMD.callServer(data)
	local agentArr = Agent[data.server]
	if not agentArr then
		agentArr = skynet.call(data.server, "lua", "getAgent")
		Agent[data.server] = agentArr
	end
	local rand = math.random(1, #agentArr)
	log.fatal("start data.session, agentId", data.session, agentArr[rand])
	local agentId = skynet.call(agentArr[rand], "lua", data.command, data)
	log.fatal("end data.session, agentId", data.session, agentId)
end

function  CMD.clearAgent(serverName)
	log.fatal("clearAgent serverName", serverName)
	Agent[serverName] = nil
end



function  CMD.client(session, source, msg)
	print("session, source, msg, sz", session, source, msg)
	local rHeadMessage, rHeadSize, rMsg = string.unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	for _, _protoMessage in ipairs(rHeadData.protoMessages) do
		local rMessage, rMessageSize, rMsg = string.unpack_package(rMsg)
		local rData = protobuf.decode(_protoMessage, rMessage)
		rHeadData[_protoMessage] = rData
	end
	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})

	local cs = CsServer[rHeadData.server]
	local func
	if rHeadData.server == ServerName then
		func = CMD[rHeadData.command]
	else
		func = CMD["callServer"]
	end

	if not cs then
		skynet.ret(skynet.pack(func(rHeadData)))
	else
		skynet.ret(skynet.pack(cs(func, rHeadData)))
	end
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