fx_version "adamant"
game "gta5"

dependency "connectqueue"
dependency "ggsql"

server_scripts {
  "server/lib/utils.lua"
}

server_scripts {
  "@connectqueue/connectqueue.lua",
  "server/modules/*.lua"
}
