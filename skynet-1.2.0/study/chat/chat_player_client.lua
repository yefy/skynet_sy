local skynet = require "skynet"
local log = require "common/log"
local client = require ("common/dispatch_client").new()

function  client.chat(source, data)
	local rChatRequest = data.request
	log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
	log.fatal("start messageTest")
	skynet.sleep(100)
	local _, str = skynet.call(source, "lua", "server", "message_server", "messageTest")
	log.fatal("end messageTest str", str)
	return 0, rChatRequest
end