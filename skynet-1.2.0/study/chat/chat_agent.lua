local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"

local CMD = {}

function  CMD.chat(data)
	local rChatRequest = data.request
	log.printTable(log.fatalLevel(), {{rChatRequest, "rChatRequest"}})
	return 0, rChatRequest
end

skynet.start(function()
	skynet.dispatch("lua", function(_,_, commond, data)
		log.printTable(log.fatalLevel(), {{data, "data"}})
		local f = CMD[commond]
		skynet.ret(skynet.pack(f(data)))
	end)
end)