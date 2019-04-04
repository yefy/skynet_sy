local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local Client = dispatch.Client
local Server = dispatch.Server

function  Client.message(source, data)
	local rMessageRequest = data.request
	log.printTable(log.fatalLevel(), {{rMessageRequest, "rMessageRequest"}})
	--log.fatal("start chatTest")
	--skynet.sleep(100)
	--local str = skynet.call(source, "lua", "chat_server", "chatTest")
	--log.fatal("end chatTest str", str)
	return 0, rMessageRequest
end


function  Server.messageTest(source, data)
	log.fatal("messageTest")
	return 0, "messageTest"
end

dispatch.start()