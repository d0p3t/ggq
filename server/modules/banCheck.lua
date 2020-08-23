local string_sub = string.sub
Citizen.CreateThread(
  function()
    while not Queue.IsReady() do
      Wait(0)
    end
    Queue.OnJoin(
      function(s, allow)
        local src = s
        local ids = Queue.Exports:GetIds(src)
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
            "Player: " ..
              licenseId .. "\nBanned until: " .. endDate .. "\nReason: " .. results[1].reason .. "\n\nBan Appeal at discord.gungame.store"
          )
        end
      end
    )
  end
)
