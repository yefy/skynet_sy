local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"

local _Client_fd = -1
local _ServerAgent
local _Uid
local _MaxPackageSize = 9 * 1024
local _MaxCacheSize = 64 *1024 * 1024
local _StatsNumber = 0
local _SumStatsNumber = 0

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end

local _CS
local _ForkNumber = commonConfig.switchAgentFork or 1
if _ForkNumber > 1 then
	_CS = queue()
end

local _AgentCS = queue()

local function send_package(package)
	socket.write(_Client_fd, package)
end

local function stats()
	skynet.sleep(100)
	log.fatal("_Client_fd, _Uid, _SumStatsNumber, _StatsNumber", _Client_fd, _Uid, _SumStatsNumber, _StatsNumber)
	_StatsNumber = 0
	skynet.fork(stats)
end

local function close()
	if _Client_fd ~= -1 then
		log.fatal("close _Client_fd", _Client_fd)
		socket.close(_Client_fd)
		_Client_fd = -1
		skynet.exit()
	end
end

local function invalidPackage(size)
	log.error("_Client_fd, size", _Client_fd, size)
	close()
end

local function invalidCache(size)
	log.error("_Client_fd, size", _Client_fd, size)
	close()
end

local function  data(pack, packSize)
	_StatsNumber = _StatsNumber + 1
	_SumStatsNumber = _SumStatsNumber + 1
	log.trace("_Client_fd, pack, packSize", _Client_fd, pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	log.trace("head.session", head.session)
	log.printTable(log.allLevel(), {{head, "head"}})
	if _Uid and _Uid ~= head.sourceUid then
		log.error("_Uid, rHeadData.sourceUid",_Uid ~= head.sourceUid)
		return
	end
	_Uid = _Uid or head.sourceUid

	local error = -1
	if commonConfig.switchAgentBenchmark == "switch_agent_package" then
		_AgentCS(function ()
			if not _ServerAgent then
				_, _ServerAgent = skynet.call("server_server", "lua", "getAgent", _Uid)
			end
		end)

		log.trace("source, desc, _Uid, rHeadData.server, rHeadData.command, pack", skynet.self(), _ServerAgent, _Uid, head.server, head.command, pack)
		error, pack = skynet.call(_ServerAgent, "client", "callClient", pack)
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

local function getPackageSize()
	local pack = socket.read(_Client_fd, 2)
	if not pack then
		return nil
	end
	return pack:byte(1) * 256 + pack:byte(2)
end

local function recv_package()
	if _Client_fd == -1 then
		return nil
	end

	local size = getPackageSize()
	if not size then
		close()
		return nil
	end
	if size > _MaxPackageSize then
		invalidPackage(size)
		return nil
	end
	local pack = socket.read(_Client_fd, size)
	if not pack then
		close()
		return nil
	end
	return pack, size
end

local function fork_recv_package()
	while true do
		if _CS then
			local pack, size = _CS(recv_package)
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
	if size > _MaxCacheSize then
		invalidCache(size)
	end
end

local function open(fd)
	log.fatal("open fd", fd)
	_Client_fd = fd
	socket.start(fd)
	socket.warning(fd, warning)
	for i = 1, _ForkNumber do
		skynet.fork(fork_recv_package)
	end
end

function  dispatch.open(fd)
	skynet.fork(stats)
	open(fd)
	return 0
end

dispatch.start(function ()
end)
