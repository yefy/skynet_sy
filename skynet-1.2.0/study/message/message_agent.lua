local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local cs

local CMD = {}

function  CMD.message(source, data)
	local rMessageRequest = data.request
	log.printTable(log.fatalLevel(), {{rMessageRequest, "rMessageRequest"}})
	log.fatal("start chatTest")
	skynet.sleep(100)
	local str = skynet.call(source, "lua", "chat_server", "chatTest")
	log.fatal("end chatTest str", str)
	return 0, rMessageRequest
end


function  CMD.messageTest(source, data)
	log.fatal("messageTest")
	return "messageTest"
end

local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(command, source, ...)
	local func =  CMD[command]
	if not cs then
		return xpcall_ret(xpcall(func, function() print(debug.traceback()) end, source, ...))
	else
		return cs(func, source, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, data)
		log.printTable(log.fatalLevel(), {{data, "data"}})
		skynet.ret(skynet.pack(callFunc(command, source, data)))
	end)
end)