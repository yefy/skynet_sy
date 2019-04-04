local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local Client = dispatch.Client
local Server = dispatch.Server

function  Client.chat(source, data)
	local rChatRequest = data.request
	log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
	--log.fatal("start messageTest")
	--skynet.sleep(100)
	--local str = skynet.call(source, "lua", "message_server", "messageTest")
	--log.fatal("end messageTest str", str)
	return 0, rChatRequest
end

function  Server.chatTest(source, data)
	log.fatal("chatTest")
	return 0, "chatTest"
end

dispatch.start()