require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = class("dispatch_class")

function dispatchClass:ctor(...)
    self.uid = nil
    self.session = {}
end

function dispatchClass:setUid(uid)
    self.uid = uid
end

function dispatchClass:getUid()
    return self.uid
end

function dispatchClass:addSession(session, source, head)
    self.session[session] = {source = source, head = head}
end

function dispatchClass:clearSession(session)
    self.session[session] = nil
end



return dispatchClass