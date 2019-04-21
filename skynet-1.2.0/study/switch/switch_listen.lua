local skynet = require "skynet"
local log = require "common/log"
local socket = require "skynet.socket"
local dispatch = require "common/dispatch"
local thread = skynet.getenv "thread"

local _StatsNumber = 0
local _SumStatsNumber = 0
local _playerNumber = 0
local _SumPlayerNumber = 0

local function stats()
	skynet.sleep(1000)
	log.fatal("_sumStatsNumber, _statsNumber, _SumPlayerNumber, _playerNumber", _SumStatsNumber, _StatsNumber, _SumPlayerNumber, _playerNumber)
	_StatsNumber = 0
	_playerNumber = 0
	skynet.fork(stats)
end


local _AgentArr = {}

local function  getAgent(fd)
	local index = fd % #_AgentArr + 1
	return _AgentArr[index]
end

function  dispatch.add()
	_playerNumber = _playerNumber + 1
	_SumPlayerNumber = _SumPlayerNumber + 1
	return 0
end

dispatch.start(function ()
	log.fatal("socket.listen 127.0.0.1 8888")
	local lfd = socket.listen("127.0.0.1", 8888)
	socket.start(lfd , function(fd, addr)
		log.fatal("connect from addr, fd", addr, fd)
		_StatsNumber =  _StatsNumber + 1
		_SumStatsNumber = _SumStatsNumber + 1
		local agent = getAgent(fd)
		socket.abandon(fd) ---清除 socket id 在本服务内的数据结构，但并不关闭这个 socket 。这可以用于你把 id 发送给其它服务，以转交 socket 的控制权。
		skynet.call(agent,"lua", "open", fd, skynet.self())
	end)
	for i = 1, thread * 3 * 3 do
		local agent = skynet.newservice("switch_fd_agent")
		table.insert(_AgentArr, agent)
	end
	--skynet.fork(stats)
end)