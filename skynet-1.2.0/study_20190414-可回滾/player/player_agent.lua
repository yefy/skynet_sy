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

function  client.login(source, data)
	statsNumber = statsNumber + 1
	local rLoginRequest = data
	log.trace("login")
	log.printTable(log.allLevel(), {{rLoginRequest, "rLoginRequest"}})
	--skynet.call(source, "lua", "router_server", "router", "login")
	return 0, rLoginRequest
end

dispatch.start({"cmd/player_agent_cmd"}, function ()
	skynet.fork(stats)
end)