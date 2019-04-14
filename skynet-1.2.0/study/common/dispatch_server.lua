require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local server = class("dispatch_server")

local _uid
local _session = {}

function server:ctor(...)
end

function server:setUid(uid)
    _uid = uid
end

function server:addSession(session, head)
    _session[session] = {head = head}
end

return server