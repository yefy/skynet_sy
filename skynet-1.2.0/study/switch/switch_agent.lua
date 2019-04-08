local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")

local CMD = {}
local client_fd = -1
local serverAgent
local uid

local function package(msg)
	local package = string.pack(">s2", msg)
	return package
end

local function send_package(package)
	socket.write(client_fd, package)
end

function CMD.client(fd, pack, packSize)
	assert(fd == client_fd)
	pack = skynet.tostring(pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	log.printTable(log.fatalLevel(), {{head, "head"}})
	if uid and uid ~= head.sourceUid then
		log.error("uid, rHeadData.sourceUid",uid ~= head.sourceUid)
		return
	end
	uid = uid or head.sourceUid
	if not serverAgent then
		_, serverAgent = skynet.call("server_server", "lua", "getAgent", uid)
	end

	log.fatal("source, desc, uid, rHeadData.server, rHeadData.command", skynet.self(), serverAgent, uid, head.server, head.command)
	pack, packSize = skynet.call(serverAgent, "client", pack)
	local error, pack = skynet.unpack(pack, packSize)
	print("error, pack", error, pack)
	send_package(pack)
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
