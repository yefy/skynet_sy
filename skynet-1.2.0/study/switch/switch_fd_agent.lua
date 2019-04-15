local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"
local client = {}
local server = {}

local cs
local addr
local client_fd = -1
local serverAgent
local uid
local forkNumber = 1
local maxPackageSize = 9 * 1024
local maxCacheSize = 64 *1024 * 1024
local _statsNumber = 0
local _sumRecvdPackage = 0
local _seconNumber = 0

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end

forkNumber = commonConfig.switchAgentFork or 1

if forkNumber > 1 then
	cs = queue()
end

local function send_package(package)
	socket.write(client_fd, package)
end

local function stats()
	skynet.sleep(100)
	_seconNumber = _seconNumber + 1
	log.fatal("client_fd, uid, _sumRecvdPackage, statsNumber, avg = ", client_fd, uid, _sumRecvdPackage, _statsNumber, _sumRecvdPackage/_seconNumber)
	_statsNumber = 0
	skynet.fork(stats)
end

local function close()
	if client_fd ~= -1 then
		log.fatal("close client_fd", client_fd)
		socket.close(client_fd)
		client_fd = -1
		skynet.exit()
	end
end

local function invalidPackage(size)
	log.error("client_fd, size", client_fd, size)
	close()
end

local function invalidCache(size)
	log.error("client_fd, size", client_fd, size)
	close()
end

local function data(pack, packSize)
	log.trace("client_fd, pack, packSize", client_fd, pack, packSize)
	server.data(0, pack, packSize)
	_statsNumber = _statsNumber + 1
	_sumRecvdPackage = _sumRecvdPackage + 1
end

local function getPackageSize()
	local pack = socket.read(client_fd, 2)
	if not pack then
		return nil
	end
	return pack:byte(1) * 256 + pack:byte(2)
end



local function recv_package()
	if client_fd == -1 then
		return nil
	end

	local size = getPackageSize()
	if not size then
		close()
		return nil
	end
	if size > maxPackageSize then
		invalidPackage(size)
		return nil
	end
	local pack = socket.read(client_fd, size)
	if not pack then
		close()
		return nil
	end
	return pack, size
end

local function fork_recv_package()
	while true do
		if cs then
			local pack, size = cs(recv_package)
			if not pack then
				break
			end
			data(pack, size)
		else
			local pack, size = recv_package()
			if not pack then
				break
			end
			data(pack, size)
		end
	end
end

local function warning(fd, size)
	if size > maxCacheSize then
		invalidCache(size)
	end
end

local function open(fd)
	log.fatal("open fd", fd)
	client_fd = fd
	socket.start(fd)
	socket.warning(fd, warning)
	for i = 1, forkNumber do
		skynet.fork(fork_recv_package)
	end
end

function  dispatch.connect(fd)
	if commonConfig.switchAgentStats then
		skynet.fork(stats)
	end
	open(fd)
	return 0
end









function  server.open(source, fd)
	log.fatal("open source, fd", source, fd)
	addr = source
	client_fd = fd
	return 0
end

function  server.data(source, pack, packSize)
	log.trace("client_fd, pack, packSize", client_fd, pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	log.trace("head.session", head.session)
	log.printTable(log.allLevel(), {{head, "head"}})
	if uid and uid ~= head.sourceUid then
		log.error("uid, rHeadData.sourceUid",uid ~= head.sourceUid)
		return
	end
	uid = uid or head.sourceUid

	local error = -1
	if commonConfig.switchAgentBenchmark == "switch_agent_package" then
		if not serverAgent then
			_, serverAgent = skynet.call("server_server", "lua", "getAgent", uid)
		end

		log.trace("source, desc, uid, rHeadData.server, rHeadData.command", skynet.self(), serverAgent, uid, head.server, head.command)
		error, pack = skynet.call(serverAgent, "client", pack)
	end
	log.trace("error, pack", error, pack)
	if error ~= 0 then
		head.error = error
		local headMsg = protobuf.encode("base.Head",head)
		local headPack = string.pack_package(headMsg)
		pack = string.pack_package(headPack)
	end
	send_package(pack)
	return 0
end

function  server.exit(source)
	log.fatal("close fd", client_fd)
	skynet.call(source,"lua", "exit", client_fd)
	skynet.exit()
	return 0
end

dispatch.start(function ()
end)
