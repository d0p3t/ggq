fx_version "cerulean"
game "gta5"

dependency "queue"
dependency "ggsql"

server_scripts {
  "server/lib/utils.lua"
}

server_scripts {
  "@queue/queue.lua",
  "server/modules/*.lua"
}
