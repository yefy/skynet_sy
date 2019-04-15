local skynet = require "skynet"
local log = require "common/log"
require "common/proto_create"
local protobuf = require "pblib/protobuf"
local queue = require "skynet.queue"
local dispatch = require "common/dispatch"

local commonConfig = skynet.getenv "commonConfig"
if commonConfig then
	commonConfig = require(commonConfig)
end

math.randomseed(tostring(os.time()):reverse():sub(1, 6))


dispatch.actionClass("server_player")

dispatch.start(function ()
end)