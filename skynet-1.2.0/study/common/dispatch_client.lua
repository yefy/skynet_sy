require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local client = class("dispatch_client")
local _uid
local _session = {}

function client:ctor()
    self.uid = nil
    self.session = nil
end

function client:setUid(uid)
    _uid = uid
end

function client:addSession(session, source, head)
    _session[session] = {source = source, head = head}
end

return client