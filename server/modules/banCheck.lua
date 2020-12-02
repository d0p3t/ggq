local string_sub = string.sub
local get_player_name = GetPlayerName
local colorCodes = {
  "^1",
  "^2",
  "^3",
  "^4",
  "^5",
  "^6",
  "^7",
  "^8",
  "^9",
  "^*",
  "~r~",
  "~g~",
  "~b~",
  "~y~",
  "~p~",
  "~c~",
  "~m~",
  "~u~",
  "~o~",
  "~h~"
}

local illegalNames = {
  "34ByTe Community",
  "AlphaV ~ 5391",
  "Baran#8992",
  "Brutan",
  "Desudo",
  "EulenCheats",
  "Fallen#0811",
  "HAMMAFIA",
  "HamMafia",
  "HamHaxia",
  "Ham Mafia",
  "WATERMALONE",
  "hammafia.com",
  "KoGuSzEk#3251",
  "Lynx",
  "lynxmenu.com",
  "MARVIN menu",
  "Melon#1379",
  "Soviet Bear",
  "Xanax#0134",
  "iLostName#7138",
  "vjuton.pl",
  "renalua.com",
  "TeamSpeak",
  "brutan",
  "Baran",
  "Anti-Lynx",
  "ribbon_1",
  "яιввση",
  "noyaas",
  "d0pamine",
  "Dopamine",
  "Plane#000",
  "SKAZAMENU",
  "aries",
  "skaza",
  "OnionExecutor",
  "BAGGY menu",
  "Baggy menu",
  "Baggy Menu",
  "^0AlphaV",
  "TITO MODZ",
  "Sokin_Menu",
  "v500",
  "kogusz",
  "falloutmenu",
  "RedEngine"
}

Citizen.CreateThread(
  function()
    while not Queue.IsReady() do
      Wait(0)
    end
    Queue.OnJoin(
      function(s, allow)
        local src = s

        local ids = Queue.Exports:GetIds(src)

        if ids == nil or type(ids) == "boolean" then
          allow("Could not get your identifiers. Try again please.")
          return
        end

        local name = get_player_name(src)
        if name ~= nil and name ~= "**Invalid**" then
          name = string.lower(name)
          if string.find(name, "<html>", 1, true) then
            allow("\n\nReason: Player name containing HTML code is not allowed. \nAction: Change your name and reconnect.")
            return
          end
          for _, pattern in ipairs(colorCodes) do
            if string.find(name, pattern, 1, true) then
              allow(
                "\n\nReason: Colored name is not allowed. \nAction: Remove color pattern(s) from name and reconnect.\nPattern: " .. pattern
              )
              return
            end
          end

          for _, pattern in ipairs(illegalNames) do
            if string.find(name, string.lower(pattern), 1, true) then
              allow(
                "\n\nReason: Player name contains illegal characters. \nAction: Change your name in the FiveM Settings or Steam.\nPatteron: " ..
                  pattern
              )
              return
            end
          end
        end

        local licenseId = ""
        local steamId = ""
        local xblId = ""
        local liveId = ""
        local discordId = ""
        local fivemId = ""
        local lUserId = ""
        local sUserId = ""
        local xUserId = ""
        local liveUserId = ""
        local dUserId = ""
        local fUserId = ""

        for _, id in ipairs(ids) do
          if string_sub(id, 1, 8) == "license:" then
            licenseId = id
            lUserId = id:gsub(".*:", "")
          elseif string_sub(id, 1, 6) == "steam:" then
            steamId = id
            sUserId = id:gsub(".*:", "")
          elseif string_sub(id, 1, 4) == "xbl:" then
            xblId = id
            xUserId = id:gsub(".*:", "")
          elseif string_sub(id, 1, 5) == "live:" then
            liveId = id
            liveUserId = id:gsub(".*:", "")
          elseif string_sub(id, 1, 8) == "discord:" then
            discordId = id
            dUserId = id:gsub(".*:", "")
          elseif string_sub(id, 1, 6) == "fivem:" then
            fivemId = id
            fUserId = id:gsub(".*:", "")
          end
        end

        exports["ggsql"]:QueryAsync(
          "UPDATE users SET fivemId=@fid WHERE licenseId=@lid OR steamId=@sid OR xblId=@xid OR liveId=@liveid OR discordId=@did",
          {
            lid = lUserId,
            sid = sUserId,
            xid = xUserId,
            liveid = liveUserId,
            did = dUserId,
            fid = fUserId
          },
          function(updateResult)
          end
        )

        local t = os.date("*t")
        local time = os.date("%Y-%m-%d %H:%M:%S", os.time(t))
        local results =
          exports["ggsql"]:QueryResult(
          "SELECT endDate,reason,licenseId,steamId,xblId,liveId,discordId,fivemId FROM bans WHERE endDate>=@t AND (licenseId=@lid OR steamId=@sid OR xblId=@xid OR liveId=@liveid OR discordId=@did OR fivemId=@fid)",
          {
            t = time,
            lid = licenseId,
            sid = steamId,
            xid = xblId,
            liveid = liveId,
            did = discordId,
            fid = fivemId
          }
        )

        if not results or #results == 0 then
          allow()
        else
          local bannedIdentifiers = {}
          local banInsertQuery =
            "INSERT INTO bans (`licenseId`, `steamId`, `xblId`, `liveId`, `discordId`, `fivemId`, `endDate`, `reason`) VALUES (@lid, NULLIF(@sid, ''), NULLIF(@xid, ''), NULLIF(@liveid, ''), NULLIF(@did, ''), NULLIF(@fid, ''), @ed, @r)"
          local function round2(num, numDecimalPlaces)
            return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
          end

          local updated = false
          local endDate = os.date("%c GMT", round2(results[1].endDate / 1000))
          for _, result in ipairs(results) do
            if result.licenseId ~= nil and result.licenseId ~= licenseId and not bannedIdentifiers[result.licenseId] then
              bannedIdentifiers[result.licenseId] = true
            end
            if result.steamId ~= nil and result.steamId ~= steamId and not bannedIdentifiers[result.steamId] then
              bannedIdentifiers[result.steamId] = true
            end
            if result.xblId ~= nil and result.xblId ~= xblId and not bannedIdentifiers[result.xblId] then
              bannedIdentifiers[result.xblId] = true
            end
            if result.liveId ~= nil and result.liveId ~= liveId and not bannedIdentifiers[result.liveId] then
              bannedIdentifiers[result.liveId] = true
            end
            if result.discordId ~= nil and result.discordId ~= discordId and not bannedIdentifiers[result.discordId] then
              bannedIdentifiers[result.discordId] = true
            end
            if result.fivemId ~= nil and result.fivemId ~= fivemId and not bannedIdentifiers[result.fivemId] then
              bannedIdentifiers[result.fivemId] = true
            end
          end
          for _, result in ipairs(results) do
            if not updated then
              local newLicenseId = licenseId
              if result.licenseId ~= nil and result.licenseId ~= licenseId and not bannedIdentifiers[result.licenseId] then
                newLicenseId = result.licenseId
              end

              local newSteamId = steamId
              if result.steamId ~= nil and result.steamId ~= steamId and not bannedIdentifiers[result.steamId] then
                newSteamId = result.steamId
              end

              local newXblId = xblId
              if result.xblId ~= nil and result.xblId ~= xblId and not bannedIdentifiers[result.xblId] then
                newXblId = result.xblId
              end

              local newLiveId = liveId
              if result.liveId ~= nil and result.liveId ~= liveId and not bannedIdentifiers[result.liveId] then
                newLiveId = result.liveId
              end

              local newDiscordId = discordId
              if result.discordId ~= nil and result.discordId ~= discordId and not bannedIdentifiers[result.discordId] then
                newDiscordId = result.discordId
              end

              local newFivemId = fivemId
              if result.fivemId ~= nil and result.fivemId ~= fivemId and not bannedIdentifiers[result.fivemId] then
                newFivemId = result.fivemId
              end

              if
                newLicenseId ~= licenseId or newSteamId ~= steamId or newXblId ~= xblId or newLiveId ~= liveId or newDiscordId ~= discordId or
                  newFivemId ~= fivemId
               then
                updated = true
                local edate = os.date("%Y-%m-%d %H:%M:%S", round2(result.endDate / 1000))
                local reason = result.reason
                exports["ggsql"]:QueryAsync(
                  banInsertQuery,
                  {
                    lid = newLicenseId,
                    sid = newSteamId,
                    xid = newXblId,
                    liveid = newLiveId,
                    did = newDiscordId,
                    fid = newFivemId,
                    ed = edate,
                    r = reason
                  },
                  function(returnResult)
                    if returnResult > 0 then
                      Utils.DebugPrint("Inserted new ban for player " .. newLicenseId .. " since they changed an identifier")
                    end
                  end
                )
              end
            end
          end

          allow(
            "\n\nYOU ARE BANNED\n\nID: " ..
              licenseId ..
                "\nUntil: " .. endDate .. "\nReason: " .. results[1].reason .. "\n\nWrongfully banned? Appeal at appeal.gungame.store"
          )
        end
      end
    )
  end
)
