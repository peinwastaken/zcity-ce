local player_GetAll = player.GetAll
zc.modes = zc.modes or {}

util.AddNetworkString("ZC_FadeScreen")

function zc.AddFade()
	net.Start("ZC_FadeScreen")
	net.Broadcast()
end

local forcemodeconvar = CreateConVar("zc_forcemode", "random", nil, "Set force mode (set to 'random' to disable)")
forcemodeconvar:SetString("random")
function zc:GetMode(round)
	if zc.modes[round] then return round end

	for name, mode in pairs(zc.modes) do
		if mode.Types and mode.Types[round] then
			return name
		end
	end
end

function CurrentRound()
	if IsValid(ents.FindByClass( "trigger_changelevel" )[1]) then
		zc.nextround = "coop"
		zc.CROUND = zc.CROUND or "coop"
		return zc.modes["coop"]
	end

	zc.CROUND = zc.CROUND or "hmcd"
	if not zc.CROUND_MAIN or (zc.LASTCROUND != zc.CROUND) then
		zc.CROUND_MAIN = zc:GetMode(zc.CROUND)
		zc.LASTCROUND = zc.CROUND
	end

	local round = zc.CROUND_MAIN

	return zc.modes[round], zc.CROUND
end

function NextRound(round)
	if IsValid(ents.FindByClass( "trigger_changelevel" )[1]) then
		zc.nextround = "coop"
	else
		zc.nextround = round
	end
end

function zc:PreRound()
	local roundCountReachedMapVote = (zc.Roundscount or 0) > 15 and not GetConVar("zc_dev"):GetBool()
	local playersCanVote = false

	if not roundCountReachedMapVote then
		playersCanVote = player.GetCount() > 1 and zc.ROUND_STATE == 0 and zc.CheckRTVVotes()
	end

	local cstrikeRoundLimitActive = zc.RoundsLeft and zc.CROUND == "cstrike"

	if (roundCountReachedMapVote or playersCanVote) and not cstrikeRoundLimitActive then
		zc.StartRTV(20)
		zc.ROUND_STATE = 0
		return
	end

	if zc.ROUND_STATE == 0 and #player_GetAll() > 1 then
		zc.END_TIME = nil

		zc.START_TIME = zc.START_TIME or CurTime() + (CurrentRound().start_time or 5)
		if zc.START_TIME < CurTime() then zc:RoundStart() end
	end
end

function zc:RoundThink()
	if zc.ROUND_STATE == 1 then
		if CurrentRound().RoundThink then CurrentRound():RoundThink(CurrentRound()) end
	end
end

hook.Add("ZC_CanReceiveCommunication","ZC_RoundStartChat",function(output, input, isChat, teamonly, text)
	if zc.ROUND_STATE == 0 or zc.ROUND_STATE == 3 then return true, false end
end)

function zc:EndRound()
	zc.ROUND_STATE = 3
	zc.Roundscount = (zc.Roundscount or 0) + 1

	local mode, _ = CurrentRound()

	net.Start("ZC_RoundInfo")
		net.WriteString(mode.name or "hmcd")
		net.WriteInt(zc.ROUND_STATE, 4)
	net.Broadcast()

	--PrintMessage(HUD_PRINTTALK, "Round ended.")
	CurrentRound():EndRound()
	hook.Run("ZC_EndRound")
	zc.AddFade()

	zc.achievements.SavePlayerAchievements()
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

function zc:ShouldRoundEnd()
	local time = zc.ROUND_TIME
	local mode = CurrentRound()
	local shouldroundend = mode:ShouldRoundEnd()
	if shouldroundend ~= false then
		local boringround = not mode.DisableRoundTimer and (zc.ROUND_START + time) < CurTime()

		if boringround and mode.BoringRoundFunction then
			PrintMessage(HUD_PRINTTALK, "Stopping round because it was TOO boring.")

			mode:BoringRoundFunction()
		end

		return (shouldroundend and true) or (boringround)
	else
		return false
	end
end

function zc:EndRoundThink()
	if zc.ROUND_STATE == 1 and zc:ShouldRoundEnd() then zc:EndRound() end
	if zc.ROUND_STATE == 3 then
		if !zc.END_TIME then
			zc.END_TIME = (CurTime() + (CurrentRound().end_time or 5))
			if zc.nextround == "coop" and GetGlobalVar("coop_first_round_timer", 0) == 0 then

				zc.END_TIME = (CurTime() + (GetConVar("zc_dev") and 5 or 60))
				SetGlobalVar("coop_first_round_timer", zc.END_TIME)
			end
		end

		zc.SHOULD_FADE = zc.SHOULD_FADE != nil and zc.SHOULD_FADE or true

		if zc.SHOULD_FADE and (zc.END_TIME < CurTime() + 1.5) then
			zc.SHOULD_FADE = false

			for _, ply in player.Iterator() do
				ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0), 1, 7)
			end
		end

		if zc.END_TIME < CurTime() then
			zc.ROUND_STATE = 0

			zc.SHOULD_FADE = true

			hook.Run("ZC_PreRoundStart")
			hook.Run("TTTPrepareRound") -- stormfox2 random_round_weather

			zc.CROUND = zc.nextround or "hmcd"
			if CurrentRound().shouldfreeze then zc:Freeze() end

			--PrintMessage(HUD_PRINTTALK, "Gamemode: " .. CurrentRound().PrintName or "None")

			local mode, _ = CurrentRound()
			net.Start("ZC_RoundInfo")
				net.WriteString(mode.name or "hmcd")
				net.WriteInt(zc.ROUND_STATE, 4)
			net.Broadcast()

			zc.UpdateRoundTime(CurrentRound().ROUND_TIME, CurTime(), CurTime() + (CurrentRound().start_time or 5))

			self:KillPlayers()
			self:AutoBalance()

			CurrentRound().saved = {}

			CurrentRound():Intermission()
			CurrentRound():GiveEquipment()
		end
	end
end

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
function zc:Think(time)
	if (zc.thinkTime or CurTime()) > time then return end
	zc.thinkTime = time + 1
	zc:PreRound()
	zc:RoundThink()
	zc:EndRoundThink()
end

hook.Add("Think", "ZC_RoundSystemThink", function() zc:Think(CurTime()) end)

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

function zc.GetModes()
	local newtbl = {}
	for name,_ in pairs(zc.modes) do
		table.insert(newtbl,name)
	end
	return newtbl
end

ZBATTLE_BIGMAP = 5700

hook.Add("InitPostEntity", "ZC_LoadLargeMapConfig", function()
	local filik = file.Read("zbattle/mapsizes.json", "DATA")

	if filik then
		local tbl = util.JSONToTable(filik)

		if tbl[game.GetMap()] then
			ZBATTLE_BIGMAP = tbl[game.GetMap()]
		end
	end
end)

COMMANDS.bigmap = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		ZBATTLE_BIGMAP = tonumber(args[1])
		ply:ChatPrint("Distance for big map: " .. ZBATTLE_BIGMAP)
		zc.RerollChances()

		file.CreateDir("zbattle")

		local tbl = util.JSONToTable(file.Read("zbattle/mapsizes.json", "DATA") or util.TableToJSON({[game.GetMap()] = ZBATTLE_BIGMAP}))

		tbl[game.GetMap()] = ZBATTLE_BIGMAP

		file.Write("zbattle/mapsizes.json", util.TableToJSON(tbl))

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

	zc.nextround = table.remove(zc.RoundList, 1)
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

function zc:RoundStart()
	if CurrentRound().shouldfreeze then zc:Unfreeze() end

	zc.ROUND_STATE = 1
	zc.START_TIME = nil

	local mode, round = CurrentRound()

	VFIRE_DISABLED = (mode.name == "coop")

	zc.ROUND_BEGIN = CurTime()
	zc.UpdateRoundTime()

	net.Start("ZC_RoundInfo")
		net.WriteString(mode.name or "hmcd")
		net.WriteInt(zc.ROUND_STATE, 4)
	net.Broadcast()

	if forcemodeconvar:GetString() != "" then
		forcemode = forcemodeconvar:GetString()
	end

	zc.AddCurrentModePlayed()

	CurrentRound():RoundStart()

	local nextMode

	if #zc.RoundList == 0 then
		zc.RerollChances()
	end

	nextMode = table.remove(zc.RoundList, 1)


	print("Next game mode is " .. nextMode)

	NextRound(forcemode ~= "random" and forcemode or (nextMode or "hmcd"))

	if CurrentRound().RoundStartPost then
		CurrentRound():RoundStartPost()
	end

	hook.Run("ZC_StartRound")

	//zc.GetAllPoints(true)

	for _, admin in ipairs(zc.GetAllAdmins()) do
		zc.SendRoundListToClient(admin)
	end
end

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
		forcemode = modeKey
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
		forcemode = args[1]
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
			forcemode = modeKey
			NextRound(forcemode)
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
