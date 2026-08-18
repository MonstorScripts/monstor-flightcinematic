local flightTransit = {}
local lastRequest = {}
local routeDepartures = {}
local boardingDistanceSquared = 64.0

function BuildRouteDepartures()
    local boardingDistance = Config.BoardingDistance or 8.0
    boardingDistanceSquared = boardingDistance * boardingDistance

    for _, departure in ipairs(Config.Departures) do
        for _, routeName in ipairs(departure.routes) do
            routeDepartures[routeName] = routeDepartures[routeName] or {}
            routeDepartures[routeName][#routeDepartures[routeName] + 1] = vector3(departure.coords.x, departure.coords.y, departure.coords.z)
        end
    end
end

function CheckRequestCooldown(playerId)
    local now = GetGameTimer()
    local previous = lastRequest[playerId]

    if previous and now - previous < 3000 then
        return false
    end

    lastRequest[playerId] = now

    return true
end

function SetFlightTransit(playerId, inTransit)
    if not inTransit then
        flightTransit[playerId] = nil
        return
    end

    flightTransit[playerId] = true

    SetTimeout(120000, function()
        flightTransit[playerId] = nil
    end)
end

function IsAtDeparture(playerId, routeName)
    local departures = routeDepartures[routeName]

    if not departures then return false end

    local playerPed = GetPlayerPed(playerId)

    if playerPed == 0 then return false end

    local playerCoords = GetEntityCoords(playerPed)

    for _, departureCoords in ipairs(departures) do
        local deltaX = playerCoords.x - departureCoords.x
        local deltaY = playerCoords.y - departureCoords.y
        local deltaZ = playerCoords.z - departureCoords.z

        if deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ <= boardingDistanceSquared then
            return true
        end
    end

    return false
end

function ChargeFare(playerId, route, jobPerks)
    if jobPerks and jobPerks.freeFare then
        return true, 0
    end

    local fare = route.fare or Config.DefaultFare

    if fare <= 0 then
        return true, 0
    end

    local player = Bridge.GetPlayer(playerId)

    if not player then return false, fare end

    if player.GetAccountMoney('money') < fare then
        return false, fare
    end

    player.RemoveAccountMoney('money', fare)

    return true, fare
end

function ConfiscateContraband(playerId)
    local confiscated = {}
    local inventory = Bridge.GetInventoryItems(playerId) or {}

    for _, slot in pairs(inventory) do
        local itemName = slot and slot.name

        if type(itemName) == 'string' and Config.BlockedItems[itemName:lower()] then
            local count = slot.count or slot.amount or 0

            if count > 0 and Bridge.RemoveItem(playerId, itemName, count) then
                confiscated[#confiscated + 1] = ('%s x%s'):format(itemName, count)
            end
        end
    end

    return confiscated
end

function ConfiscateExcessCash(playerId)
    local allowance = Config.MaxCashAllowance

    if not allowance or allowance < 0 then return 0 end

    local player = Bridge.GetPlayer(playerId)

    if not player then return 0 end

    local held = player.GetAccountMoney('money')

    if held <= allowance then return 0 end

    local excess = held - allowance
    player.RemoveAccountMoney('money', excess)

    return excess
end

function LogFlight(player, routeName, fare, confiscated, excessCash, note)
    local confiscatedValue = note


    if not confiscatedValue then
        confiscatedValue = (confiscated and #confiscated > 0) and table.concat(confiscated, ', ') or 'Nothing was confiscated.'
    end

    if excessCash > 0 then
        confiscatedValue = ('%s (cash over the allowance: %s)'):format(confiscatedValue, excessCash)
    end

    Bridge.LogFields(Config.LogCategory, 'A player has taken a flight.', Config.LogColour, {
        { name = 'Player', value = player.UniqueId, inline = true },
        { name = 'Type of Flight', value = routeName, inline = true },
        { name = 'Money Removed', value = fare > 0 and fare or 'No Money Removed', inline = true },
        { name = 'Items Confiscated', value = confiscatedValue, inline = true },
        { name = 'Job', value = player.JobName, inline = true }
    })
end

lib.callback.register('monstor-flightcinematic:requestFlight', function(source, routeName)
    local playerId = source

    if not CheckRequestCooldown(playerId) then return false end
    if type(routeName) ~= 'string' then return false end

    local route = Config.Routes[routeName]

    if not route then return false end

    if flightTransit[playerId] then
        Bridge.Notify(playerId, Bridge.Locale('flightcinematic.alreadyTravelling'), 'error')
        return false
    end

    local player = Bridge.GetPlayer(playerId)

    if not player then return false end

    if not IsAtDeparture(playerId, routeName) then
        Bridge.Notify(playerId, Bridge.Locale('flightcinematic.tooFarFromPilot'), 'error')
        return false
    end

    local jobPerks = Config.Jobs[player.JobName]
    local charged, fare = ChargeFare(playerId, route, jobPerks)

    if not charged then
        Bridge.Notify(playerId, Bridge.Locale('flightcinematic.notEnoughMoney'), 'error')
        return false
    end

    SetFlightTransit(playerId, true)
    TriggerClientEvent('monstor-flightcinematic:forceDetach', -1, playerId)

    if jobPerks and jobPerks.keepItems then
        Bridge.Notify(playerId, Bridge.Locale('flightcinematic.jobKeepsItems'), 'success')
        LogFlight(player, routeName, fare, nil, 0, 'No items were confiscated, the job allows the player to keep them.')
        return true
    end

    if not route.confiscateContraband then
        LogFlight(player, routeName, fare, nil, 0, 'No items were confiscated, this route does not run customs checks.')
        return true
    end

    local confiscated = ConfiscateContraband(playerId)
    local excessCash = ConfiscateExcessCash(playerId)

    if #confiscated > 0 or excessCash > 0 then
        Bridge.Notify(playerId, Bridge.Locale('flightcinematic.itemsConfiscated'), 'error')
    end

    LogFlight(player, routeName, fare, confiscated, excessCash)

    return true
end)

RegisterNetEvent('monstor-flightcinematic:flightFinished', function()
    local playerId = source

    if not flightTransit[playerId] then return end

    SetFlightTransit(playerId, false)
end)

AddEventHandler('playerDropped', function()
    local playerId = source

    flightTransit[playerId] = nil
    lastRequest[playerId] = nil
end)

AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    BuildRouteDepartures()
end)