local skynet = require "skynet"
local socket = require "skynet.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require "common/log"
require("common/stringEx")
local queue = require "skynet.queue"
local dispatchClass = require ("common/dispatch_class")
local dispatch = class("dispatch", dispatchClass)

local dispatchSocket = class("dispatch_class")

local _MaxPackageSize = 9 * 1024
local _MaxCacheSize = 64 *1024 * 1024
local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end
local _ForkNumber = commonConfig.switchAgentFork or 1
local _DispatchSocketMap = {}


local function send_package(fd, package)
	if fd then
		socket.write(fd, package)
	end
end

function dispatchSocket:ctor(...)
	self.statsNumber = 0
	self.sumStatsNumber = 0
	self.dispatch = nil
	self.source = nil
	self.fd = nil
	self.agent = nil
	self.uid = nil
	self.cs = _ForkNumber > 1 and queue() or nil
	self.agentCS = queue()
end

function dispatchSocket:stats()
	skynet.sleep(1000)
	log.fatal("id, self, fd, self.uid, sumStatsNumber, statsNumber", skynet.self(), self, self.fd, self.uid, self.sumStatsNumber, self.statsNumber)
	self.statsNumber = 0
	if self.fd then
		skynet.fork(self["stats"], self)
	end
end

function dispatchSocket:close()
	if self.fd then
		log.fatal("close fd", self.fd)
		--self.dispatch.close(self.fd)
		socket.close(self.fd)
		self.fd = nil
	end
end

function dispatchSocket:invalidPackage(size)
	log.error("fd, size", self.fd, size)
	self:close()
end

function dispatchSocket:invalidCache(size)
	log.error("fd, size", self.fd, size)
	self:close()
end

function  dispatchSocket:data(pack, packSize)
	log.trace("fd, pack, packSize", self.fd, pack, packSize)
	local headMsg, headSize, _ = string.unpack_package(pack)
	local head = protobuf.decode("base.Head", headMsg)
	if not head then
		log.error("parse head nil")
		return
	end
	log.trace("head.session", head.session)
	log.printTable(log.allLevel(), {{head, "head"}})
	if self.uid and self.uid ~= head.sourceUid then
		log.error("self.uid, rHeadData.sourceUid",self.uid ~= head.sourceUid)
		return
	end
	self.uid = self.uid or head.sourceUid

	local error = -1
	if commonConfig.switchAgentBenchmark == "switch_agent_package" then
		self.agentCS(function ()
			if not self.agent then
				_, self.agent = skynet.call("server_server", "lua", "getAgent", self.uid)
			end
		end)

		log.trace("source, desc, self.uid, rHeadData.server, rHeadData.command, pack", skynet.self(), self.agent, self.uid, head.server, head.command, pack)
		error, pack = skynet.call(self.agent, "client", "client", "callClient", pack)
	end
	self.statsNumber = self.statsNumber + 1
	self.sumStatsNumber = self.sumStatsNumber + 1
	skynet.send(self.source, "lua", "add")
	log.trace("error, pack", error, pack)
	if error ~= 0 then
		head.error = error
		local headMsg = protobuf.encode("base.Head",head)
		local headPack = string.pack_package(headMsg)
		pack = string.pack_package(headPack)
	end
	send_package(self.fd, pack)
	return 0
end

function dispatchSocket:getPackageSize()
	local pack = socket.read(self.fd, 2)
	if not pack then
		return nil
	end
	return pack:byte(1) * 256 + pack:byte(2)
end

function dispatchSocket:recv_package()
	if not self.fd then
		return nil
	end

	local size = self:getPackageSize()
	if not size then
		self:close()
		return nil
	end
	if size > _MaxPackageSize then
		self:invalidPackage(size)
		return nil
	end
	local pack = socket.read(self.fd, size)
	if not pack then
		self:close()
		return nil
	end
	return pack, size
end

function dispatchSocket:fork_recv_package()
	while true do
		if self.cs then
			local pack, size = self.cs(self["recv_package"], self)
			if not pack then
				break
			end
			self:data(pack, size)
		else
			local pack, size = self:recv_package()
			if not pack then
				break
			end
			self:data(pack, size)
		end
	end
end

local function warning(fd, size)
	if size > _MaxCacheSize then
		local dispatchSocket = _DispatchSocketMap[fd]
		dispatchSocket:invalidCache(size)
	end
end

function  dispatchSocket:open(source, fd, dispatch)
	log.fatal("source, open fd, dispatch", source, fd, dispatch)
	self.source = source
	self.fd = fd
	self.dispatch = dispatch
	socket.start(fd)
	socket.warning(fd, warning)
	for i = 1, _ForkNumber do
		skynet.fork(self["fork_recv_package"], self)
	end
	skynet.fork(self["stats"], self)
	return 0
end


function dispatch:ctor(...)
end

function  dispatch:open(source)
	local socket = dispatchSocket.new()
	_DispatchSocketMap[self:getKey()] = socket
	return socket:open(source, self:getKey(), self:getDispatch())
end

return dispatch
