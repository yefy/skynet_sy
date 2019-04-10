local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

local addr
local client_fd = -1
local serverAgent
local uid

local function send_package(package)
	socket.write(client_fd, package)
end

function  server.open(source, fd)
	log.fatal("open source, fd", source, fd)
	addr = source
	client_fd = fd
	return 0
end

function  server.data(source, pack, packSize)
	log.fatal("data fd, pack, packSize", client_fd, pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	log.fatal("head.session", head.session)
	log.printTable(log.allLevel(), {{head, "head"}})
	if uid and uid ~= head.sourceUid then
		log.error("uid, rHeadData.sourceUid",uid ~= head.sourceUid)
		return
	end
	uid = uid or head.sourceUid
	if not serverAgent then
		_, serverAgent = skynet.call("server_server", "lua", "getAgent", uid)
	end

	log.trace("source, desc, uid, rHeadData.server, rHeadData.command", skynet.self(), serverAgent, uid, head.server, head.command)
	local error, pack = skynet.call(serverAgent, "client", pack)
	print("error, pack", error, pack)
	if error ~= 0 then
		head.error = error
		local headPack = string.pack_package(head)
		pack = string.pack_package(headPack)
	end
	send_package(pack)
	return 0
end

function  server.close(source)
	log.fatal("close fd", client_fd)
	return 0
end

dispatch.start(nil, function ()
end)
