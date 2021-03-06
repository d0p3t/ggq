local Config = {}
----------------------------------------------------------------------------------------------------------------------
-- Priority list can be any identifier. (hex steamid, steamid32, ip) Integer = power over other priorities
Config.Priority = {
	["STEAM_0:0:165467450"] = 50,
	["license:255d3bfe7ac05e9eeb74093340b2a10c226d226b"] = 999,
	["STEAM_0:1:515348215"] = 50,
	["STEAM_0:1:115295916"] = 50,
	["license:53fe2e9141d2847714b1fd0cf2f2353ae45641f1"] = 50
}

Config.RequireSteam = false
Config.PriorityOnly = false
Config.CheckBans = true
Config.Whitelist = false
-- easy localization
Config.Language = {
	joining = "Loading weapons...",
	connecting = "Connecting...",
	err = "Error: Couldn't retrieve any of your id's, try restarting.",
	_err = "There was an unknown error",
	pos = "You are %d/%d in queue",
	connectingerr = "Error adding you to connecting list",
	banned = "%s. \n\nWrongfully banned? Appeal on discord.d0p3t.nl",
	steam = "Error: Steam must be running",
	prio = "You must be whitelisted to join this server.",
	illchar = "Illegal characters found in your name! Remove them and try again."
}
-----------------------------------------------------------------------------------------------------------------------

local Queue = {}
Queue.QueueList = {}
Queue.PlayerList = {}
Queue.PlayerCount = 0
Queue.Priority = {}
Queue.Connecting = {}
Queue.ThreadCount = 0
Queue.Loading = {
	"🕐",
	"🕑",
	"🕒",
	"🕓",
	"🕔",
	"🕕",
	"🕖",
	"🕗",
	"🕘",
	"🕙",
	"🕚",
	"🕛"
}
local debug = false
local displayQueue = false
local initHostName = false
local maxPlayers = 32

local tostring = tostring
local tonumber = tonumber
local ipairs = ipairs
local pairs = pairs
local print = print
local string_sub = string.sub
local string_format = string.format
local string_lower = string.lower
local math_abs = math.abs
local math_floor = math.floor
local os_time = os.time
local table_insert = table.insert
local table_remove = table.remove

for k, v in pairs(Config.Priority) do
	Queue.Priority[string_lower(k)] = v
end

local function ordinal_numbers(n)
	local ordinal, digit = {"st", "nd", "rd"}, string.sub(n, -1)
	if
		tonumber(digit) > 0 and tonumber(digit) <= 3 and string.sub(n, -2) ~= 11 and string.sub(n, -2) ~= 12 and
			string.sub(n, -2) ~= 13
	 then
		return n .. ordinal[tonumber(digit)]
	else
		return n .. "th"
	end
end

-- converts hex steamid to SteamID 32
function Queue:HexIdToSteamId(hexId)
	local cid = math_floor(tonumber(string_sub(hexId, 7), 16))
	local steam64 = math_floor(tonumber(string_sub(cid, 2)))
	local a = steam64 % 2 == 0 and 0 or 1
	local b = math_floor(math_abs(6561197960265728 - steam64 - a) / 2)
	local sid = "steam_0:" .. a .. ":" .. (a == 1 and b - 1 or b)
	return sid
end

function Queue:IsSteamRunning(src)
	for k, v in ipairs(GetPlayerIdentifiers(src)) do
		if string.sub(v, 1, 5) == "steam" then
			return true
		end
	end

	return false
end

function Queue:GetIdentifier(src, identifier)
	for k, v in ipairs(GetPlayerIdentifiers(src)) do
		if string.sub(v, 1, string.len(identifier)) == identifier then
			return v
		end
	end

	return nil
end

function Queue:DebugPrint(msg)
	if debug then
		msg = "QUEUE: " .. tostring(msg)
		print(msg)
	end
end

function Queue:IsInQueue(ids, rtnTbl, bySource, connecting)
	for k, v in ipairs(connecting and self.Connecting or self.QueueList) do
		local inQueue = false

		if not bySource then
			for i, j in ipairs(v.ids) do
				if inQueue then
					break
				end

				for q, e in ipairs(ids) do
					if e == j then
						inQueue = true
						break
					end
				end
			end
		else
			inQueue = ids == v.source
		end

		if inQueue then
			if rtnTbl then
				return k, connecting and self.Connecting[k] or self.QueueList[k]
			end

			return true
		end
	end

	return false
end

function Queue:IsPriority(ids)
	for k, v in ipairs(ids) do
		v = string_lower(v)

		if string_sub(v, 1, 5) == "steam" and not self.Priority[v] then
			local steamid = self:HexIdToSteamId(v)
			if self.Priority[steamid] then
				return self.Priority[steamid] ~= nil and self.Priority[steamid] or false
			end
		end

		if self.Priority[v] then
			return self.Priority[v] ~= nil and self.Priority[v] or false
		end
	end
end

function Queue:AddToQueue(ids, connectTime, name, src, deferrals)
	if self:IsInQueue(ids) then
		return
	end

	local tmp = {
		source = src,
		ids = ids,
		name = name,
		firstconnect = connectTime,
		priority = self:IsPriority(ids) or (src == "debug" and math.random(0, 15)),
		timeout = 0,
		deferrals = deferrals
	}

	local _pos = false
	local queueCount = self:GetSize() + 1

	for k, v in ipairs(self.QueueList) do
		if tmp.priority then
			if not v.priority then
				_pos = k
			else
				if tmp.priority > v.priority then
					_pos = k
				end
			end

			if _pos then
				self:DebugPrint(
					string_format("%s[%s] was prioritized and placed %d/%d in queue", tmp.name, ids[1], _pos, queueCount)
				)
				break
			end
		end
	end

	if not _pos then
		_pos = self:GetSize() + 1
		self:DebugPrint(string_format("%s[%s] was placed %d/%d in queue", tmp.name, ids[1], _pos, queueCount))
	end

	table_insert(self.QueueList, _pos, tmp)
end

function Queue:RemoveFromQueue(ids, bySource)
	if self:IsInQueue(ids, false, bySource) then
		local pos, data = self:IsInQueue(ids, true, bySource)
		table_remove(self.QueueList, pos)
	end
end

function Queue:GetSize()
	return #self.QueueList
end

function Queue:ConnectingSize()
	return #self.Connecting
end

function Queue:IsInConnecting(ids, bySource, refresh)
	local inConnecting, tbl = self:IsInQueue(ids, refresh and true or false, bySource and true or false, true)

	if not inConnecting then
		return false
	end

	if refresh and inConnecting and tbl then
		self.Connecting[inConnecting].timeout = 0
	end

	return true
end

function Queue:RemoveFromConnecting(ids, bySource)
	for k, v in ipairs(self.Connecting) do
		local inConnecting = false

		if not bySource then
			for i, j in ipairs(v.ids) do
				if inConnecting then
					break
				end

				for q, e in ipairs(ids) do
					if e == j then
						inConnecting = true
						break
					end
				end
			end
		else
			inConnecting = ids == v.source
		end

		if inConnecting then
			table_remove(self.Connecting, k)
			return true
		end
	end

	return false
end

function Queue:AddToConnecting(ids, ignorePos, autoRemove, done)
	local function removeFromQueue()
		if not autoRemove then
			return
		end

		done(Config.Language.connectingerr)
		self:RemoveFromConnecting(ids)
		self:RemoveFromQueue(ids)
		self:DebugPrint("Player could not be added to the connecting list")
	end

	if self:ConnectingSize() >= 5 then
		removeFromQueue()
		return false
	end
	if ids[1] == "debug" then
		table_insert(
			self.Connecting,
			{source = ids[1], ids = ids, name = ids[1], firstconnect = ids[1], priority = ids[1], timeout = 0}
		)
		return true
	end

	if self:IsInConnecting(ids) then
		self:RemoveFromConnecting(ids)
	end

	local pos, data = self:IsInQueue(ids, true)
	if not ignorePos and (not pos or pos > 1) then
		removeFromQueue()
		return false
	end

	table_insert(self.Connecting, data)
	self:RemoveFromQueue(ids)
	return true
end

function Queue:GetIds(src)
	local ids = GetPlayerIdentifiers(src)
	ids = (ids and ids[1]) and ids or {"ip:" .. GetPlayerEP(src)}
	ids = ids ~= nil and ids or false

	if ids and #ids > 1 then
		for k, v in ipairs(ids) do
			if string.sub(v, 1, 3) == "ip:" then
				table_remove(ids, k)
			end
		end
	end

	return ids
end

function Queue:AddPriority(id, power)
	if not id then
		return false
	end

	if type(id) == "table" then
		for k, v in pairs(id) do
			if k and type(k) == "string" and v and type(v) == "number" then
				self.Priority[k] = v
			else
				self:DebugPrint("Error adding a priority id, invalid data passed")
				return false
			end
		end

		return true
	end

	power = (power and type(power) == "number") and power or 10
	self.Priority[string_lower(id)] = power

	return true
end

function Queue:RemovePriority(id)
	if not id then
		return false
	end
	self.Priority[id] = nil
	return true
end

function Queue:UpdatePosData(src, ids, deferrals)
	local pos, data = self:IsInQueue(ids, true)
	self.QueueList[pos].source = src
	self.QueueList[pos].ids = ids
	self.QueueList[pos].timeout = 0
	self.QueueList[pos].deferrals = deferrals
end

function Queue:NotFull(firstJoin)
	local canJoin = self.PlayerCount + self:ConnectingSize() < maxPlayers and self:ConnectingSize() < 5
	canJoin = firstJoin and (self:GetSize() <= 1 and canJoin) or canJoin
	return canJoin
end

function Queue:SetPos(ids, newPos)
	local pos, data = self:IsInQueue(ids, true)

	table_remove(self.QueueList, pos)
	table_insert(self.QueueList, newPos, data)

	Queue:DebugPrint("Set " .. data.name .. "[" .. data.ids[1] .. "] pos to " .. newPos)
end

-- export
function AddPriority(id, power)
	return Queue:AddPriority(id, power)
end

-- export
function RemovePriority(id)
	return Queue:RemovePriority(id)
end

Citizen.CreateThread(
	function()
		local function playerConnect(name, setKickReason, deferrals)
			maxPlayers = GetConvarInt("sv_maxclients", 32)
			debug = GetConvar("sv_debugqueue", "true") == "true" and true or false
			displayQueue = GetConvar("sv_displayqueue", "true") == "true" and true or false
			initHostName = not initHostName and GetConvar("sv_hostname") or initHostName

			local src = source
			local ids = Queue:GetIds(src)
			local connectTime = os_time()
			local connecting = true

			deferrals.defer()

			Citizen.Wait(0)

			Citizen.CreateThread(
				function()
					while connecting do
						Citizen.Wait(0)
						if not connecting then
							return
						end
						deferrals.update(Config.Language.connecting)
					end
				end
			)

			Citizen.Wait(0)

			local function done(msg)
				connecting = false
				Citizen.Wait(0)
				if not msg then
					deferrals.done()
				else
					deferrals.done(tostring(msg) and tostring(msg) or "")
					CancelEvent()
				end
			end

			local function update(msg)
				connecting = false
				Citizen.Wait(0)
				deferrals.update(tostring(msg) and tostring(msg) or "")
			end

			if not ids then
				-- prevent joining
				done(Config.Language.err)
				CancelEvent()
				Queue:DebugPrint("Dropped " .. name .. ", couldn't retrieve any of their id's")
				return
			end

			local lowerName = string.lower(name)
			local license = Queue:GetIdentifier(src, "license")
			if
				string.match(lowerName, "<[^>]*>") or string.match(lowerName, "34byte") or string.match(lowerName, "ham-mafia") or
					string.match(lowerName, "desudo") or
					string.match(lowerName, "[\\^][1-9]")
			 then
				local endpoint = GetPlayerEndpoint(src)
				done(Config.Language.illchar)
				CancelEvent()
				return
			end

			if Config.RequireSteam and not Queue:IsSteamRunning(src) then
				done(Config.Language.steam)
				CancelEvent()
				return
			end

			if Config.CheckBans then
				local ids = Queue:GetIds(src)
				local lid = Queue:GetIdentifier(src, "license")
				local sid = Queue:GetIdentifier(src, "steam")
				local xid = Queue:GetIdentifier(src, "xbl")
				local liveid = Queue:GetIdentifier(src, "live")
				local did = Queue:GetIdentifier(src, "discord")
				local fid = Queue:GetIdentifier(src, "fivem")
				if sid == nil then
					sid = ""
				end
				if xid == nil then
					xid = ""
				end
				if liveid == nil then
					liveid = ""
				end
				if did == nil then
					did = ""
				end
				if fid == nil then
					fid = ""
				end

				local t = os.date("*t")
				local time = os.date("%Y-%m-%d %H:%M:%S", os.time(t))

				local results =
					exports["ggsql"]:QueryResult(
					"SELECT endDate, reason, licenseId, steamId, xblId, liveId, discordId, fivemId FROM bans WHERE endDate>=@t AND (licenseId=@lid OR steamId=@sid OR xblId=@xid OR liveId=@liveid OR discordId=@did OR fivemId=@fid)",
					{
						t = time,
						lid = lid,
						sid = sid,
						xid = xid,
						liveid = liveid,
						did = did,
						fid = fid
					}
				)
				if results then
					local resultCounter = 1
					local function round2(num, numDecimalPlaces)
						return tonumber(string.format("%." .. (numDecimalPlaces or 0) .. "f", num))
					end
					local banLicense = ""
					local banSteam = ""
					local banXbl = ""
					local banLive = ""
					local banDiscord = ""
					local banFivem = ""
					local banEndDate = 0
					local banReason = ""
					local isBanned = false

					while results[resultCounter] ~= nil do
						isBanned = true

						if banLicense == "" and lid ~= "" then
							if results[resultCounter].licenseId ~= nil then
								banLicense = results[resultCounter].licenseId
							end
						end

						if banSteam == "" and sid ~= "" then
							if results[resultCounter].steamId ~= nil then
								banSteam = results[resultCounter].steamId
							end
						end

						if banXbl == "" and xid ~= "" then
							if results[resultCounter].xblId ~= nil then
								banXbl = results[resultCounter].xblId
							end
						end

						if banLive == "" and liveid ~= "" then
							if results[resultCounter].liveId ~= nil then
								banLive = results[resultCounter].liveId
							end
						end

						if banDiscord == "" and did ~= "" then
							if results[resultCounter].discordId ~= nil then
								banDiscord = results[resultCounter].discordId
							end
						end

						if banFivem == "" and fid ~= "" then
							if results[resultCounter].fivemId ~= nil then
								banFivem = results[resultCounter].fivemId
							end
						end

						banEndDate = results[resultCounter].endDate
						banReason = results[resultCounter].reason

						resultCounter = resultCounter + 1
					end

					if isBanned then
						local differentIdentifierDetected = false

						if
							banLicense ~= lid or banSteam ~= sid or banXbl ~= xid or banLive ~= liveid or banDiscord ~= did or
								banFivem ~= fid
						 then
							differentIdentifierDetected = true
						end

						local didUpdateIdentifiers = "No"

						if differentIdentifierDetected == true then
							local BanInsertQuery =
								"INSERT INTO bans (`licenseId`, `steamId`, `xblId`, `liveId`, `discordId`, `fivemId`, `endDate`, `reason`) VALUES (@lid, NULLIF(@sid, ''), NULLIF(@xid, ''), NULLIF(@liveid, ''), NULLIF(@did, ''), NULLIF(@fid, ''), @ed, @r)"

							local edate = os.date("%Y-%m-%d %H:%M:%S", round2(banEndDate / 1000))
							local updateResult =
								exports["ggsql"]:Query(
								BanInsertQuery,
								{
									lid = lid,
									sid = sid,
									xid = xid,
									liveid = liveid,
									did = did,
									fid = fid,
									ed = edate,
									r = banReason
								}
							)

							if updateResult == 1 then
								didUpdateIdentifiers = "Yes"
							end
						end

						done(
							string.format(
								Config.Language.banned,
								"Player: " ..
									lid .. "\nBanned until: " .. os.date("%c GMT", round2(banEndDate / 1000)) .. "\nReason: " .. banReason .. ""
							)
						)
						Queue:RemoveFromQueue(ids)
						Queue:RemoveFromConnecting(ids)
						CancelEvent()
						return
					end
				end
			end

			local whitelisted

			if Config.Whitelist then -- Whitelist check
				local whitelisted = true

				if not whitelisted then
					done(Config.Language.prio)
					Queue:RemoveFromQueue(ids)
					Queue:RemoveFromConnecting(ids)
					CancelEvent()
					return
				end
			end

			local reason = "You were kicked from joining the queue"

			local function setReason(msg)
				reason = tostring(msg)
			end

			TriggerEvent("queue:playerJoinQueue", src, setReason)

			if WasEventCanceled() then
				done(reason)

				Queue:RemoveFromQueue(ids)
				Queue:RemoveFromConnecting(ids)

				CancelEvent()
				return
			end

			if Config.PriorityOnly and not Queue:IsPriority(ids) then
				done(Config.Language.prio)
				return
			end

			local rejoined = false

			if Queue:IsInQueue(ids) then
				rejoined = true
				Queue:UpdatePosData(src, ids, deferrals)
				Queue:DebugPrint(string_format("%s[%s] has rejoined queue after cancelling", name, ids[1]))
			else
				Queue:AddToQueue(ids, connectTime, name, src, deferrals)
			end

			if Queue:IsInConnecting(ids, false, true) then
				Queue:RemoveFromConnecting(ids)

				if Queue:NotFull() then
					local added = Queue:AddToConnecting(ids, true, true, done)
					if not added then
						CancelEvent()
						return
					end

					done()

					return
				else
					Queue:AddToQueue(ids, connectTime, name, src, deferrals)
					Queue:SetPos(ids, 1)
				end
			end

			local pos, data = Queue:IsInQueue(ids, true)

			if not pos or not data then
				done(Config.Language._err .. "[3]")

				RemoveFromQueue(ids)
				RemoveFromConnecting(ids)

				CancelEvent()
				return
			end

			if Queue:NotFull(true) then
				-- let them in the server
				local added = Queue:AddToConnecting(ids, true, true, done)
				if not added then
					CancelEvent()
					return
				end

				done()
				Queue:DebugPrint(name .. "[" .. ids[1] .. "] is loading into the server")

				return
			end

			update(string_format(Config.Language.pos, pos, Queue:GetSize()))

			Citizen.CreateThread(
				function()
					if rejoined then
						return
					end

					Queue.ThreadCount = Queue.ThreadCount + 1

					local emoji = Queue.Loading[1]
					local emojiCount = 0

					while true do
						Citizen.Wait(50)

						emojiCount = emojiCount + 1

						if emojiCount > #Queue.Loading then
							emojiCount = 1
						end
						emoji = Queue.Loading[emojiCount]

						local pos, data = Queue:IsInQueue(ids, true)

						-- will return false if not in queue; timed out?
						if not pos or not data then
							if data and data.deferrals then
								Citizen.Wait(0)
								data.deferrals.done(Config.Language._err)
							end
							CancelEvent()
							Queue:RemoveFromQueue(ids)
							Queue:RemoveFromConnecting(ids)
							Queue.ThreadCount = Queue.ThreadCount - 1
							return
						end

						if pos <= 1 and Queue:NotFull() then
							-- let them in the server
							local added = Queue:AddToConnecting(ids)
							Citizen.Wait(5)
							data.deferrals.update(Config.Language.joining)
							Citizen.Wait(0)

							if not added then
								data.deferrals.done(Config.Language.connectingerr)
								CancelEvent()
								Queue.ThreadCount = Queue.ThreadCount - 1
								return
							end

							data.deferrals.done()

							Queue:RemoveFromQueue(ids)
							Queue.ThreadCount = Queue.ThreadCount - 1
							Queue:DebugPrint(name .. "[" .. ids[1] .. "] is loading into the server")

							return
						end

						Citizen.Wait(0)
						-- send status update
						local msg = string_format(Config.Language.pos .. " %s Check discord.d0p3t.nl to join Priority List", pos, Queue:GetSize(), emoji)
						data.deferrals.update(msg)
					end
				end
			)
		end

		AddEventHandler("playerConnecting", playerConnect)

		local function checkTimeOuts()
			local i = 1

			while i <= Queue:GetSize() do
				local data = Queue.QueueList[i]
				local lastMsg = GetPlayerLastMsg(data.source)

				if lastMsg >= 30000 then
					data.timeout = data.timeout + 1
				else
					data.timeout = 0
				end

				-- check just incase there is invalid data
				if not data.ids or not data.name or not data.firstconnect or data.priority == nil or not data.source then
					data.deferrals.done(Config.Language._err .. "[1]")
					table_remove(Queue.QueueList, i)
					Queue:DebugPrint(
						tostring(data.name) .. "[" .. tostring(data.ids[1]) .. "] was removed from the queue because it had invalid data"
					)
				elseif (data.timeout >= 120) and data.source ~= "debug" and os_time() - data.firstconnect > 5 then
					-- remove by source incase they rejoined and were duped in the queue somehow
					data.deferrals.done(Config.Language._err .. "[2]")
					Queue:RemoveFromQueue(data.source, true)
					Queue:RemoveFromConnecting(data.source, true)
					Queue:DebugPrint(data.name .. "[" .. data.ids[1] .. "] was removed from the queue because they timed out")
				else
					i = i + 1
				end
			end

			i = 1

			while i <= Queue:ConnectingSize() do
				local data = Queue.Connecting[i]

				local lastMsg = GetPlayerLastMsg(data.source)

				data.timeout = data.timeout + 1

				if
					((data.timeout >= 300 and lastMsg >= 35000) or data.timeout >= 340) and data.source ~= "debug" and
						os_time() - data.firstconnect > 5
				 then
					Queue:RemoveFromQueue(data.source, true)
					Queue:RemoveFromConnecting(data.source, true)
					Queue:DebugPrint(
						data.name .. "[" .. data.ids[1] .. "] was removed from the connecting queue because they timed out"
					)
				else
					i = i + 1
				end
			end

			local qCount = Queue:GetSize()

			-- show queue count in server name
			if displayQueue and initHostName then
				TriggerEvent("prometheus:queueUpdate", qCount)
				SetConvar("sv_hostname", (qCount > 0 and "[" .. tostring(qCount) .. "] " or "") .. initHostName)
			end

			SetTimeout(1000, checkTimeOuts)
		end

		checkTimeOuts()
	end
)

local function playerActivated()
	local src = source
	local ids = Queue:GetIds(src)

	if not Queue.PlayerList[src] then
		Queue.PlayerCount = Queue.PlayerCount + 1
		Queue.PlayerList[src] = true
		Queue:RemoveFromQueue(ids)
		Queue:RemoveFromConnecting(ids)
	end
end

RegisterServerEvent("Queue:playerActivated")
AddEventHandler("Queue:playerActivated", playerActivated)

local function playerDropped()
	local src = source
	local ids = Queue:GetIds(src)

	if Queue.PlayerList[src] then
		Queue.PlayerCount = Queue.PlayerCount - 1
		Queue.PlayerList[src] = nil
		Queue:RemoveFromQueue(ids)
		Queue:RemoveFromConnecting(ids)
	end
end

AddEventHandler("playerDropped", playerDropped)

Citizen.CreateThread(
	function()
		while true do
			Citizen.Wait(0)
			if exports and exports.connectqueue then
				TriggerEvent("queue:onReady")
				return
			end
		end
	end
)

-- debugging / testing commands
-- local testAdds = 0

-- AddEventHandler("rconCommand", function(command, args)
-- 	-- adds a fake player to the queue for debugging purposes, this will freeze the queue
-- 	if command == "addq" then
-- 		print("==ADDED FAKE QUEUE==")
-- 		Queue:AddToQueue({"steam:110000103fd1bb1"..testAdds}, os_time(), "Fake Player", "debug")
-- 		testAdds = testAdds + 1
-- 		CancelEvent()

-- 	-- removes targeted id from the queue
-- 	elseif command == "removeq" then
-- 		if not args[1] then return end
-- 		print("REMOVED " .. Queue.QueueList[tonumber(args[1])].name .. " FROM THE QUEUE")
-- 		table_remove(Queue.QueueList, args[1])
-- 		CancelEvent()

-- 	-- print the current queue list
-- 	elseif command == "printq" then
-- 		print("==CURRENT QUEUE LIST==")
-- 		for k,v in ipairs(Queue.QueueList) do
-- 			print(k .. ": [src: " .. v.source .. "] " .. v.name .. "[" .. v.ids[1] .. "] | Priority: " .. (tostring(v.priority and true or false)) .. " | Last Msg: " .. (v.source ~= "debug" and GetPlayerLastMsg(v.source) or "debug") .. " | Timeout: " .. v.timeout)
-- 		end
-- 		CancelEvent()

-- 	-- adds a fake player to the connecting list
-- 	elseif command == "addc" then
-- 		print("==ADDED FAKE CONNECTING QUEUE==")
-- 		Queue:AddToConnecting({"debug"})
-- 		CancelEvent()

-- 	-- removes a player from the connecting list
-- 	elseif command == "removec" then
-- 		print("==REMOVED FAKE CONNECTING QUEUE==")
-- 		if not args[1] then return end
-- 		table_remove(Queue.Connecting, args[1])
-- 		CancelEvent()

-- 	-- prints a list of players that are connecting
-- 	elseif command == "printc" then
-- 		print("==CURRENT CONNECTING LIST==")
-- 		for k,v in ipairs(Queue.Connecting) do
-- 			print(k .. ": [src: " .. v.source .. "] " .. v.name .. "[" .. v.ids[1] .. "] | Priority: " .. (tostring(v.priority and true or false)) .. " | Last Msg: " .. (v.source ~= "debug" and GetPlayerLastMsg(v.source) or "debug") .. " | Timeout: " .. v.timeout)
-- 		end
-- 		CancelEvent()

-- 	-- prints a list of activated players
-- 	elseif command == "printl" then
-- 		for k,v in pairs(Queue.PlayerList) do
-- 			print(k .. ": " .. tostring(v))
-- 		end
-- 		CancelEvent()

-- 	-- prints a list of priority id's
-- 	elseif command == "printp" then
-- 		print("==CURRENT PRIORITY LIST==")
-- 		for k,v in pairs(Queue.Priority) do
-- 			print(k .. ": " .. tostring(v))
-- 		end
-- 		CancelEvent()

-- 	-- prints the current player count
-- 	elseif command == "printcount" then
-- 		print("Player Count: " .. Queue.PlayerCount)
-- 		CancelEvent()

-- 	elseif command == "printt" then
-- 		print("Thread Count: " .. Queue.ThreadCount)
-- 		CancelEvent()
-- 	end
-- end)

-- prevent duplicating queue count in server name
AddEventHandler(
	"onResourceStop",
	function(resource)
		if displayQueue and resource == GetCurrentResourceName() then
			SetConvar("sv_hostname", initHostName)
		end
	end
)

RegisterCommand("qp", function(source, args,rawCommand)
	if source == 0 then
		if(args[1] ~= nil) then
			Queue.Priority[string_lower(args[1])] = 50
			print('' .. args[1] .. ' added to priority list')
		end
	end
end, true)

RegisterCommand("pq", function(source, args,rawCommand)
	if source == 0 then
		for k, v in pairs(Queue.Priority) do
			print(k,v)
		end
	end
end, true)