package.cpath = "luaclib/?.so;study/pblib/?.so"
package.path = "lualib/?.lua;study/?.lua"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local socket = require "client.socket"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local log = require("common/log")

local last = ""
local session = 0

local fd = assert(socket.connect("127.0.0.1", 8888))

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

local function recv_package(last)
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
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = name
	send_package(fd, str)
	print("Request:", session)
end


local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function sendLogin()
	session = session + 1
	local rHead = {
		ver = 1,
		session = session,
		server = "player_agent",
		command = "login",
		sourceUid = 1,
		destUid = 1,
		error = 0,
	}
	local rLogin = {
		password = "123456"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rLoginMessage = protobuf.encode("base.Login",rLogin)
	local rLoginPackage = package(rLoginMessage)
	send_package(fd, package(rHeadPackage .. rLoginPackage))
end

local function sendChat()
	session = session + 1
	local rHead = {
		ver = 1,
		session = session,
		server = "chat_server",
		command = "chat",
		sourceUid = 1,
		destUid = 2,
		error = 0,
	}
	local rChat = {
		message = "chat_hello"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rChatMessage = protobuf.encode("base.Chat",rChat)
	local rChatPackage = package(rChatMessage)
	send_package(fd, package(rHeadPackage .. rChatPackage))
end

local function sendMessage()
	session = session + 1
	local rHead = {
		ver = 1,
		session = session,
		server = "message_server",
		command = "message",
		sourceUid = 1,
		destUid = 2,
		error = 0,
	}
	local rMessage = {
		message = "message_hello"
	}
	local rHeadMessage = protobuf.encode("base.Head",rHead)
	local rHeadPackage = package(rHeadMessage)
	local rMessageMessage = protobuf.encode("base.Message",rMessage)
	local rMessagePackage = package(rMessageMessage)
	send_package(fd, package(rHeadPackage .. rMessagePackage))
end

local function onRespond(msg, sz)
	local rHeadMessage, rHeadSize, msg  = unpack_package(msg)
	local rHeadData = protobuf.decode("base.Head", rHeadMessage, rHeadSize);
	log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
	if rHeadData.server == "player_agent" and rHeadData.command == "login" then
		local rHeadMessage, rHeadSize, msg  = unpack_package(msg)
		local rHeadData = protobuf.decode("base.Login", rHeadMessage, rHeadSize);
		log.printTable(log.fatalLevel(), {{rHeadData, "rHeadData"}})
	end
end

local function dispatch_package()
	while true do
		local msg, sz
		msg, sz, last = recv_package(last)
		if not msg then
			break
		end
		onRespond(msg, sz)
	end
end
--[[
while true do
	dispatch_package()
	sendRequest()
	socket.usleep(10000)
	--socket.usleep(1000000)
end
]]
for i = 1, 1 do
	sendLogin()
	sendChat()
	sendMessage()
	--[[
	sendChat()
	log.fatal("sleep stat")
	socket.usleep(1000000* 10)
	log.fatal("sleep end")
	sendChat()
	]]
end
socket.usleep(1000000)
socket.usleep(1000000)
dispatch_package()
