require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local server = class("dispatch_server")

function server:ctor(...)
    self.uid = nil
    self.client = nil
end

function server:setUid(uid)
    self.uid = uid
end

function server:getUid()
    return self.uid
end

function server:setClient(client)
    self.client = client
end

function server:getClient()
    return self.client
end

return server