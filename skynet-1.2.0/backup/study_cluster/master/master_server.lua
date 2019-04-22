local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local cluster = require "skynet.cluster"
local serverName = skynet.getenv "server_name"
local masterAddress = skynet.getenv "master_address"
local masterName = skynet.getenv "master_name"

local CMD = {}

function  CMD.init()
	local addrssTable = {}
	addrssTable[masterName] = masterAddress
	cluster.reload(addrssTable)
	local rMaster = skynet.self()
	cluster.register(masterName, rMaster)
	cluster.open(masterName)
end


function  CMD.slaveRegister(data)
	local rSlaveRegister = data["base.SlaveRegister"]
	log.printTable(log.fatalLevel(), {{rSlaveRegister, "rSlaveRegister"}})
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, msg)
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
	skynet.fork(CMD.init)
end)