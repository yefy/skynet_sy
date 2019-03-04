
local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require "skynet.manager"	-- import skynet.register

local function harbor_test()
	skynet.send("switch_harbor", "lua", "chat_server_harbor", "chat_server_harbor")
	skynet.sleep(100)
	skynet.fork(harbor_test)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		log.print(log.fatalLevel(), command, log.getArgvData(...))
		skynet.ret(skynet.pack(""))

	end)
	skynet.register "chat_harbor"
	skynet.fork(harbor_test)
end)


--[[
local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"

local CMD = {}

function  CMD.login(data)
	local rLoginData = data["base.Login"]
	log.printTable(log.fatalLevel(), {{rLoginData, "rLoginData"}})
	return
end

function  CMD.chat(data)
	local rChatData = data["base.Chat"]
	log.printTable(log.fatalLevel(), {{rChatData, "rChatData"}})
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, msg)
		local rHeadMessage, rHeadSize, rMsg = string.unpack_package(msg)
		local rHeadData = protobuf.decode("base.Head", rHeadMessage)
		for _, _protoMessage in ipairs(rHeadData.protoMessages) do
			local rMessage, rMessageSize, rMsg = string.unpack_package(rMsg)
			local rData = protobuf.decode(_protoMessage, rMessage)
			rHeadData[_protoMessage] = rData
		end
		log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
		local f = CMD[rHeadData.command]
		skynet.ret(skynet.pack(f(rHeadData)))

	end)
	skynet.register "chat_server1"
end)
]]