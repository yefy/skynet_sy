local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
local cluster = require "skynet.cluster"
local serverName = skynet.getenv "server_name"
local masterAddress = skynet.getenv "master_address"
local masterName = skynet.getenv "master_name"
local slaveAddress = skynet.getenv "slave_address"
local slaveName = skynet.getenv "slave_name"

local CMD = {}

function  CMD.init()
	local addrssTable = {}
	addrssTable[slaveName] = slaveAddress
	cluster.reload(addrssTable)
	local rSlave = skynet.self()
	cluster.register(slaveName, rSlave)
	cluster.open(slaveName)

	cluster.reload {
		switch = "127.0.0.1:2528",
	}
	local proxySwitch = cluster.proxy "switch@switchServer"	-- cluster.proxy("switch", "@switch")
	print(skynet.call(proxySwitch, "lua", "GET", "a"))
	print(skynet.call(proxySwitch, "lua", "GET", "b"))
end

function  CMD.slaveRegister()
	local rSlaveRegister = data["base.SlaveRegister"]
	log.printTable(log.fatalLevel(), {{rSlaveRegister, "rSlaveRegister"}})
end


function  CMD.onSlaveRegister(data)
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