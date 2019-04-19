require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = class("dispatch_class")

function dispatchClass:ctor(...)
    self.key = nil
    self.session = {}
    self.dispatch = nil
end

function dispatchClass:setDispatch(dispatch)
    self.dispatch = dispatch
end

function dispatchClass:getDispatch()
    return self.dispatch
end

function dispatchClass:setKey(key)
    self.key = key
end

function dispatchClass:getKey()
    return self.key
end

function dispatchClass:addSession(session, source, head)
    self.session[session] = {source = source, head = head}
end

function dispatchClass:clearSession(session)
    self.session[session] = nil
end

function dispatchClass:getSource(session)
    return self.session[session].source
end

function dispatchClass:getHead(session)
    return self.session[session].head
end

function dispatchClass:callServer(session, serverName, command, ...)
    local source = self:getSource(session)
    local head = self:getHead(session)
    return skynet.call(source, "lua", "callServer", head.sourceUid, serverName, command, head.sourceUid, ...)
end

function dispatchClass:sendServer(session, serverName, command, ...)
    local source = self:getSource(session)
    local head = self:getHead(session)
    skynet.send(source, "lua", "callServer", head.sourceUid, serverName, command, head.sourceUid, ...)
end



return dispatchClass