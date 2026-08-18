local CUTSCENE_CHARACTER_MODEL = 'MP_1'
local LOAD_SCENE_TIMEOUT = 10000
local spawnedPeds = {}
local isTravelling = false

function ClearTravelScene()
    ClearFocus()
    ClearHdArea()
    NewLoadSceneStop()
end

function StartLoadScene(coords)
    NewLoadSceneStop()

    SetFocusPosAndVel(coords.x, coords.y, coords.z, 0.0, 0.0, 0.0)
    SetHdArea(coords.x, coords.y, coords.z, 200.0)
    RequestCollisionAtCoord(coords.x, coords.y, coords.z)

    if not NewLoadSceneStartSphere(coords.x, coords.y, coords.z, 1000.0, 0) then
        return false
    end

    local startedAt = GetGameTimer()

    while not IsNewLoadSceneLoaded() and GetGameTimer() - startedAt < LOAD_SCENE_TIMEOUT do
        Wait(0)
    end

    return IsNewLoadSceneLoaded()
end

function CollectSceneLoadCoords(route, sceneIndex)
    local coordsList = {}
    local sceneCount = #route.cutscene
    local sceneCoords = route.sceneLoadCoords[sceneIndex]

    if sceneCoords then
        coordsList[#coordsList + 1] = sceneCoords
    end

    if sceneIndex == sceneCount then
        for extraIndex = sceneCount + 1, #route.sceneLoadCoords do
            coordsList[#coordsList + 1] = route.sceneLoadCoords[extraIndex]
        end
    end

    if #coordsList == 0 then
        coordsList[#coordsList + 1] = route.sceneLoadCoords[#route.sceneLoadCoords]
    end

    return coordsList
end

function EndCutsceneSession()
    StopCutsceneImmediately()
    RemoveCutscene()

    if NetworkIsInTutorialSession() then
        NetworkEndTutorialSession()
    end
end

function PlayCutsceneScene(route, scene, sceneIndex, pedClone)
    if scene.playbackList then
        RequestCutsceneWithPlaybackList(scene.name, scene.playbackList, 8)
    else
        RequestCutscene(scene.name)
    end

    local startedAt = GetGameTimer()

    while not HasCutsceneLoaded() and GetGameTimer() - startedAt < 10000 do
        Wait(100)
    end

    if not HasCutsceneLoaded() then
        RemoveCutscene()
        return false
    end

    RegisterEntityForCutscene(pedClone, CUTSCENE_CHARACTER_MODEL, 0, 0, 0)
    SetCutsceneEntityStreamingFlags(CUTSCENE_CHARACTER_MODEL, 0, 1)

    local loadCoordsList = CollectSceneLoadCoords(route, sceneIndex)

    if loadCoordsList[1] then
        StartLoadScene(loadCoordsList[1])
    end

    if scene.customLoadCoords then
        SetCutsceneOriginAndOrientation(scene.customLoadCoords.x, scene.customLoadCoords.y, scene.customLoadCoords.z, 0, 0, scene.customLoadCoords.w or 0, 0)
    end

    Wait(500)

    if scene.customLoadCoords then
        StartCutsceneAtCoords(scene.customLoadCoords.x, scene.customLoadCoords.y, scene.customLoadCoords.z, 8)
    else
        StartCutscene(8)
    end

    startedAt = GetGameTimer()

    while not IsCutscenePlaying() and GetGameTimer() - startedAt < 5000 do
        Wait(0)
    end

    DoScreenFadeIn(500)

    startedAt = GetGameTimer()

    while not DoesCutsceneEntityExist(CUTSCENE_CHARACTER_MODEL, 0) and GetGameTimer() - startedAt < 10000 do
        Wait(100)
    end

    if DoesCutsceneEntityExist(CUTSCENE_CHARACTER_MODEL, 0) then
        ClonePedToTarget(cache.ped, pedClone)
    end

    for coordsIndex = 2, #loadCoordsList do
        StartLoadScene(loadCoordsList[coordsIndex])
    end

    local deadline = GetGameTimer() + (scene.endTime or 180000)

    while not HasCutsceneFinished() and GetGameTimer() < deadline do
        Wait(0)
    end

    DoScreenFadeOut(0)
    StopCutsceneImmediately()
    RemoveCutscene()

    return true
end

function PlayCutsceneTravel(route)
    local playerPed = cache.ped
    local played = false

    DoScreenFadeOut(500)
    Wait(2000)

    CancelEmote()
    DetachEntity(playerPed, true, false)
    Wait(350)

    local pedClone = ClonePed(playerPed, false, false, true)

    if pedClone and DoesEntityExist(pedClone) then
        NetworkStartSoloTutorialSession()

        local startedAt = GetGameTimer()

        while not NetworkIsInTutorialSession() and GetGameTimer() - startedAt < 10000 do
            Wait(100)
        end

        played = true

        for sceneIndex, scene in ipairs(route.cutscene) do
            if not PlayCutsceneScene(route, scene, sceneIndex, pedClone) then
                played = false
                break
            end
        end

        DeletePed(pedClone)
    end

    EndCutsceneSession()
    Wait(500)
    ClearTravelScene()
    Wait(500)

    StartLoadScene(route.destinationCoords)
    SetEntityCoords(cache.ped, route.destinationCoords.x, route.destinationCoords.y, route.destinationCoords.z)

    DoScreenFadeIn(500)

    local fadeStartedAt = GetGameTimer()

    while not IsScreenFadedIn() and GetGameTimer() - fadeStartedAt < 5000 do
        Wait(100)
    end

    ClearTravelScene()

    return played
end

function StartFlight(routeName)
    local route = Config.Routes[routeName]

    if not route then return end

    if isTravelling then
        Bridge.LocalNotify(Bridge.Locale('flightcinematic.alreadyTravelling'), 'error')
        return
    end

    if not CanTravel() then return end

    isTravelling = true

    local granted = lib.callback.await('monstor-flightcinematic:requestFlight', false, routeName)

    if not granted then
        isTravelling = false
        return
    end

    local completed = PlayCutsceneTravel(route)

    TriggerServerEvent('monstor-flightcinematic:flightFinished')
    isTravelling = false

    if not completed then
        Bridge.LocalNotify(Bridge.Locale('flightcinematic.flightFailed'), 'error')
    end
end

function BuildTargetOptions(departure)
    local options = {}

    for _, routeName in ipairs(departure.routes) do
        local route = Config.Routes[routeName]

        if route then
            options[#options + 1] = {
                name = ('monstor-flightcinematic:%s'):format(routeName),
                label = route.label,
                icon = route.icon or 'fas fa-plane-departure',
                action = function()
                    CreateThread(function()
                        StartFlight(routeName)
                    end)
                end
            }
        end
    end

    return { options = options, distance = 2.0 }
end

function SpawnDeparturePed(departureIndex)
    local departure = Config.Departures[departureIndex]

    if not departure or spawnedPeds[departureIndex] then return end

    local pedModel = joaat(departure.ped)

    if not lib.requestModel(pedModel, 10000) then return end

    local ped = CreatePed(4, pedModel, departure.coords.x, departure.coords.y, departure.coords.z, departure.coords.w, false, true)
    SetModelAsNoLongerNeeded(pedModel)

    if not DoesEntityExist(ped) then return end

    SetEntityInvincible(ped, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    FreezeEntityPosition(ped, true)
    SetPedDefaultComponentVariation(ped)
    SetPedDiesWhenInjured(ped, false)
    SetPedCanRagdollFromPlayerImpact(ped, false)

    spawnedPeds[departureIndex] = ped
    Bridge.AddTargetEntity(ped, BuildTargetOptions(departure))
end

function RemoveDeparturePed(departureIndex)
    local ped = spawnedPeds[departureIndex]

    if not ped then return end

    spawnedPeds[departureIndex] = nil

    if DoesEntityExist(ped) then
        Bridge.RemoveTargetEntity(ped)
        DeletePed(ped)
    end
end

function RemoveAllDeparturePeds()
    for departureIndex in pairs(spawnedPeds) do
        RemoveDeparturePed(departureIndex)
    end
end

function SpawnAllDeparturePeds()
    for departureIndex in ipairs(Config.Departures) do
        SpawnDeparturePed(departureIndex)
    end
end

RegisterNetEvent('monstor-flightcinematic:forceDetach', function(travellerServerId)
    if type(travellerServerId) ~= 'number' then return end
    if travellerServerId == cache.serverId then return end

    local travellerPed = GetPlayerPed(GetPlayerFromServerId(travellerServerId))

    if travellerPed == 0 or not DoesEntityExist(travellerPed) then return end
    if not IsEntityAttachedToEntity(cache.ped, travellerPed) then return end

    DetachEntity(cache.ped, true, false)
    CancelEmote()
end)

bridgeCore:On('playerLoaded', function()
    SpawnAllDeparturePeds()
end)

bridgeCore:On('playerUnloaded', function()
    RemoveAllDeparturePeds()
    isTravelling = false
end)

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    RemoveAllDeparturePeds()
end)

OnBridgeReady(function()
    SpawnAllDeparturePeds()
end)
