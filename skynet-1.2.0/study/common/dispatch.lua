local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"

local Dispatch = {}
local Client = {}
local Server = {}
Dispatch.Client = Client
Dispatch.Server = Server

local TypeNames = {
	Client = Client,
	Server = Server,
}

local cs

local function xpcall_ret(typeName, command, ok, error, ...)
	if not ok then
		log.error("xpcall_ret : typeName, command", typeName, command)
		error = -1
	end

	if not error then
		log.error("xpcall_ret error nil : typeName, command", typeName, command)
		error = -1
	end
	return error, ...
end

local function callFunc(typeName, source, command, ...)
	log.trace("typeName, source, command, ...", typeName, source, command, log.getArgvData(...))
	local server =  TypeNames[typeName]
	local func = server[command]
	if not cs then
		return xpcall_ret(typeName, command, xpcall(func, function() print(debug.traceback()) end, source, ...))
	else
		return cs(func, source, ...)
	end
end


function  Dispatch.actionCs()
	cs = queue()
end

function  Dispatch.start(func)
	skynet.register_protocol {
		name = "client",
		id = skynet.PTYPE_CLIENT,
		pack = skynet.pack,
		unpack = skynet.unpack,
		dispatch = function (session, source, command, ...)
			skynet.ret(skynet.pack(callFunc("Client", source, command, ...)))
		end
	}

	skynet.start(function()
		skynet.dispatch("lua", function(session, source, command, ...)
			skynet.ret(skynet.pack(callFunc("Server", source, command, ...)))
		end)
		if func then
			func()
		end
	end)
end

return Dispatch