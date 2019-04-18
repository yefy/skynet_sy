local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local dispatch = require "common/dispatch"
local socket = require "skynet.socket"
local client = dispatch.client
local server = dispatch.server
local agentMap = {}
local fds = {}
local maxPackageSize = 9 * 1024
local maxCacheSize = 64 *1024 * 1024
local _statsNumber = 0
local _sumRecvdPackage = 0
local _seconNumber = 0

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end

local function stats()
	skynet.sleep(100)
	_seconNumber = _seconNumber + 1
	log.fatal("_seconNumber, _sumRecvdPackage, statsNumber, avg",_seconNumber, _sumRecvdPackage, _statsNumber, math.floor(_sumRecvdPackage / _seconNumber))
	_statsNumber = 0
	for _, _data in pairs(fds) do
		log.fatal("_seconNumber, _data.fd, _data.sumRecv, _data.recv, avg", _seconNumber, _data.fd, _data.sumRecv, _data.recv, math.floor(_data.sumRecv / _seconNumber))
		_data.recv = 0
	end
	skynet.fork(stats)
end


local function getPackageSize(fd)
	local pack = socket.read(fd, 2)
	if not pack then
		return nil
	end
	return pack:byte(1) * 256 + pack:byte(2)
end

local function recv_package(fd)
	local size = getPackageSize(fd)
	if not size then
		return -1
	end
	if size > maxPackageSize then
		return -2, nil, size
	end
	local pack = socket.read(fd, size)
	if not pack then
		return -1
	end
	return 0, pack, size
end


local function send_package(fd, package)
	socket.write(fd, package)
end



local function close(fd)
	local agent = agentMap[fd]
	if agent then
		log.fatal("close fd", fd)
		skynet.send(agent,"lua", "exit")
	end
end


local function invalidPackage(fd, size)
	log.error("invalidPackage fd, size", fd, size)
	close(fd)
end

local function invalidCache(fd, size)
	log.error("fd, size", fd, size)
	close(fd)
end

local function warning(fd, size)
	if size > maxCacheSize then
		invalidCache(fd, size)
	end
end

local function data(fd, pack, packSize)
	local agent = agentMap[fd]
	if agent then
		local data = fds[fd]
		data.recv = data.recv + 1
		data.sumRecv = data.sumRecv + 1
		_statsNumber = _statsNumber + 1
		_sumRecvdPackage = _sumRecvdPackage + 1
		log.trace("data fd, pack, packSize", fd, pack, packSize)
		if commonConfig.switchBenchmark == "switch_listen_ping" then
			local headMsg, headSize, _ = string.unpack_package(pack)
			local head = protobuf.decode("base.Head", headMsg)
			head.error = 0
			local headMsg = protobuf.encode("base.Head",head)
			local headPack = string.pack_package(headMsg)
			local pack = string.pack_package(headPack)
			send_package(fd, pack)
			log.trace("switch_listen_ping")
			return
		end
		skynet.call(agent,"lua", "data", pack, packSize)
	end
end

local function open(fd)
	log.fatal("open fd", fd)
	fds[fd] = {fd = fd, recv = 0, sumRecv = 0}
	local agent = skynet.newservice("switch_fd_agent")
	agentMap[fd] = agent
	skynet.call(agent,"lua", "open", fd)
	socket.start(fd)
	socket.warning(fd, warning)
end

local function accept(fd)
	open(fd)
	while true do
		local ret, pack, size = recv_package(fd)
		if ret == -1 then
			close(fd)
			break
		elseif ret == -2 then
			invalidPackage(fd, size)
			break
		end
		data(fd, pack, size)
		skynet.yield()
	end
end

function server.exit(source, fd)
	local agent = agentMap[fd]
	if agent then
		log.fatal("close fd", fd)
		agentMap[fd] = nil
		fds[fd] = nil
		socket.close(fd)
	end

	return 0
end

dispatch.start(nil, function ()
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		if commonConfig.switchBenchmark == "switch_listen_ping" or commonConfig.switchBenchmark == "switch_listen_package" then
			skynet.fork(accept, fd)
		else
			local agent = skynet.newservice("switch_fd_agent")
			socket.abandon(fd) ---清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
			skynet.call(agent,"lua", "connect", fd)
		end
	end)
	if commonConfig.switchStats then
		skynet.fork(stats)
	end
end)