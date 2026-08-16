local BridgeLib = require('@BridgeLib.init')
BridgeLib.SetRoot('@BridgeLib')

Bridge = {}
isBridgeReady = false

local readyHandlers = {}

bridgeCore = BridgeLib.New({
    context = 'client',
    schema = Bridge,
    label = 'monstor-flightcinematic:client',
    modules = { 'framework', 'target' },
})

function OnBridgeReady(handler)
    if isBridgeReady then
        return handler()
    end

    readyHandlers[#readyHandlers + 1] = handler
end

CreateThread(function()
    bridgeCore:LoadAll()
    isBridgeReady = true

    for _, handler in ipairs(readyHandlers) do
        handler()
    end
end)
