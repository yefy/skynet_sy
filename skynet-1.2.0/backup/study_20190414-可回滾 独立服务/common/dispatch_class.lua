require "common/functions"
local skynet = require "skynet"
local log = require "common/log"
local Dispatch = class("dispatch_class")

function Dispatch:ctor(...)
    Dispatch.Client = {}
    Dispatch.Server = {}
end

return Dispatch