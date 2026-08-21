local player_GetAll = player.GetAll
zc.modes = zc.modes or {}

util.AddNetworkString("ZC_FadeScreen")

function zc.AddFade()
	net.Start("ZC_FadeScreen")
	net.Broadcast()
end

local forcemodeconvar = CreateConVar("zc_forcemode", "random", nil, "Set force mode (set to 'random' to disable)")
forcemodeconvar:SetString("random")

local CHANGELEVEL_TRIGGER_CLASS = "trigger_changelevel"
local CHANGELEVEL_TRIGGER_REFRESH_INTERVAL = 5
local cachedChangelevelTrigger
local cachedChangelevelTriggerExists = false
local nextChangelevelTriggerRefresh = 0

local function RefreshChangelevelTrigger(ignoreEnt)
	local found
	for _, ent in ipairs(ents.FindByClass(CHANGELEVEL_TRIGGER_CLASS)) do
		if ent != ignoreEnt and IsValid(ent) then
			found = ent
			break
		end
	end

	cachedChangelevelTrigger = found
	cachedChangelevelTriggerExists = IsValid(found)
	nextChangelevelTriggerRefresh = CurTime() + CHANGELEVEL_TRIGGER_REFRESH_INTERVAL
	return cachedChangelevelTriggerExists
end

local function HasChangelevelTrigger()
	if cachedChangelevelTriggerExists and IsValid(cachedChangelevelTrigger) then return true end

	-- EntityRemoved normally keeps this exact, while the bounded refresh also
	-- covers entities created or removed by systems that bypass the usual hooks.
	if cachedChangelevelTriggerExists then
		cachedChangelevelTrigger = nil
		cachedChangelevelTriggerExists = false
		nextChangelevelTriggerRefresh = 0
	end

	if nextChangelevelTriggerRefresh <= CurTime() then
		return RefreshChangelevelTrigger()
	end

	return false
end

hook.Add("InitPostEntity", "ZC_CacheChangelevelTrigger", function()
	RefreshChangelevelTrigger()
end)
hook.Add("PostCleanupMap", "ZC_CacheChangelevelTrigger", function()
	RefreshChangelevelTrigger()
end)
hook.Add("OnEntityCreated", "ZC_CacheDynamicChangelevelTrigger", function(ent)
	if ent:GetClass() != CHANGELEVEL_TRIGGER_CLASS then return end

	cachedChangelevelTrigger = ent
	cachedChangelevelTriggerExists = true
	nextChangelevelTriggerRefresh = CurTime() + CHANGELEVEL_TRIGGER_REFRESH_INTERVAL

	-- Some scripted entities are announced before their initialization finishes.
	-- Reconfirm on the next tick so the cache cannot get stuck on a NULL entity.
	timer.Simple(0, function()
		if IsValid(ent) then
			cachedChangelevelTrigger = ent
			cachedChangelevelTriggerExists = true
			nextChangelevelTriggerRefresh = CurTime() + CHANGELEVEL_TRIGGER_REFRESH_INTERVAL
		elseif cachedChangelevelTrigger == ent then
			RefreshChangelevelTrigger(ent)
		end
	end)
end)
hook.Add("EntityRemoved", "ZC_CacheDynamicChangelevelTrigger", function(ent)
	if ent != cachedChangelevelTrigger and ent:GetClass() != CHANGELEVEL_TRIGGER_CLASS then return end
	RefreshChangelevelTrigger(ent)
end)

function zc:GetMode(round)
	if zc.modes[round] then return round end

	for name, mode in pairs(zc.modes) do
		if mode.Types and mode.Types[round] then
			return name
		end
	end
end

function zc.HasChangelevelTrigger()
	return HasChangelevelTrigger()
end

-- Pure getter: returns the current mode table (and its name) without any
-- side effects. The round controller owns all transitions.
function CurrentRound()
	if zc.round and zc.round.GetCurrent then
		return zc.round.GetCurrent()
	end

	return zc.modes[zc.CROUND or "hmcd"], zc.CROUND
end

function NextRound(round)
	if HasChangelevelTrigger() then
		zc.nextround = "coop"
	else
		zc.nextround = round
	end
end

hook.Add("ZC_CanReceiveCommunication","ZC_RoundStartChat",function(output, input, isChat, teamonly, text)
	if zc.ROUND_STATE == 0 or zc.ROUND_STATE == 3 then return true, false end
end)

-- Legacy wrapper: ends the current round through the controller.
-- Repeated calls while not ACTIVE (or with a result already fixed) are
-- ignored by the controller.
function zc:EndRound(result)
	return zc.round.RequestEnd(istable(result) and result or { reason = "admin" })
end

function zc:CheckWinner(tbl)
	local playerTable = table.Copy(tbl)
	for i, players in pairs(playerTable) do
		if table.Count(players) == 0 then
			playerTable[i] = nil
			continue
		end

		playerTable[i] = i
	end

	local winner = (table.Count(playerTable) == 1 and table.Random(playerTable)) or (table.Count(playerTable) == 0 and 3) or false
	local shouldendround = winner and true or nil
	return shouldendround, winner
end

zc.ROUND_TIME = zc.ROUND_TIME or 300
zc.DEFAULT_RESPAWN_TIMER = zc.DEFAULT_RESPAWN_TIMER or 10

hook.Add("PlayerInitialSpawn", "ZC_SendRoundInfo", function(ply)
	if zc.CROUND then
		local mode,_ = CurrentRound()
		net.Start("ZC_RoundInfo")
			net.WriteString(mode.name or "hmcd")
			net.WriteInt(zc.ROUND_STATE, 4)
		net.Send(ply)
	end

	if ply.SyncVars then ply:SyncVars() end
end)

util.AddNetworkString("ZC_RoundInfo")

-- Round ticking is owned by the round controller (ZC_RoundControllerThink).

hook.Add("PlayerDeath", "ZC_ModeRespawnTimer", function(ply)
	local mode = CurrentRound()
	if not mode or not mode.AllowRespawn then return end
	if ply:Team() == TEAM_SPECTATOR then return end

	local modeName = mode.name
	local delay = tonumber(mode.RespawnTimer) or zc.DEFAULT_RESPAWN_TIMER
	local timerName = "ZC_ModeRespawnTimer" .. ply:EntIndex()

	timer.Create(timerName, math.max(delay, 0), 1, function()
		if not IsValid(ply) or ply:Alive() or ply:Team() == TEAM_SPECTATOR then return end
		if zc.ROUND_STATE ~= 1 then return end

		local currentMode = CurrentRound()
		if not currentMode or currentMode.name ~= modeName or not currentMode.AllowRespawn then return end

		ply:Spawn()
		PlayerSelectSpawn(ply)

		if currentMode.GivePlayerEquipment then
			currentMode:GivePlayerEquipment(ply)
		end
	end)
end)

function zc:KillPlayers()
	local mode = CurrentRound()
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ply:GiveExp(math.random(4,15))

		if ply:Alive() and mode.DontKillPlayer and mode:DontKillPlayer(ply) then
			zc.organism.Clear(ply.organism)
			zc.FakeUp(ply,true,true)

			continue
		end

		if ply:FlashlightIsOn() then ply:Flashlight(false) end

		ply:KillSilent()
		ply:Spawn()
		ply:SetPlayerClass()
	end
end

zc.forcemode = zc.forcemode or "random"

local forcemode = zc.forcemode

-- Accessors for the round controller; the convar overrides until an admin
-- sets the force mode directly.
function zc.GetForcemode()
	local str = forcemodeconvar:GetString()
	if str ~= "" then
		forcemode = str
	end

	return forcemode
end

function zc.SetForcemode(name)
	forcemode = name
end

function zc.GetModes()
	local newtbl = {}
	for name,_ in pairs(zc.modes) do
		table.insert(newtbl,name)
	end
	return newtbl
end

ZBATTLE_BIGMAP = 5700
local MAP_SIZES_PATH = "maps/sizes.json"

hook.Add("InitPostEntity", "ZC_LoadLargeMapConfig", function()
	local tbl = zc.ParseDataFile(MAP_SIZES_PATH, {})

	if tbl[game.GetMap()] then
		ZBATTLE_BIGMAP = tbl[game.GetMap()]
	end
end)

COMMANDS.bigmap = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		ZBATTLE_BIGMAP = tonumber(args[1])
		ply:ChatPrint("Distance for big map: " .. ZBATTLE_BIGMAP)
		zc.RerollChances()

		local tbl = zc.ParseDataFile(MAP_SIZES_PATH, {[game.GetMap()] = ZBATTLE_BIGMAP})

		tbl[game.GetMap()] = ZBATTLE_BIGMAP

		zc.WriteData(MAP_SIZES_PATH, tbl, true)

		ply:ChatPrint("Saved into a file")
	end,
	0
}


zc.BigMaps = {
	["mu_smallotown_v2_snow"] = true,
	["mu_smallotown_v2_13"] = true,
	["mu_smallotown_v2_13_night"] = true,
}

function zc.GetAvailableModes()
	zc.tdm_checkpoints()

	local newtbl = {}

	for _, name in pairs(zc.GetModes()) do

		local tbl = zc.modes[name]
		if (tbl.CanLaunch and tbl:CanLaunch()) and
		(
			( not tbl.ForBigMaps ) or
			( zc.GetWorldSize() > ZBATTLE_BIGMAP )
		) then
			if tbl.SubModes then
				for _, name2 in pairs(tbl:SubModes()) do
					table.insert(newtbl, name2)
				end
			else
				table.insert(newtbl, name)
			end
		end
	end

	return newtbl
end

zc.ModesPlaytime = zc.ModesPlaytime or {}

function zc.GetModesPlaytime()
	local tbl = zc.GetAvailableModes()
	local newtbl = {}
	local count = 0

	for _, name in ipairs(tbl) do
		local amt = zc.ModesPlaytime[name] or 0
		newtbl[name] = amt
		count = count + amt
	end

	return newtbl, count
end

function zc.GetModePlaytime(name)
	return zc.ModesPlaytime[name] or 0
end

function zc.SetModePlaytime(name, set)
	zc.ModesPlaytime[name] = set
end

function zc.AddModePlaytime(name, add)
	zc.ModesPlaytime[name] = (zc.ModesPlaytime[name] or 0) + add
end

function zc.AddCurrentModePlayed()
	if not CurrentRound() then return end
	local mode = CurrentRound()
	local name = mode.name

	if mode.SubModes then
		name = mode.Type or "hmcd"
	end

	zc.AddModePlaytime(name, 1)
end

function zc.GetChance(name, addtbl)
	local mode = zc:GetMode(name)
	local tbl = zc.modes[mode]

	local newtbl = tbl.Types and tbl.Types[name] or tbl

	return newtbl.ChanceFunction and newtbl:ChanceFunction(addtbl or {}) or zc.ModesChances[name] or newtbl.Chance or 0.1
end

function zc.GetModesChances()
	local tbl = zc.GetAvailableModes()
	local newtbl = {}

	for _, name in pairs(tbl) do
		newtbl[name] = zc.GetChance(name)
	end

	return newtbl
end

function zc.WeightedChanceMode(modes_chances)
	local weight = 0

	local newchancestbl = {}
	for name, chance in pairs(modes_chances) do
		local newchance = zc.GetChance(name, {rounds = zc.RoundList}) or chance
		newchancestbl[name] = newchance
		weight = weight + newchance * 100
	end

	local random = math.random(weight)

	local count = 0
	for name, chance in RandomPairs(modes_chances) do
		count = count + (newchancestbl[name] or chance) * 100

		if count >= random then
			return name
		end
	end

	return "hmcd"
end

function zc.GetWorldSize()
	/*
	local world = game.GetWorld()
	local worldMin = world:GetInternalVariable("m_WorldMins")
	local worldMax = world:GetInternalVariable("m_WorldMaxs")
	local size = worldMin:Distance(worldMax)

	return size + (zc.BigMaps[ game.GetMap() ] and 5000 or 0)
	*/

	local dist = 0
	local pts = zc.GetMapPoints( "RandomSpawns" )

	for _, pnt in pairs(pts) do
		for _, pnt2 in pairs(pts) do
			dist = math.max(dist, pnt.pos:DistToSqr(pnt2.pos))
		end
	end

	return math.sqrt(dist)
end

function zc.GetRoundName(name)
	local mode = zc:GetMode(name)
	if not mode or not zc.modes[mode] then return end
	return zc.modes[mode].PrintName
end

zc.RoundList = zc.RoundList or {}
zc.QueuedModes = zc.QueuedModes or {}

function zc.CheckChances()
	if #zc.RoundList == 0 then
		zc.RerollChances()
	end

	local nextrnd = zc.nextround or zc.RoundList[1]
	print("Next round is: "..zc.GetRoundName(nextrnd).." ("..nextrnd..")")

	if #zc.QueuedModes > 0 then
		print("Queued game modes:")
		for i=1, #zc.QueuedModes do
			print("  "..i..": "..zc.GetRoundName(zc.QueuedModes[i]).." ("..zc.QueuedModes[i]..")")
		end
	else
		for i=1,#zc.RoundList do
			print("Round "..(i+1).." will be "..zc.GetRoundName(zc.RoundList[i]).." ("..zc.RoundList[i]..")")
		end
	end
end

function zc.RerollChances()
	zc.RoundList = {}

	local chances = zc.GetModesChances()

	for i = 1, 20 do
		local round = zc.WeightedChanceMode(chances)

		zc.RoundList[i] = round
	end
end

function zc.GetModesInfo()
	local modesInfo = {}

	for name, mode in pairs(zc.modes) do
		if mode.Types then
			for name2 in pairs(mode.Types) do
				table.insert(modesInfo, {
					key = name2,
					name = (mode.PrintName or mode.name or name).."/"..name2,
					description = mode.Description or "",
					forBigMaps = mode.ForBigMaps or false,
					canlaunch = (mode:CanLaunch() and 1 or 0)
				})
			end
		else
			table.insert(modesInfo, {
				key = name,
				name = mode.PrintName or mode.name or name,
				description = mode.Description or "",
				forBigMaps = mode.ForBigMaps or false,
				canlaunch = (mode:CanLaunch() and 1 or 0)
			})
		end
	end

	return modesInfo
end


function zc.SetRoundList(newList)
	local newLista = table.Copy(newList)
	if #newLista > 0 then
		zc.nextround = table.remove(newLista, 1)
		zc.RoundList = newLista
	else
		zc.RerollChances()

		zc.nextround = table.remove(zc.RoundList, 1)
	end
end


util.AddNetworkString("ZC_ModesInfoSend")
util.AddNetworkString("ZC_RoundListSend")
util.AddNetworkString("ZC_RoundListRequest")
util.AddNetworkString("ZC_RoundListUpdate")
util.AddNetworkString("ZC_RoundListChangeNotice")


function zc.SendModesInfoToClient(ply)
	net.Start("ZC_ModesInfoSend")
		net.WriteTable(zc.GetModesInfo())
	net.Send(ply)
end


function zc.SendRoundListToClient(ply)
	net.Start("ZC_RoundListSend")
		net.WriteTable(zc.RoundList)
		net.WriteString(zc.nextround or "")
	net.Send(ply)
end


hook.Add("PlayerInitialSpawn", "ZC_SendModesOnSpawn", function(ply)
	if ply:IsAdmin() then
		timer.Simple(1, function()
			if IsValid(ply) then
				zc.SendModesInfoToClient(ply)
				zc.SendRoundListToClient(ply)
			end
		end)
	end
end)


net.Receive("ZC_RoundListRequest", function(len, ply)
	if IsValid(ply) and ply:IsAdmin() then
		zc.SendModesInfoToClient(ply)
		zc.SendRoundListToClient(ply)
	end
end)

net.Receive("ZC_RoundListUpdate", function(len, ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end

	local newList = net.ReadTable()

	zc.SetRoundList(newList)

	net.Start("ZC_RoundListChangeNotice")
		net.WriteString(ply:Nick())
	net.Send(zc.GetAllAdmins())

	for _, admin in ipairs(zc.GetAllAdmins()) do
		zc.SendRoundListToClient(admin)
	end
end)

function zc.SendRoundListToAllAdmins()
	for _, admin in ipairs(zc.GetAllAdmins()) do
		zc.SendRoundListToClient(admin)
	end
end

-- Round start/finish transitions live in sv_roundcontroller.lua now.
-- zc:EndRound above is the only legacy entry point kept for admins.

concommand.Add("zb_checkchances",function(ply) if ply:IsAdmin() then zc.CheckChances() end end)
concommand.Add("zb_rerollchances",function(ply) if ply:IsAdmin() then zc.RerollChances() zc.CheckChances() end end)

function zc.NotifyQueueEmptied()
	net.Start("ZC_QueueEmptiedNotice")
	net.Send(zc.GetAllAdmins())
end

hook.Add("PlayerInitialSpawn", "ZC_SendGameModesToClient", function(ply)
	if ply:IsAdmin() then
		local modesToSend = {}
		for key, mode in pairs(zc.modes) do
			table.insert(modesToSend, {key = key, name = mode.PrintName or mode.name})
		end

		net.Start("ZC_AvailableModesSend")
			net.WriteTable(modesToSend)
		net.Send(ply)
	end
end)

net.Receive("ZC_AdminSetGameMode", function(len, ply)
	if not ply:IsAdmin() then return end

	local command = net.ReadString()
	local modeKey = net.ReadString()
	local addToQueue = net.ReadBool() or false

	if command == "setmode" then
		NextRound(modeKey)
		ply:ChatPrint("Game mode set to: " .. modeKey)

		if addToQueue then
			table.insert(zc.QueuedModes, modeKey)
			zc.NotifyQueueModified(ply, "added " .. modeKey .. " to")

			zc.SyncQueueToAdmins()
		end
	elseif command == "setforcemode" then
		zc.SetForcemode(modeKey)
		NextRound(forcemode)
		ply:ChatPrint("Force mode set to: " .. modeKey)

		if addToQueue then
			table.insert(zc.QueuedModes, modeKey)
			zc.NotifyQueueModified(ply, "added " .. modeKey .. " to")

			zc.SyncQueueToAdmins()
		end
	end
end)

net.Receive("ZC_AdminEndRound", function(len, ply)
	if not ply:IsAdmin() then return end

	ply:ChatPrint("Round ended!")
	zc:EndRound()
end)

function zc.SyncQueueToAdmins()
	timer.Simple(0.1, function()
		net.Start("ZC_GameQueueSend")
		net.WriteTable(zc.QueuedModes)
		net.Send(zc.GetAllAdmins())
	end)
end

net.Receive("ZC_AdminSetGameQueue", function(len, ply)
	if not ply:IsAdmin() then return end

	local modeQueue = net.ReadTable()
	zc.QueuedModes = modeQueue

	if #modeQueue == 0 then
		ply:ChatPrint("Game mode queue has been cleared")
		zc.NotifyQueueModified(ply, "cleared")


		timer.Simple(0.2, function()
			net.Start("ZC_QueueEmptiedNotice")
			net.Send(zc.GetAllAdmins())
		end)
	else
		ply:ChatPrint("Game mode queue set with " .. #modeQueue .. " modes")
		zc.NotifyQueueModified(ply, "updated")
	end

	zc.SyncQueueToAdmins()
end)

function zc.NotifyQueueModified(ply, action)
	local admins = zc.GetAllAdmins()

	local recipients = {}
	for _, admin in ipairs(admins) do
		if admin ~= ply then
			table.insert(recipients, admin)
		end
	end


	if #recipients > 0 then
		net.Start("ZC_QueueModifiedNotice")
		net.WriteString(IsValid(ply) and ply:Nick() or "Server")
		net.WriteString(action)
		net.Send(recipients)
	end
end

function zc:Unfreeze()
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
end


function zc:Freeze()
	for i, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(true) end
	end
end

function zc.GetAllAdmins()
	local admins = {}
	for _, ply in player.Iterator() do
		if ply:IsAdmin() then
			table.insert(admins, ply)
		end
	end
	return admins
end

COMMANDS.setmode = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		if not args[1] or (not zc:GetMode(args[1]) and args[1]~="random") then return end
		ply:ChatPrint(args[1])
		NextRound(args[1])
	end,
	0
}

COMMANDS.setforcemode = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		if not args[1] or (not zc:GetMode(args[1]) and args[1]~="random") then return end
		ply:ChatPrint(args[1])
		zc.SetForcemode(args[1])
		if args[1] ~= "random" then
			NextRound(args[1])
		end
	end, 0
}

COMMANDS.endround = {
	function(ply, args)
		if not ply:IsAdmin() then
			ply:ChatPrint("You don't have access")
			return
		end
	 	zc:EndRound()
	end, 0
}

if SERVER then
	util.AddNetworkString("ZC_AvailableModesSend")
	util.AddNetworkString("ZC_AdminSetGameMode")
	util.AddNetworkString("ZC_AdminEndRound")
	util.AddNetworkString("ZC_AdminSetGameQueue")
	util.AddNetworkString("ZC_GameQueueRequest")
	util.AddNetworkString("ZC_GameQueueSend")
	util.AddNetworkString("ZC_QueueEmptiedNotice")
	util.AddNetworkString("ZC_QueueModifiedNotice")

	hook.Add("PlayerInitialSpawn", "ZC_SendGameModesToClient", function(ply)
		if ply:IsAdmin() then
			local modesToSend = {}
			for key, mode in pairs(zc.modes) do
				table.insert(modesToSend, {key = key, name = mode.PrintName or mode.name})
			end

			net.Start("ZC_AvailableModesSend")
				net.WriteTable(modesToSend)
			net.Send(ply)
		end
	end)

	net.Receive("ZC_AdminSetGameMode", function(len, ply)
		if not ply:IsAdmin() then return end

		local command = net.ReadString()
		local modeKey = net.ReadString()
		local addToQueue = net.ReadBool() or false

		if !(ply:IsSuperAdmin() or ply:IsAdmin()) and not zc.modes[modeKey]:CanLaunch() then
			ply:ChatPrint("This mode can't launch (No points or Is blocked): " .. modeKey)
			return
		end

		if command == "setmode" then
			NextRound(modeKey)
			ply:ChatPrint("Game mode set to: " .. modeKey)

			if addToQueue then
				table.insert(zc.QueuedModes, modeKey)
				zc.NotifyQueueModified(ply, "added " .. modeKey .. " to")

				zc.SyncQueueToAdmins()
			end
		elseif command == "setforcemode" then
			zc.SetForcemode(modeKey)
			NextRound(zc.GetForcemode())
			ply:ChatPrint("Force mode set to: " .. modeKey)

			if addToQueue then
				table.insert(zc.QueuedModes, modeKey)
				zc.NotifyQueueModified(ply, "added " .. modeKey .. " to")

				zc.SyncQueueToAdmins()
			end
		end
	end)

	function zc.SyncQueueToAdmins()
		timer.Simple(0.1, function()
			net.Start("ZC_GameQueueSend")
			net.WriteTable(zc.QueuedModes)
			net.Send(zc.GetAllAdmins())
		end)
	end

	net.Receive("ZC_AdminSetGameQueue", function(len, ply)
		if not ply:IsAdmin() then return end

		local modeQueue = net.ReadTable()
		zc.QueuedModes = modeQueue

		if #modeQueue == 0 then
			ply:ChatPrint("Game mode queue has been cleared")
			zc.NotifyQueueModified(ply, "cleared")


			timer.Simple(0.2, function()
				net.Start("ZC_QueueEmptiedNotice")
				net.Send(zc.GetAllAdmins())
			end)
		else
			ply:ChatPrint("Game mode queue set with " .. #modeQueue .. " modes")
			zc.NotifyQueueModified(ply, "updated")
		end

		zc.SyncQueueToAdmins()
	end)

end
