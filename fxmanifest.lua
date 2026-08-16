fx_version 'cerulean'
game 'gta5'
lua54 'yes'
author 'Alivemonstor'
description 'Cinematic Flight Travel'
version '1.0.0'

dependencies {
    'BridgeLib',
    'ox_lib'
}

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua'
}

client_scripts {
    'client/bridge.lua',
    'client/exploits.lua',
    'client/client.lua'
}

server_scripts {
    'server/bridge.lua',
    'server/server.lua'
}

files {
    'locales/*.json'
}
