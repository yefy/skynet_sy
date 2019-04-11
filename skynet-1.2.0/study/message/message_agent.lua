local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

function  client.message(source, data)
	local rMessageRequest = data
	log.fatal("message")
	log.printTable(log.allLevel(), {{rMessageRequest, "rMessageRequest"}})
	skynet.call(source, "lua", "router_server", "router", "message")
	return 0, rMessageRequest
end

dispatch.start({"cmd/message_agent_cmd"})