require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local dispatchClass = class("dispatch_class")

function dispatchClass:ctor(...)
    self.key = nil
    self.token = {}
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

function dispatchClass:addToken(token, session, source, head)
    --log.fatal("addToken key, self.token, id, self, token, session, source, head", self:getKey(), self.token, skynet.self(), self, token, session, source, head)
    if self.token[token] then
        log.fatal("exist key, self.token, id, self, token, session, source, head", self:getKey(), self.token, skynet.self(), self, token, session, source, head)
        log.printTable(log.fatalLevel(), {{head, "head"}})
        --skynet.exit()
        return false
    end
    self.token[token] = {session = session, source = source, head = head}
    return true
end

function dispatchClass:clearToken(token, session, source, head)
    --log.fatal("clearToken key, self.token, id, self, token, session, source, head", self:getKey(), self.token, skynet.self(), self, token, session, source, head)
    if not self.token[token] then
        log.fatal("not key, self.token, id, self, token, session, source, head", self:getKey(), self.token, skynet.self(), self, token, session, source, head)
        log.printTable(log.fatalLevel(), {{head, "head"}})
        --skynet.exit()
        return false
    end
    self.token[token] = nil
    return true
end

function dispatchClass:getSource(token)
    if not self.token[token] then
        log.error("not token", token)
        return
    end
    return self.token[token].source
end

function dispatchClass:getHead(token)
    if not self.token[token] then
        log.error("not token", token)
        return
    end
    return self.token[token].head
end

function dispatchClass:callServer(token, serverName, command, ...)
    --log.fatal("111callServer key, self.token, id, self, token", self:getKey(), self.token, skynet.self(), self, token)
    local source = self:getSource(token)
    local head = self:getHead(token)
    local a = self.token
    --log.fatal("222callServer key, self.token, id, self, token", self:getKey(), self.token, skynet.self(), self, token)
    skynet.call(source, "lua", "callServer", head.sourceUid, serverName, command, head.sourceUid, ...)
    --log.fatal("333callServer key, self.token, id, self, token", self:getKey(), self.token, skynet.self(), self, token)
    local b = self.token
    if a ~= b then
        log.error("a ~= b")
    end
    return 0, "123"
end

function dispatchClass:sendServer(token, serverName, command, ...)
    local source = self:getSource(token)
    local head = self:getHead(token)
    skynet.send(source, "lua", "callServer", head.sourceUid, serverName, command, head.sourceUid, ...)
end

function dispatchClass:callRouter(token, serverName, command, ...)
    local routerSession = self:sendRouter(token, serverName, command, ...)
    return skynet.suspend(routerSession)
end

function dispatchClass:sendRouter(token, serverName, command, ...)
    local source = self:getSource(token)
    local head = self:getHead(token)
    local routerSession = skynet.genid()
    log.trace("sendRouter key,  skynet.self(), routerSession, serverName, command, head.sourceUid, head.destUid", self:getKey(), skynet.self(), routerSession, serverName, command, head.sourceUid, head.destUid)
    local headMsg, headSz = skynet.pack(skynet.self(), routerSession, serverName, command, head.sourceUid, head.destUid)
    local headStr = skynet.tostring(headMsg, headSz)
    skynet.trash(headMsg, headSz)
    local headPack = string.pack_package(headStr)
    local bodyMsg, bodySz = skynet.pack(head.sourceUid, ...)
    local bodyStr = skynet.tostring(bodyMsg, bodySz)
    skynet.trash(bodyMsg, bodySz)
    local bodyPack = string.pack_package(bodyStr)
    local pack = string.pack_package(headPack..bodyPack)
    skynet.send(source, "lua", "callServer", head.sourceUid, "router_server", "router", head.destUid, skynet.self(), routerSession, pack)
    return routerSession
end

return dispatchClass