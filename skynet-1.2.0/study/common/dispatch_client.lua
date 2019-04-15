require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local client = class("dispatch_client")

function client:ctor(...)
    self.uid = nil
    self.session = nil
    self.server = nil
end

function client:setUid(uid)
    self.uid = uid
end

function client:getUid()
    return self.uid
end

function client:setServer(server)
    self.server = server
end

function client:getServer()
    return self.server
end

function client:addSession(session, source, head)
    self.session[session] = {source = source, head = head}
end

function client:clearSession(session)
    self.session[session] = nil
end

return client