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
            Sql:QueryResult(
            "SELECT id FROM users WHERE licenseId=@lid OR steamId=@lid OR discordId=@lid OR fivemId=@lid",
            {
                lid = identifier
            }
        )

        local userId = 0
        local keepman = manualIdentifier -- always keep for adding

        if results[1] then
            local user = results[1]
            userId = tonumber(user.id)
            manualIdentifier = ""
        end

        Sql:QueryAsync(
            "REPLACE INTO queue (userId,donatorLevel,priority,manualIdentifier) VALUES (NULLIF(@uid, 0),@dl, @p,NULLIF(@mid,''))",
            {
                uid = userId,
                dl = donationLevel,
                p = priority,
                mid = manualIdentifier
            },
            function(result)
                if result == 1 then
                  Common:Log("Tebex Commands", "Successfully added " .. manualIdentifier .. " to queue.")
                    Utils.DebugPrint("Successfully added player into queue DB")
                elseif result > 1 then
                    Common:Log("Tebex Commands", "Updated " .. manualIdentifier .. " to queue.")
                    Utils.DebugPrint("Updated player queue priority in DB")
                end
                Queue.AddPriority(keepman, priority)
            end
        )
    end,
    true
)

RegisterCommand(
    "removeprio",
    function(source, args, raw)
        if source ~= 0 then
            return
        end

        if #args ~= 1 then
            Utils.DebugPrint("Must only specify identifier to remove")
            return
        end

        local identifier = args[1]

        Queue.RemovePriority(identifier)

        Sql:QueryAsync(
            "DELETE FROM queue WHERE manualIdentifier=@mid",
            {
                mid = tostring(identifier)
            },
            function(result)
                if result < 1 then
                -- find by userid. use one sql transaction with DECLARE and shizzle
                end
            end
        )
    end,
    true
)

RegisterCommand(
    "sponsorrewards",
    function(source, args, raw)
        if source ~= 0 then
            return
        end

        if #args ~= 3 then
            Utils.DebugPrint("Must specify [identifier] [xp] [money]")
            return
        end

        local manualIdentifier = tostring(args[1])
        local addXP = tonumber(args[2]) or 0
        local addMoney = tonumber(args[3]) or 0

        local identifier = manualIdentifier:gsub(".*:", "")
        local results =
            Sql:QueryAsync(
            "UPDATE users SET xp=xp+@addXp, money=money+@addMoney, donator=1 WHERE licenseId=@lid OR steamId=@lid OR discordId=@lid OR fivemId=@lid LIMIT 1;",
            {
                addXp = addXp,
                addMoney = addMoney,
                lid = identifier
            },
            function(updateResult)
                if updateResult == 1 then
                    Utils.DebugPrint(
                        "Successfully added " ..
                            tostring(addXP) .. "XP and $" .. tostring(addMoney) .. " to user " .. identifier
                    )
                    Common:Log(
                        "Tebex Commands",
                        "Successfully added " ..
                            tostring(addXP) .. "XP and $" .. tostring(addMoney) .. " to user " .. identifier
                    )
                else
                    Common:Log("Tebex Commands", "Something went wrong updating " .. identifier)
                    Utils.DebugPrint("Something went wrong updating " .. identifier)
                end
            end
        )
    end,
    true
)

RegisterCommand(
    "unban",
    function(source, args, raw)
        if source ~= 0 then
            return
        end

        if #args ~= 1 then
            Utils.DebugPrint("Gave more than 1 argument.")
            return
        end

        local identifier = tostring(args[1])
        Sql:Queryasync(
            "UPDATE bans SET endDate=now() WHERE fivemId=@identifier OR discordId=@identifier OR steamId=@identifier;",
            {
                identifier = identifier
            },
            function(updateResult)
                if updateResult > 0 then
                    Common:Log("Tebex Commands", "Removed bans of " .. identifier)
                    Utils.DebugPrint("Updated ban(s) of " .. identifier)
                else
                    Common:Log("Tebex Commands", "COuld not find any bans belonging to " .. identifier)
                    Utils.DebugPrint("Could not find any bans belonging to " .. identifier)
                end
            end
        )
    end,
    true
)

RegisterCommand(
    "addtempprio",
    function(source, args, raw)
        if source ~= 0 or #args ~= 3 then
            return
        end

        local identifier = tostring(args[1])
        local power = tonumber(args[2])
        local seconds = tonumber(args[3]) * 3600

        Queue.AddPriority(identifier, power, seconds)

        Utils.DebugPrint("Added " .. identifier .. " to temp priority for " .. tostring(seconds / 3600) .. " hours.")
    end,
    true
)
