local switchAgentBenchmarkType = {
    switch_agent_ping = "switch_agent_ping",
    switch_agent_package = "switch_agent_package",
}

local serverAgentBenchmarkType = {
    server_agent_ping = "server_agent_ping",
    server_agent_package = "server_agent_package",
}

local config = {
    switchAgentBenchmark = switchAgentBenchmarkType.switch_agent_package,
    switchAgentFork = 15,
    serverAgentBenchmark = serverAgentBenchmarkType.server_agent_package,
}

return config
