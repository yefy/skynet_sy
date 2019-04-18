package.cpath = "luaclib/?.so;study/pblib/?.so"
package.path = "lualib/?.lua;study/?.lua"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local socket = require "client.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require("common/log")

math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local session = 0

local function package(msg)
	local package = string.pack(">s2", msg)
	return package
end

local function send_package(fd, package)
	socket.send(fd, package)
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

local function recv_package(fd,last)
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
		return r
	end
	return unpack_package(last .. r)
end

local function sendLogin(data)
	session = session + 1
	log.trace("sendLogin session", session)
	local rHead = {
		ver = 1,
		session = session,
		server = "player_server",
		command = "login",
		sourceUid = data.sourceUid,
		destUid = data.sourceUid,
		error = 0,
	}
	local rLogin = {
		password = "123456"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rLoginMessage = protobuf.encode("base.Login",rLogin)
	local rLoginPackage = package(rLoginMessage)
	send_package(data.fd, package(rHeadPackage .. rLoginPackage))
end

local function sendChat(data)
	session = session + 1
	log.trace("sendChat session", session)
	local rHead = {
		ver = 1,
		session = session,
		server = "chat_server",
		command = "chat",
		sourceUid = data.sourceUid,
		destUid = data.destUid,
		error = 0,
	}
	local rChat = {
		message = "chat_hello"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rChatMessage = protobuf.encode("base.Chat",rChat)
	local rChatPackage = package(rChatMessage)
	send_package(data.fd, package(rHeadPackage .. rChatPackage))
end

local function sendMessage(data)
	session = session + 1
	log.trace("sendMessage session", session)
	local rHead = {
		ver = 1,
		session = session,
		server = "message_server",
		command = "message",
		sourceUid = data.sourceUid,
		destUid = data.destUid,
		error = 0,
	}
	local rMessage = {
		message = "message_hello"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rMessageMessage = protobuf.encode("base.Message",rMessage)
	local rMessagePackage = package(rMessageMessage)
	send_package(data.fd, package(rHeadPackage .. rMessagePackage))
end

local minSend = 2000
local maxSend = 3000
local socketNumber = ...
if not socketNumber then
	socketNumber = 1
end
local fds = {}
local map = {[1] = sendLogin, [2] = sendChat, [3] = sendMessage}
local sumSendPackage = 0
local sumRecvdPackage = 0



local function onRespond(data, msg, sz)
	local rHeadMessage, rHeadSize, msg  = unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage, rHeadSize)

	--log.fatal("data.session[rHeadData.command], data.session", data.session[rHeadData.command], rHeadData.session)
	assert(data.session[rHeadData.command] < rHeadData.session)
	data.session[rHeadData.command] = rHeadData.session
	--log.fatal("recv rHeadData.session, rHeadData.command", rHeadData.session, rHeadData.command)
	--[[
	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
	if rHeadData.server == "player_server" and rHeadData.command == "login" then
		local rHeadMessage, rHeadSize, msg  = unpack_package(msg)
		local rHeadData = protobuf.decode("base.Login", rHeadMessage, rHeadSize);
		log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
	end
	]]
end


local function send_rand_package(_data)
	local rand = math.random(1, #map)
	map[rand](_data)
end

for i = 1, socketNumber do
	local fd = assert(socket.connect("127.0.0.1", 8888))
	local sourceUid = math.random(1, 100000000)
	local destUid
	while true do
		destUid = math.random(1, 100000000)
		if destUid ~= sourceUid then
			break
		end
	end
	fds[fd] = {fd = fd, sourceUid = sourceUid, destUid = destUid, send = 0, sumSend = 0, last = "",
			   session = {
				   message = -1,
				   chat = -1,
				   login = -1,
			   }
	}
end

while true do
	local delFds = {}
	local ismsgnil = false
	for _, _data in pairs(fds) do
		local send = _data.send
		if send > 0 then
			local msg, sz
			for i = 1, 10 do
				msg, sz, _data.last = recv_package(_data.fd, _data.last)
				if not msg then
					ismsgnil = true
					break
				end

				if msg == "" then
					table.insert(delFds, _data.fd)
					break
				end
				onRespond(_data, msg, sz)
				_data.send = _data.send - 1
				sumRecvdPackage = sumRecvdPackage + 1
			end
		else
			assert(send == 0)
			local rand = math.random(minSend, maxSend)
			_data.send = rand
			_data.sumSend = _data.sumSend + rand
			sumSendPackage = sumSendPackage + rand
			for i = 1, rand do
				send_rand_package(_data)
			end
		end
	end

	for _, _fd in pairs(delFds) do
		fds[_fd] = nil
	end

	print("sumSendPackage, sumRecvdPackage", sumSendPackage, sumRecvdPackage)

	local isnil = true
	for _fd, _ in pairs(fds) do
		isnil = false
	end
	if isnil then
		break
	end

	if ismsgnil then
		socket.usleep(0)
	end
end

for _fd, _ in pairs(fds) do
	socket.close(_fd)
end

--socket.usleep(1000000)
