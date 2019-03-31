
local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
--require "common/proto_create"
--local protobuf = require "pblib/protobuf"
local log = require "common/log"
require "skynet.manager"	-- import skynet.register


local number = 1
local function resume(handle, session)
	print("resume handle, session = ", handle, session)
	skynet.sleep(10)
	skynet.resume(handle, session)
end

local function harbor_test(session)
	print("harbor_test")
	print("fork resume")
	print("skynet.self()", skynet.self())
	local handle = skynet.handle()
	--if not session then
		--session= skynet.session()
		session = skynet.genid()
	--end
	number = number + 1
	skynet.send("switch_harbor", "lua", "chat_server_harbor1", number)
	skynet.fork(resume, handle, session)
	print("suspend start handle, session = ", handle, session)
	skynet.suspend(session)
	print("suspend end handle, session = ", handle, session)
	skynet.fork(harbor_test, session)
end
local function harbor_test2()
	number = number + 1
	skynet.send("switch_harbor", "lua", "chat_server_harbor2", number)
	skynet.sleep(10)
	skynet.fork(harbor_test2)
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		log.print(log.fatalLevel(), command, log.getArgvData(...))
		skynet.ret(skynet.pack(""))

	end)
	skynet.register "chat_harbor"
	skynet.fork(harbor_test)
	skynet.fork(harbor_test2)
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