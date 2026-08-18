Config = Config or {}

Config.LogCategory = 'flight'
Config.LogColour = '15844367'

Config.DefaultFare = 10000

Config.EmoteResource = 'rpemotes'

Config.MaxCashAllowance = 10000

Config.BoardingDistance = 8.0

Config.PedSpawnDistance = 100.0

Config.AttachedScanDistance = 5.0

Config.Jobs = {
    police = { keepItems = true, freeFare = true },
    doj = { keepItems = true, freeFare = true },
    ambulance = { keepItems = false, freeFare = true },
}

Config.CarryPedModels = {
    [`mp_m_freemode_01`] = true,
    [`mp_f_freemode_01`] = true
}

Config.BlockedItems = {
    ['weapon_pistol'] = true,
}

function ScenesToBitwise(scenes)
    local flags = 0

    for _, sceneNumber in ipairs(scenes) do
        flags = flags | (1 << sceneNumber)
    end

    return flags
end

Config.Routes = {
    LS_TO_CAYO = {
        label = 'Take off to Cayo Perico',
        fare = 10000,
        confiscateContraband = true,
        destinationCoords = vector3(4432.96, -4493.7, 3.2),
        sceneLoadCoords = {
            vec3(4375.49, -4535.19, 3.18)
        },
        cutscene = {
            { name = 'hs4_nimb_lsa_isd', playbackList = ScenesToBitwise({ 10, 11 }) }
        }
    },
    CAYO_TO_LS = {
        label = 'Take Plane to Los Santos',
        fare = 10000,
        confiscateContraband = true,
        destinationCoords = vector3(-1037.08, -2742.10, 19.17),
        sceneLoadCoords = {
            vector3(4432.96, -4493.7, 3.2),
            vector4(-1037.08, -2742.10, 19.17, 346)
        },
        cutscene = {
            { name = 'hs4_nimb_isd_lsa', playbackList = ScenesToBitwise({ 3 }) },
            { name = 'hs4_lsa_land_nimb', playbackList = ScenesToBitwise({ 0 }), endTime = 8000 }
        }
    },
    SANDY_TO_CAYO = {
        label = 'Take Plane to Cayo',
        fare = 100000,
        confiscateContraband = false,
        destinationCoords = vector3(4432.96, -4493.7, 3.2),
        sceneLoadCoords = {
            vector4(1591.34, 3220.04, 40.41, 104),
            vector3(-3506.09, 7697.03, 44.83)
        },
        cutscene = {
            { name = 'hs4_vel_lsa_isd', playbackList = ScenesToBitwise({ 0 }) }
        }
    },
    CAYO_TO_SANDY = {
        label = 'Take Plane to Sandy',
        fare = 100000,
        confiscateContraband = false,
        destinationCoords = vector3(1739.17, 3296.04, 40.18),
        sceneLoadCoords = {
            vec3(1575.4, 3175.45, 39.53)
        },
        cutscene = {
            { name = 'hs4_lsa_land_vel', endTime = 8000, customLoadCoords = vector4(1680.81, 3058.13, 39.50, 73) }
        }
    },
    GRAPE_TO_CAYO = {
        label = 'Take Plane to Cayo',
        fare = 10000,
        confiscateContraband = true,
        destinationCoords = vector3(4432.96, -4493.7, 3.2),
        sceneLoadCoords = {
            vector4(2124.45, 4778.69, 40.12, 110)
        },
        cutscene = {
            { name = 'hs4_vel_lsa_isd', playbackList = ScenesToBitwise({ 0 }) }
        }
    },
    CAYO_TO_GRAPE = {
        label = 'Take Plane to Grapeseed',
        fare = 10000,
        confiscateContraband = true,
        destinationCoords = vector3(2118.88, 4788.37, 40.16),
        sceneLoadCoords = {
            vec3(2041.07, 4768.66, 40.06)
        },
        cutscene = {
            { name = 'hs4_lsa_land_vel', endTime = 8000, customLoadCoords = vector4(2120.057129, 4614.237305, 40.670288, 56) }
        }
    }
}

Config.Departures = {
    {
        ped = 's_m_m_pilot_01',
        coords = vector4(-1037.08, -2742.10, 19.17, 346),
        routes = { 'LS_TO_CAYO' }
    },
    {
        ped = 's_m_m_pilot_01',
        coords = vector4(4453.03, -4477.07, 3.3, 206.81),
        routes = { 'CAYO_TO_SANDY', 'CAYO_TO_GRAPE', 'CAYO_TO_LS' }
    },
    {
        ped = 's_m_m_pilot_01',
        coords = vector4(1744.22, 3295.76, 40.11, 201.08),
        routes = { 'SANDY_TO_CAYO' }
    },
    {
        ped = 's_m_m_pilot_01',
        coords = vector4(2118.88, 4788.37, 40.16, 34.65),
        routes = { 'GRAPE_TO_CAYO' }
    }
}
