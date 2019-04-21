local skynet = require "skynet"
local log = require "common/log"
local dispatch = require "common/dispatch"
local thread = skynet.getenv "thread"

dispatch.actionServerCS()

local _AgentArr = {}
local _UidAgentMap = {}
local _ServerNameMap = {}

function  dispatch.register(serverName)
	log.fatal("register serverName", serverName)
	_ServerNameMap[serverName] = true
	for _uid, _agent in pairs(_UidAgentMap) do
		skynet.call(_agent, "lua", "register", _uid, serverName)
	end
	return 0
end


function  dispatch.getAgent(uid)
	local agent = _UidAgentMap[uid]
	if not agent then
		local index = uid % #_AgentArr + 1
		agent = _AgentArr[index]
		skynet.call(agent, "lua", "registerMap", uid, _ServerNameMap)
		_UidAgentMap[uid] = agent
	end
	log.trace("agent", agent)
	return 0, agent
end

dispatch.start(function ()
	for i = 1, thread * 3 * 3 do
		local agent = skynet.newservice("server_agent")
		table.insert(_AgentArr, agent)
	end
	skynet.register "server_server"
end)