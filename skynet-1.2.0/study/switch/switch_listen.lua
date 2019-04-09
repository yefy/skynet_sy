local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local socket = require "socket"
local client = dispatch.client
local server = dispatch.server
local agentMap = {}

function server.close(fd)
	socket.close(fd)
end

--https://blog.csdn.net/selfi_xiaowen/article/details/70596565
local function open(fd)
	local agent = skynet.newservice("switch_fd_agent")
	agentMap[fd] = agent
	skynet.call(agent,"lua", "open", fd)
	socket.start(fd)
end

local function data(fd, pack, packSize)
	local agent = agentMap[fd]
	skynet.call(agent,"lua", "data", pack, packSize)
end

local function close(fd)
	local agent = agentMap[fd]
	skynet.call(agent,"lua", "close")
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

local function recv_package(fd, last)
	local msg, sz
	msg, sz, last = unpack_package(last)
	if msg then
		return msg, sz, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, 0, last
	end
	if r == "" then
		return ""
	end
	return unpack_package(last .. r)
end

local function dispatch_package(fd, last)
	while true do
		local msg, sz
		msg, sz, last = recv_package(fd, last)
		if msg == "" then
			close(fd)
			break
		end
		if msg then
			data(fd, msg, sz)
		end
	end
end

local function accept(fd)
	open(fd)
	local last = ""
	dispatch_package(fd, last)
	--socket.abandon(id)清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
	--socket.abandon(fd)
end

dispatch.start(nil, function ()
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		skynet.fork(accept, fd)
	end)
end)
