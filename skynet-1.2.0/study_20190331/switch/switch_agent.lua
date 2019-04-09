local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")

local CMD = {
	client_fd = -1,
}

local function package(msg)
	local package = string.pack(">s2", msg)
	return package
end

local function send_package(package)
	socket.write(CMD.client_fd, package)
end

function CMD.client(fd, msg, sz)
	assert(fd == CMD.client_fd)
	local rMessage = skynet.tostring(msg, sz)
	local rHeadMessage, rHeadSize, _ = string.unpack_package(rMessage)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage)
	log.printTable(log.allLevel(), {{rHeadData, "rHeadData"}})
	skynet.send(rHeadData.server, "lua", rMessage)
end

function CMD.server(conf)

end

function CMD.start(conf)
	local fd = conf.client
	local gate = conf.gate
	local watchdog = conf.watchdog
	CMD.client_fd = fd
	skynet.call(gate, "lua", "forward", CMD.client_fd)
end

function CMD.disconnect()
	log.fatal("disconnect : client_fd", CMD.client_fd)
	skynet.exit()
end


skynet.register_protocol {
	name = "client",
	id = skynet.PTYPE_CLIENT,
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
