Utils = {}

local debug = true

function Utils.DebugPrint(msg)
  if not debug then
    return
  end
  print("^3GGQ: ^0" .. tostring(msg) .. "^7")
end
