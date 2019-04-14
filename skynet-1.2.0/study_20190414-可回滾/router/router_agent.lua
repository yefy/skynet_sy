local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local client = dispatch.client
local server = dispatch.server

local function resume(handle, session)
	skynet.resume(handle, session)
end

function  server.router(source, data)
	log.fatal("router data", data)
	--[[
	local session = skynet.genid()
	log.fatal("skynet.self(), session", skynet.self(), session)
	skynet.fork(resume, skynet.self(), session)
	skynet.suspend(session)
	]]
	return 0
end

dispatch.start(nil, function ()
end)