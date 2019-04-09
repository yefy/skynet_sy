local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

function  client.message(source, data)
	local rMessageRequest = data
	log.printTable(log.fatalLevel(), {{rMessageRequest, "rMessageRequest"}})
	log.fatal("start chatTest")
	skynet.sleep(100)
	local _,str = skynet.call(source, "lua", "chat_server", "chatTest")
	log.fatal("end chatTest str", str)
	return 0, rMessageRequest
end


function  server.messageTest(source, data)
	log.fatal("messageTest")
	return 0, "messageTest"
end

dispatch.start({"cmd/message_agent_cmd"})