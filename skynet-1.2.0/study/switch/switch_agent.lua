local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")

local CMD = {}
local client_fd = -1
local playerAgent
local uid

local function package(msg)
	local package = string.pack(">s2", msg)
	return package
end

local function send_package(package)
	socket.write(client_fd, package)
end

function CMD.client(fd, msg, sz)
	assert(fd == client_fd)
	local rMessage = skynet.tostring(msg, sz)
	local rHeadMessage, rHeadSize, _ = string.unpack_package(rMessage)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
	if uid and uid ~= rHeadData.sourceUid then
		log.error("uid, rHeadData.sourceUid",uid ~= rHeadData.sourceUid)
		return
	end
	uid = uid or rHeadData.sourceUid
	if not playerAgent then
		_, playerAgent = skynet.call("player_server", "lua", "getAgent", uid)
	end

	log.fatal("source, desc, uid, rHeadData.server, rHeadData.command", skynet.self(), playerAgent, uid, rHeadData.server, rHeadData.command)
	local package, sz = skynet.call(playerAgent, "client", "client", rMessage)
	local error, pa = skynet.unpack(package, sz)
	print("error, pa", error, pa)
	send_package(pa)
end

function CMD.server(conf)

end

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	local watchdog = conf.watchdog
	client_fd = fd
	skynet.call(gate, "lua", "forward", client_fd)
end

function CMD.disconnect()
	log.fatal("disconnect : client_fd", client_fd)
	skynet.exit()
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
	pack = skynet.pack,
	unpack = function (...)
		return ...
	end,
	dispatch = function (fd, _, msg, sz)
		CMD.client(fd, msg, sz)
	end
}

skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		local f = CMD[command]
		skynet.ret(skynet.pack(f(...)))
	end)
end)
