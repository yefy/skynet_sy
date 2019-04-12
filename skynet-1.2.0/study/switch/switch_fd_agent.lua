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

local function send_package(fd, package)
	socket.write(fd, package)
end

local socket = require "skynet.socket"
local _statsNumber = 0
local _sumRecvdPackage = 0

--https://blog.csdn.net/selfi_xiaowen/article/details/70596565
local function stats()
	skynet.sleep(100)
	_sumRecvdPackage = _sumRecvdPackage + _statsNumber
	print("client_fd, _sumRecvdPackage, statsNumber = ", client_fd, _sumRecvdPackage, _statsNumber)
	_statsNumber = 0
	skynet.fork(stats)
end

local function data(fd, pack, packSize)
	_statsNumber = _statsNumber + 1
	log.fatal("data fd, pack, packSize", fd, pack, packSize)
	server.data(0, pack, packSize)
end

local function close(fd)
	log.fatal("close fd", fd)
	print("close fd", fd)
	socket.close(fd)
	skynet.exit()
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, 0, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, 0, text
	end

	return text:sub(3,2+s), s, text:sub(3+s)
end

local function recv_package(fd)
	local last = ""
	while true do
		while true do
			local msg, sz
			msg, sz, last = unpack_package(last)
			if msg then
				data(fd, msg, sz)
			else
				break
			end
		end

		local r = socket.read(fd)
		if not r then
			close(fd)
			break
		end
		last = last .. r
	end
end


local function open(source, fd)
	log.fatal("open fd", fd)
	print("open fd", fd)
	addr = source
	client_fd = fd
	socket.start(fd)
	--skynet.fork(recv_package, fd)
end

function  server.connect(source, fd)
	skynet.fork(stats)
	open(source, fd)
	return 0
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

	if true then
		head.error = 0
		local headMsg = protobuf.encode("base.Head",head)
		local headPack = string.pack_package(headMsg)
		pack = string.pack_package(headPack)
		send_package(client_fd, pack)
		return 0
	end

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
	log.fatal("error, pack", error, pack)
	if error ~= 0 then
		head.error = error
		local headMsg = protobuf.encode("base.Head",head)
		local headPack = string.pack_package(headMsg)
		pack = string.pack_package(headPack)
	end
	send_package(client_fd, pack)
	return 0
end

function  server.close(source)
	log.fatal("close fd", client_fd)
	return 0
end

dispatch.start(nil, function ()
end)
