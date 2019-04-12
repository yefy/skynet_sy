local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local dispatch = require "common/dispatch"
local socket = require "skynet.socket"
local client = dispatch.client
local server = dispatch.server
local agentMap = {}
local _statsNumber = 0
local _sumRecvdPackage = 0
local fds = {}

--https://blog.csdn.net/selfi_xiaowen/article/details/70596565
local function stats()
	skynet.sleep(100)
	_sumRecvdPackage = _sumRecvdPackage + _statsNumber
	print("_sumRecvdPackage, statsNumber = ", _sumRecvdPackage, _statsNumber)
	_statsNumber = 0
	for _, _data in pairs(fds) do
		print("_data.fd, _data.recv = ", _data.fd, _data.sumRecv, _data.recv)
		_data.recv = 0
	end
	skynet.fork(stats)
end

local function open(fd)
	log.fatal("open fd", fd)
	local agent = skynet.newservice("switch_fd_agent")
	agentMap[fd] = {
		agent = agent,
		close = false,
	}
	skynet.call(agent,"lua", "open", fd)
	socket.start(fd)
end

local function send_package(fd, package)
	socket.write(fd, package)
end

local function data(fd, pack, packSize)
	local data = fds[fd]
	data.recv = data.recv + 1
	data.sumRecv = data.sumRecv + 1
	_statsNumber = _statsNumber + 1
	log.fatal("data fd, pack, packSize", fd, pack, packSize)
	local agent = agentMap[fd].agent
	skynet.call(agent,"lua", "data", pack, packSize)

	--[[
	log.fatal("data fd, pack, packSize", fd, pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	head.error = 0
	local headMsg = protobuf.encode("base.Head",head)
	local headPack = string.pack_package(headMsg)
	pack = string.pack_package(headPack)
	send_package(fd, pack)
	]]

end

local function close(fd)
	log.fatal("close fd", fd)
	local agent = agentMap[fd].agent
	skynet.call(agent,"lua", "close")
	agentMap[fd] = nil
	local data = fds[fd]
	_sumRecvdPackage = _sumRecvdPackage - data.sumRecv
	fds[fd] = nil
	socket.close(fd)
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
		if agentMap[fd].close then
			close(fd)
			break
		end

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

local function accept(fd)
	fds[fd] = {fd = fd, recv = 0, sumRecv = 0}
	open(fd)
	recv_package(fd)
end


function server.close(source, fd)
	log.fatal("close source, fd", source, fd)
	if agentMap[fd] then
		if agentMap[fd].agent == source then
			log.fatal("close agentMap[fd].agent", agentMap[fd].agent)
			agentMap[fd].close = true
		end
	end
	return 0
end

dispatch.start(nil, function ()
	local remore = true
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		if not remore then
			skynet.fork(accept, fd)
		else
			local agent = skynet.newservice("switch_fd_agent")
			socket.abandon(fd) ---清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
			skynet.call(agent,"lua", "connect", fd)
		end
	end)
	if not remore then
		skynet.fork(stats)
	end
end)
