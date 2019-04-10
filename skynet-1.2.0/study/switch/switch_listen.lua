local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local socket = require "skynet.socket"
local client = dispatch.client
local server = dispatch.server
local agentMap = {}

--https://blog.csdn.net/selfi_xiaowen/article/details/70596565
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

local function data(fd, pack, packSize)
	log.fatal("data fd, pack, packSize", fd, pack, packSize)
	local agent = agentMap[fd].agent
	skynet.call(agent,"lua", "data", pack, packSize)
end

local function close(fd)
	log.fatal("close fd", fd)
	local agent = agentMap[fd].agent
	skynet.call(agent,"lua", "close")
	agentMap[fd] = nil
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
	open(fd)
	recv_package(fd)
	skynet.exit()
	--socket.abandon(id)清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
	--socket.abandon(fd)
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
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		skynet.fork(accept, fd)
	end)
end)
