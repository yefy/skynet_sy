local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local log = require "common/log"
local queue = require "skynet.queue"
local cs = queue()  -- cs 是一个执行队列
local cs2 = queue()  -- cs 是一个执行队列
math.randomseed(tostring(os.time()):reverse():sub(1, 6))

local CMD = {}
function CMD.do_chat_server_harbor1(...)
	skynet.sleep(25 * 1)
	log.print(log.fatalLevel(), "do_chat_server_harbor1", log.getArgvData(...))
end

function CMD.chat_server_harbor1(...)
	--CMD.do_chat_server_harbor1(...)
	cs(CMD.do_chat_server_harbor1, ...)
end


function CMD.do_chat_server_harbor2(...)
	local rand = math.random(1, 100 * 3)
	log.print(log.fatalLevel(), "rand", rand)
	skynet.sleep(25 * 1)
	log.print(log.fatalLevel(), "do_chat_server_harbor2", log.getArgvData(...))
end

function CMD.chat_server_harbor2(...)
	--log.print(log.fatalLevel(), "chat_server_harbor2", log.getArgvData(...))
	--CMD.do_chat_server_harbor2(...)
	cs2(CMD.do_chat_server_harbor2, ...)
end



skynet.start(function()
	skynet.dispatch("lua", function(_,_, command, ...)
		--print( command, ...)
		CMD[command](...)
		skynet.ret(skynet.pack(""))
	end)
	skynet.register "switch_harbor"
end)
