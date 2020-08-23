RegisterCommand(
  "addprio",
  function(source, args, raw)
    if source ~= 0 then
      return
    end

    if #args ~= 2 then
      Utils.DebugPrint("Arguments must be [identifier] [donationLevel]")
      return
    end

    local manualIdentifier = tostring(args[1])

    local donationLevel = tonumber(args[2])

    if donationLevel > 3 then
      donationLevel = 3
    end

    local priority = 50

    if donationLevel == 2 then
      priority = 51
    elseif donationLevel == 3 then
      priority = 52
    end

    local identifier = manualIdentifier:gsub(".*:", "")
    local results =
      exports["ggsql"]:QueryResult(
      "SELECT id FROM users WHERE licenseId=@lid OR steamId=@lid OR discordId=@lid OR fivemId=@lid",
      {
        lid = identifier
      }
    )

    local userId = 0

    if results[1] then
      local user = results[1]
      userId = tonumber(user.id)
      manualIdentifier = ""
    end

    exports["ggsql"]:QueryAsync(
      "REPLACE INTO queue (userId,donatorLevel,priority,manualIdentifier) VALUES (NULLIF(@uid, 0),@dl, @p,NULLIF(@mid,''))",
      {
        uid = userId,
        dl = donationLevel,
        p = priority,
        mid = manualIdentifier
      },
      function(result)
        if result == 1 then
          Utils.DebugPrint("Successfully added player into queue DB")
        elseif result > 1 then
          Utils.DebugPrint("Updated player queue priority in DB")
        end
      end
    )

    Queue.AddPriority(manualIdentifier, priority)
  end,
  true
)

RegisterCommand('removeprio', function(source,args,raw)
  if source ~= 0 then return end

  if #args ~= 1 then
    Utils.DebugPrint('Must only specify identifier to remove')
    return
  end

  local identifier = args[1]

  Queue.RemovePriority(identifier)

  exports["ggsql"]:QueryAsync("DELETE FROM queue WHERE manualIdentifier=@mid", {
    mid = tostring(identifier)
  }, function(result)
    if result < 1 then
      -- find by userid. use one sql transaction with DECLARE and shizzle
    end
  end)
end, true)

RegisterCommand("sponsorrewards", function(source, args,raw)
  if source ~= 0 then return end

  if #args ~= 3 then
    Utils.DebugPrint("Must specify [identifier] [xp] [money]")
    return
  end

  local manualIdentifier = tostring(args[1])
  local addXP = tonumber(args[2])
  local addMoney = tonumber(args[3])

  local identifier = manualIdentifier:gsub(".*:", "")
  local results =
    exports["ggsql"]:QueryResult(
    "SELECT id, xp, money FROM users WHERE licenseId=@lid OR steamId=@lid OR discordId=@lid OR fivemId=@lid",
    {
      lid = identifier
    }
  )  

  if not results[1] then
    Utils.DebugPrint("Could not find user with identifier: " .. manualIdentifier)
    return
  end

  local user = results[1]
  exports["ggsql"]:QueryAsync("UPDATE users SET xp=@xp, money=@money, donator=1 WHERE id=@id", {
    xp = user.xp + addXP,
    money = user.money + addMoney,
    id = user.id
  }, function(updateResult)
    if updateResult == 1 then
      Utils.DebugPrint("Successfully added " .. tostring(addXP) .. "XP and $" .. tostring(addMoney) .. " to user " .. tostring(user.id))
    else
      Utils.DebugPrint("Something went wrong updating " .. tostring(user.id))
    end   
  end)
end,true)