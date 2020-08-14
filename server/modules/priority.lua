local queueReady = false

Queue.OnReady(
  function()
    queueready = true -- Let's the resource know that the queue is ready.
  end
)

Citizen.CreateThread(
  function()
    Queue.OnReady(
      function()
        while not Queue.IsReady() do
          Wait(0)
        end

        while not exports["ggsql"] do
          Wait(0)
        end

        Utils.DebugPrint("Connectqueue and GGSql are ready!")

        local time = os.date("%Y-%m-%d %H:%M:%S", os.time(t))
        local results =
          exports["ggsql"]:QueryResult(
          "SELECT userId, priority, donatorLevel, manualIdentifier FROM queue WHERE expirationDate>=@t",
          {
            t = time
          }
        )

        if not results or #results == 0 then
          Utils.DebugPrint("Nobody with active queue priority.")
        else
          local manualIdentifiers = {}
          local hasManualPriorities = false
          local grabAdditionalUsers = {}
          local hasGrabAdditionalUsers = false
          for _, result in ipairs(results) do
            if not result.userId and result.manualIdentifier then
              manualIdentifiers[result.manualIdentifier] = result.priority
              hasManualPriorities = true
            else
              if result.userId then
                grabAdditionalUsers[result.userId] = result.priority
                hasGrabAdditionalUsers = true
              end
            end
          end

          if hasManualPriorities then
            Queue.AddPriority(manualIdentifiers)
          end

          if hasGrabAdditionalUsers then
            local orString = ""
            local firstUser = true
            for id, _ in pairs(grabAdditionalUsers) do
              if firstUser then
                orString = "id=" .. tostring(id)
                firstUser = false
              else
                orString = orString .. " OR id=" .. tostring(id) .. ""
              end
            end

            local additionalIds = exports["ggsql"]:QueryResult("SELECT id, licenseId FROM users WHERE " .. tostring(orString))
            if additionalIds then
              local additionalIdentifiers = {}
              for _, additionalId in ipairs(additionalIds) do
                additionalIdentifiers["license:" .. additionalId.licenseId] = grabAdditionalUsers[additionalId.id]
                Utils.DebugPrint(
                  "Added license:" .. additionalId.licenseId .. " with priority " .. grabAdditionalUsers[additionalId.id] .. ""
                )
              end

              Queue.AddPriority(additionalIdentifiers)
            end
          end
        end
      end
    )
  end
)