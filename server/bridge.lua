local BridgeLib = require('@BridgeLib.init')
BridgeLib.SetRoot('@BridgeLib')

Bridge = {}
isBridgeReady = false

local readyHandlers = {}

bridgeCore = BridgeLib.New({
    context = 'server',
    schema = Bridge,
    label = 'monstor-flightcinematic:server',
    modules = { 'framework', 'inventory', 'logging' },
})

function OnBridgeReady(handler)
    if isBridgeReady then
        return handler()
    end

    readyHandlers[#readyHandlers + 1] = handler
end

CreateThread(function()
    bridgeCore:LoadAll()
    Bridge.InitNetworkEvents()
    isBridgeReady = true

    for _, handler in ipairs(readyHandlers) do
        handler()
    end
end)
