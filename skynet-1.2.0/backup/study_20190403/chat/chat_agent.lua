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
	log.fatal("start helloTest")
	skynet.call(source, "lua", "helloTest")
	log.fatal("end helloTest")
	return 0, rChatRequest
end



local traceback = debug.traceback

local function xpcall_ret(ok, ...)
	return ...
end

local function callFunc(command, ...)
	local func =  CMD[command]
	if not cs then
		return xpcall_ret(xpcall(func, traceback, ...))
	else
		return cs(func, ...)
	end
end

skynet.start(function()
	skynet.dispatch("lua", function(session, source, command, data)
		log.printTable(log.fatalLevel(), {{data, "data"}})
		skynet.ret(skynet.pack(callFunc(command, data)))
	end)
end)