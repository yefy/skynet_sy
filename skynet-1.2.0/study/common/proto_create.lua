local protobuf = require "pblib/protobuf"
local log = require "common/log"
--[[
local files = {
    "./study/protos/base.pb",
}

for _,file in ipairs(files) do
    print("注册协议文件："..file)
    protobuf.register_file(file)
end
]]

local f = assert(io.open("./study/protos/protoName",'r'))
while true do
    local fileName = f:read("*line")
    if not fileName then
        break
    end
    log.fatal("注册协议文件："..fileName)
    protobuf.register_file("./study/protos/" .. fileName)
end
f:close()