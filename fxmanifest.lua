fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'mz_warns'
author 'Mazus'
description 'Advertencias administrativas persistentes da framework MZ'
version '1.0.0'

shared_script 'config.lua'

server_scripts {
  '@oxmysql/lib/MySQL.lua',
  'server/db.lua',
  'server/api.lua',
  'server/commands.lua',
  'server/main.lua'
}

client_scripts {
  'client/main.lua'
}

dependencies {
  'oxmysql',
  'mz_core'
}
