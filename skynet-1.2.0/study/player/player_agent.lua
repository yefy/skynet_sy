local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

function  client.login(source, data)
	local rLoginRequest = data
	log.fatal("login")
	log.printTable(log.allLevel(), {{rLoginRequest, "rLoginRequest"}})
	return 0, rLoginRequest
end

dispatch.start({"cmd/player_agent_cmd"})