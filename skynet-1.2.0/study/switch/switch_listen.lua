local skynet = require "skynet"
local log = require "common/log"
local socket = require "skynet.socket"
local dispatch = require "common/dispatch"

local _StatsNumber = 0
local _SumStatsNumber = 0

local function stats()
	skynet.sleep(100)
	log.fatal("_sumStatsNumber, _statsNumber", _SumStatsNumber, _StatsNumber)
	_StatsNumber = 0
	skynet.fork(stats)
end

dispatch.start(function ()
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		local agent = skynet.newservice("switch_fd_agent")
		socket.abandon(fd) ---清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
		skynet.call(agent,"lua", "open", fd)
		_SumStatsNumber =  _SumStatsNumber + 1
		_SumStatsNumber = _SumStatsNumber + 1
	end)
	skynet.fork(stats)
end)