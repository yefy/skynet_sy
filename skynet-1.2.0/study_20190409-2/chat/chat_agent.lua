local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

function  client.chat(source, data)
	local rChatRequest = data
	log.printTable(log.allLevel(), {{rChatRequest, "rChatRequest"}})
	log.trace("start messageTest")
	local _, str = skynet.call(source, "lua", "message_server", "messageTest")
	log.trace("end messageTest str", str)
	return 0, rChatRequest
end

function  server.chatTest(source, data)
	log.trace("chatTest")
	return 0, "chatTest"
end

dispatch.start({"cmd/chat_agent_cmd"})