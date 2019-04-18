local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

local statsNumber = 0
local function stats()
	skynet.sleep(100)
	log.fatal("id, statsNumber", skynet.self(), statsNumber)
	statsNumber= 0
	skynet.fork(stats)
end


function  client.message(source, data)
	statsNumber = statsNumber + 1
	local rMessageRequest = data
	log.trace("message")
	log.printTable(log.allLevel(), {{rMessageRequest, "rMessageRequest"}})
	--skynet.call(source, "lua", "router_server", "router", "message")
	return 0, rMessageRequest
end

dispatch.start({"cmd/message_agent_cmd"}, function ()
	skynet.fork(stats)
end)