fx_version 'cerulean'
game 'gta5'

author 'JleeGaming'
description 'Christmas lootable trees using qb-target and qb-inventory (QBCore)'
version '1.0.0'

shared_script 'config.lua'

server_script 'server.lua'
client_script 'client.lua'

-- dependencies
dependency 'qb-core'
-- optional: require qb-target and qb-inventory to be installed on the server

provides { 'jlee_xmas' }
