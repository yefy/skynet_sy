local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

function  client.chat(source, data)
	local rChatRequest = data.request
	log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
	log.fatal("start messageTest")
	skynet.sleep(100)
	local _, str = skynet.call(source, "lua", "message_server", "messageTest")
	log.fatal("end messageTest str", str)
	return 0, rChatRequest
end

function  server.chatTest(source, data)
	log.fatal("chatTest")
	return 0, "chatTest"
end

dispatch.start({"cmd/chat_agent_cmd"})