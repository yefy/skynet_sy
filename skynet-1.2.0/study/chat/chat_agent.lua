local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
dispatch.actionServerClass("chat_player_server")

dispatch.start(function ()
end)


--[[
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

function  client.chat(source, data)
	statsNumber = statsNumber + 1
	local rChatRequest = data
	log.trace("chat")
	log.printTable(log.allLevel(), {{rChatRequest, "rChatRequest"}})
	--skynet.call(source, "lua", "router_server", "router", "chat")
	return 0, rChatRequest
end

function  server.chatTest(source, data)
	log.trace("chatTest")
	return 0, "chatTest"
end

dispatch.start({"cmd/chat_agent_cmd"}, function ()
	skynet.fork(stats)
end)
]]