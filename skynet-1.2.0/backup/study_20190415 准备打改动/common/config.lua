local switchBenchmarkType = {
    switch_listen_ping = "switch_listen_ping",
    switch_listen_package = "switch_listen_package",
    switch_listen_fd = "switch_listen_fd",
}

local switchAgentBenchmarkType = {
    switch_agent_ping = "switch_agent_ping",
    switch_agent_package = "switch_agent_package",
}

local serverAgentBenchmarkType = {
    server_agent_ping = "server_agent_ping",
    server_agent_package = "server_agent_package",
}

local config = {
    switchBenchmark = switchBenchmarkType.switch_listen_fd,
    switchStats = false,
    switchAgentBenchmark = switchAgentBenchmarkType.switch_agent_ping,
    switchAgentStats = true,
    switchAgentFork = 5,
    serverAgentBenchmark = serverAgentBenchmarkType.server_agent_package,
}

return config
