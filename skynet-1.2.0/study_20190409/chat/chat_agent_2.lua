local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local cs

local CMD = {}

function  CMD.chat(source, data)
	local rChatRequest = data.request
	log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
	--log.fatal("start messageTest")
	--skynet.sleep(100)
	--local str = skynet.call(source, "lua", "message_server", "messageTest")
	--log.fatal("end messageTest str", str)
	return 0, rChatRequest
end

function  CMD.chatTest(source, data)
	log.fatal("chatTest")
	return "chatTest"
end


local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(command, source, ...)
	log.fatal("command", command)
	local func =  CMD[command]
	if not cs then
		return xpcall_ret(xpcall(func, function() print(debug.traceback()) end, source, ...))
	else
		return cs(func, source, ...)
	end
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	pack = skynet.pack,
	unpack = skynet.unpack,
	dispatch = function (session, source, command, ...)
		--log.printTable(log.fatalLevel(), {{data, "data"}})
		skynet.ret(skynet.pack(callFunc(command, source, ...)))
	end
}

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, ...)
		--log.printTable(log.fatalLevel(), {{data, "data"}})
		skynet.ret(skynet.pack(callFunc(command, source, ...)))
	end)
end)