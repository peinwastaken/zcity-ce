local player_GetAll = player.GetAll
zb.modes = zb.modes or {}

util.AddNetworkString("ZC_FadeScreen")

function zb.AddFade()
	net.Start("ZC_FadeScreen")
	net.Broadcast()
end

local forcemodeconvar = CreateConVar("zc_forcemode", "random", nil, "Set force mode (set to 'random' to disable)")
forcemodeconvar:SetString("random")
function zb:GetMode(round)
	if zb.modes[round] then return round end

	for name, mode in pairs(zb.modes) do
		if mode.Types and mode.Types[round] then
			return name
		end
	end
end

function CurrentRound()
	if IsValid(ents.FindByClass( "trigger_changelevel" )[1]) then
		zb.nextround = "coop"
		zb.CROUND = zb.CROUND or "coop"
		return zb.modes["coop"]
	end

	zb.CROUND = zb.CROUND or "hmcd"
	if not zb.CROUND_MAIN or (zb.LASTCROUND != zb.CROUND) then
		zb.CROUND_MAIN = zb:GetMode(zb.CROUND)
		zb.LASTCROUND = zb.CROUND
	end

	local round = zb.CROUND_MAIN

	return zb.modes[round], zb.CROUND
end

function NextRound(round)
	if IsValid(ents.FindByClass( "trigger_changelevel" )[1]) then
		zb.nextround = "coop"
	else
		zb.nextround = round
	end
end

function zb:PreRound()
	local roundCountReachedMapVote = (zb.Roundscount or 0) > 15 and not GetConVar("zc_dev"):GetBool()
	local playersCanVote = false

	if not roundCountReachedMapVote then
		playersCanVote = player.GetCount() > 1 and zb.ROUND_STATE == 0 and zb.CheckRTVVotes()
	end

	local cstrikeRoundLimitActive = zb.RoundsLeft and zb.CROUND == "cstrike"

	if (roundCountReachedMapVote or playersCanVote) and not cstrikeRoundLimitActive then
		zb.StartRTV(20)
		zb.ROUND_STATE = 0
		return
	end

	if zb.ROUND_STATE == 0 and #player_GetAll() > 1 then
		zb.END_TIME = nil

		zb.START_TIME = zb.START_TIME or CurTime() + (CurrentRound().start_time or 5)
		if zb.START_TIME < CurTime() then zb:RoundStart() end
	end
end

function zb:RoundThink()
	if zb.ROUND_STATE == 1 then
		if CurrentRound().RoundThink then CurrentRound():RoundThink(CurrentRound()) end
	end
end

hook.Add("ZC_CanReceiveCommunication","ZC_RoundStartChat",function(output, input, isChat, teamonly, text)
	if zb.ROUND_STATE == 0 or zb.ROUND_STATE == 3 then return true, false end
end)

function zb:EndRound()
	zb.ROUND_STATE = 3
	zb.Roundscount = (zb.Roundscount or 0) + 1

	local mode, _ = CurrentRound()

	net.Start("ZC_RoundInfo")
		net.WriteString(mode.name or "hmcd")
		net.WriteInt(zb.ROUND_STATE, 4)
	net.Broadcast()

	--PrintMessage(HUD_PRINTTALK, "Round ended.")
	CurrentRound():EndRound()
	hook.Run("ZC_EndRound")
	zb.AddFade()

	hg.achievements.SavePlayerAchievements()
end

function zb:CheckWinner(tbl)
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

zb.ROUND_TIME = zb.ROUND_TIME or 300

function zb:ShouldRoundEnd()
	local time = zb.ROUND_TIME
	local shouldroundend = CurrentRound():ShouldRoundEnd()
	if shouldroundend ~= false then
		local boringround = (zb.ROUND_START + time) < CurTime()

		if boringround and CurrentRound().BoringRoundFunction then
			PrintMessage(HUD_PRINTTALK, "Stopping round because it was TOO boring.")

			CurrentRound():BoringRoundFunction()
		end

		return (shouldroundend and true) or (boringround)
	else
		return false
	end
end

function zb:EndRoundThink()
	if zb.ROUND_STATE == 1 and zb:ShouldRoundEnd() then zb:EndRound() end
	if zb.ROUND_STATE == 3 then
		if !zb.END_TIME then
			zb.END_TIME = (CurTime() + (CurrentRound().end_time or 5))
			if zb.nextround == "coop" and GetGlobalVar("coop_first_round_timer", 0) == 0 then

				zb.END_TIME = (CurTime() + (GetConVar("zc_dev") and 5 or 60))
				SetGlobalVar("coop_first_round_timer", zb.END_TIME)
			end
		end

		zb.SHOULD_FADE = zb.SHOULD_FADE != nil and zb.SHOULD_FADE or true

		if zb.SHOULD_FADE and (zb.END_TIME < CurTime() + 1.5) then
			zb.SHOULD_FADE = false

			for _, ply in player.Iterator() do
				ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0), 1, 7)
			end
		end

		if zb.END_TIME < CurTime() then
			zb.ROUND_STATE = 0

			zb.SHOULD_FADE = true

			hook.Run("ZC_PreRoundStart")
			hook.Run("TTTPrepareRound") -- stormfox2 random_round_weather

			zb.CROUND = zb.nextround or "hmcd"
			if CurrentRound().shouldfreeze then zb:Freeze() end

			--PrintMessage(HUD_PRINTTALK, "Gamemode: " .. CurrentRound().PrintName or "None")

			local mode, _ = CurrentRound()
			net.Start("ZC_RoundInfo")
				net.WriteString(mode.name or "hmcd")
				net.WriteInt(zb.ROUND_STATE, 4)
			net.Broadcast()

			hg.UpdateRoundTime(CurrentRound().ROUND_TIME, CurTime(), CurTime() + (CurrentRound().start_time or 5))

			self:KillPlayers()
			self:AutoBalance()

			CurrentRound().saved = {}

			CurrentRound():Intermission()
			CurrentRound():GiveEquipment()
		end
	end
end

hook.Add("PlayerInitialSpawn", "ZC_SendRoundInfo", function(ply)
	if zb.CROUND then
		local mode,_ = CurrentRound()
		net.Start("ZC_RoundInfo")
			net.WriteString(mode.name or "hmcd")
			net.WriteInt(zb.ROUND_STATE, 4)
		net.Send(ply)
	end

	if ply.SyncVars then ply:SyncVars() end
end)

util.AddNetworkString("ZC_RoundInfo")
function zb:Think(time)
	if (zb.thinkTime or CurTime()) > time then return end
	zb.thinkTime = time + 1
	zb:PreRound()
	zb:RoundThink()
	zb:EndRoundThink()
end

hook.Add("Think", "ZC_RoundSystemThink", function() zb:Think(CurTime()) end)

function zb:KillPlayers()
	local mode = CurrentRound()
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then continue end

		ply:GiveExp(math.random(4,15))

		if ply:Alive() and mode.DontKillPlayer and mode:DontKillPlayer(ply) then
			hg.organism.Clear(ply.organism)
			hg.FakeUp(ply,true,true)

			continue
		end

		if ply:FlashlightIsOn() then ply:Flashlight(false) end

		ply:KillSilent()
		ply:Spawn()
		ply:SetPlayerClass()
	end
end

zb.forcemode = zb.forcemode or "random"

local forcemode = zb.forcemode

function zb.GetModes()
	local newtbl = {}
	for name,_ in pairs(zb.modes) do
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
		zb.RerollChances()

		file.CreateDir("zbattle")

		local tbl = util.JSONToTable(file.Read("zbattle/mapsizes.json", "DATA") or util.TableToJSON({[game.GetMap()] = ZBATTLE_BIGMAP}))

		tbl[game.GetMap()] = ZBATTLE_BIGMAP

		file.Write("zbattle/mapsizes.json", util.TableToJSON(tbl))

		ply:ChatPrint("Saved into a file")
	end,
	0
}


zb.BigMaps = {
	["mu_smallotown_v2_snow"] = true,
	["mu_smallotown_v2_13"] = true,
	["mu_smallotown_v2_13_night"] = true,
}

function zb.GetAvailableModes()
	zb.tdm_checkpoints()

	local newtbl = {}

	for _, name in pairs(zb.GetModes()) do

		local tbl = zb.modes[name]
		if (tbl.CanLaunch and tbl:CanLaunch()) and
		(
			( not tbl.ForBigMaps ) or
			( zb.GetWorldSize() > ZBATTLE_BIGMAP )
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

zb.ModesPlaytime = zb.ModesPlaytime or {}

function zb.GetModesPlaytime()
	local tbl = zb.GetAvailableModes()
	local newtbl = {}
	local count = 0

	for _, name in ipairs(tbl) do
		local amt = zb.ModesPlaytime[name] or 0
		newtbl[name] = amt
		count = count + amt
	end

	return newtbl, count
end

function zb.GetModePlaytime(name)
	return zb.ModesPlaytime[name] or 0
end

function zb.SetModePlaytime(name, set)
	zb.ModesPlaytime[name] = set
end

function zb.AddModePlaytime(name, add)
	zb.ModesPlaytime[name] = (zb.ModesPlaytime[name] or 0) + add
end

function zb.AddCurrentModePlayed()
	if not CurrentRound() then return end
	local mode = CurrentRound()
	local name = mode.name

	if mode.SubModes then
		name = mode.Type or "hmcd"
	end

	zb.AddModePlaytime(name, 1)
end

function zb.GetChance(name, addtbl)
	local mode = zb:GetMode(name)
	local tbl = zb.modes[mode]

	local newtbl = tbl.Types and tbl.Types[name] or tbl

	return newtbl.ChanceFunction and newtbl:ChanceFunction(addtbl or {}) or zb.ModesChances[name] or newtbl.Chance or 0.1
end

function zb.GetModesChances()
	local tbl = zb.GetAvailableModes()
	local newtbl = {}

	for _, name in pairs(tbl) do
		newtbl[name] = zb.GetChance(name)
	end

	return newtbl
end

function zb.WeightedChanceMode(modes_chances)
	local weight = 0

	local newchancestbl = {}
	for name, chance in pairs(modes_chances) do
		local newchance = zb.GetChance(name, {rounds = zb.RoundList}) or chance
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

function zb.GetWorldSize()
	/*
	local world = game.GetWorld()
	local worldMin = world:GetInternalVariable("m_WorldMins")
	local worldMax = world:GetInternalVariable("m_WorldMaxs")
	local size = worldMin:Distance(worldMax)

	return size + (zb.BigMaps[ game.GetMap() ] and 5000 or 0)
	*/

	local dist = 0
	local pts = zb.GetMapPoints( "RandomSpawns" )

	for _, pnt in pairs(pts) do
		for _, pnt2 in pairs(pts) do
			dist = math.max(dist, pnt.pos:DistToSqr(pnt2.pos))
		end
	end

	return math.sqrt(dist)
end

function zb.GetRoundName(name)
	local mode = zb:GetMode(name)
	if not mode or not zb.modes[mode] then return end
	return zb.modes[mode].PrintName
end

zb.RoundList = zb.RoundList or {}
zb.QueuedModes = zb.QueuedModes or {}

function zb.CheckChances()
	if #zb.RoundList == 0 then
		zb.RerollChances()
	end

	local nextrnd = zb.nextround or zb.RoundList[1]
	print("Next round is: "..zb.GetRoundName(nextrnd).." ("..nextrnd..")")

	if #zb.QueuedModes > 0 then
		print("Queued game modes:")
		for i=1, #zb.QueuedModes do
			print("  "..i..": "..zb.GetRoundName(zb.QueuedModes[i]).." ("..zb.QueuedModes[i]..")")
		end
	else
		for i=1,#zb.RoundList do
			print("Round "..(i+1).." will be "..zb.GetRoundName(zb.RoundList[i]).." ("..zb.RoundList[i]..")")
		end
	end
end

function zb.RerollChances()
	zb.RoundList = {}

	local chances = zb.GetModesChances()

	for i = 1, 20 do
		local round = zb.WeightedChanceMode(chances)

		zb.RoundList[i] = round
	end

	zb.nextround = table.remove(zb.RoundList, 1)
end

function zb.GetModesInfo()
	local modesInfo = {}

	for name, mode in pairs(zb.modes) do
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


function zb.SetRoundList(newList)
	local newLista = table.Copy(newList)
	if #newLista > 0 then
		zb.nextround = table.remove(newLista, 1)
		zb.RoundList = newLista
	else
		zb.RerollChances()

		zb.nextround = table.remove(zb.RoundList, 1)
	end
end


util.AddNetworkString("ZC_ModesInfoSend")
util.AddNetworkString("ZC_RoundListSend")
util.AddNetworkString("ZC_RoundListRequest")
util.AddNetworkString("ZC_RoundListUpdate")
util.AddNetworkString("ZC_RoundListChangeNotice")


function zb.SendModesInfoToClient(ply)
	net.Start("ZC_ModesInfoSend")
		net.WriteTable(zb.GetModesInfo())
	net.Send(ply)
end


function zb.SendRoundListToClient(ply)
	net.Start("ZC_RoundListSend")
		net.WriteTable(zb.RoundList)
		net.WriteString(zb.nextround or "")
	net.Send(ply)
end


hook.Add("PlayerInitialSpawn", "ZC_SendModesOnSpawn", function(ply)
	if ply:IsAdmin() then
		timer.Simple(1, function()
			if IsValid(ply) then
				zb.SendModesInfoToClient(ply)
				zb.SendRoundListToClient(ply)
			end
		end)
	end
end)


net.Receive("ZC_RoundListRequest", function(len, ply)
	if IsValid(ply) and ply:IsAdmin() then
		zb.SendModesInfoToClient(ply)
		zb.SendRoundListToClient(ply)
	end
end)

net.Receive("ZC_RoundListUpdate", function(len, ply)
	if not IsValid(ply) or not ply:IsAdmin() then return end

	local newList = net.ReadTable()

	zb.SetRoundList(newList)

	net.Start("ZC_RoundListChangeNotice")
		net.WriteString(ply:Nick())
	net.Send(zb.GetAllAdmins())

	for _, admin in ipairs(zb.GetAllAdmins()) do
		zb.SendRoundListToClient(admin)
	end
end)

function zb:RoundStart()
	if CurrentRound().shouldfreeze then zb:Unfreeze() end

	zb.ROUND_STATE = 1
	zb.START_TIME = nil

	local mode, round = CurrentRound()

	VFIRE_DISABLED = (mode.name == "coop")

	zb.ROUND_BEGIN = CurTime()
	hg.UpdateRoundTime()

	net.Start("ZC_RoundInfo")
		net.WriteString(mode.name or "hmcd")
		net.WriteInt(zb.ROUND_STATE, 4)
	net.Broadcast()

	if forcemodeconvar:GetString() != "" then
		forcemode = forcemodeconvar:GetString()
	end

	zb.AddCurrentModePlayed()

	CurrentRound():RoundStart()

	local nextMode

	if #zb.RoundList == 0 then
		zb.RerollChances()
	end

	nextMode = table.remove(zb.RoundList, 1)


	print("Next game mode is " .. nextMode)

	NextRound(forcemode ~= "random" and forcemode or (nextMode or "hmcd"))

	if CurrentRound().RoundStartPost then
		CurrentRound():RoundStartPost()
	end

	hook.Run("ZC_StartRound")

	//zb.GetAllPoints(true)

	for _, admin in ipairs(zb.GetAllAdmins()) do
		zb.SendRoundListToClient(admin)
	end
end

concommand.Add("zb_checkchances",function(ply) if ply:IsAdmin() then zb.CheckChances() end end)
concommand.Add("zb_rerollchances",function(ply) if ply:IsAdmin() then zb.RerollChances() zb.CheckChances() end end)

function zb.NotifyQueueEmptied()
	net.Start("ZC_QueueEmptiedNotice")
	net.Send(zb.GetAllAdmins())
end

hook.Add("PlayerInitialSpawn", "ZC_SendGameModesToClient", function(ply)
	if ply:IsAdmin() then
		local modesToSend = {}
		for key, mode in pairs(zb.modes) do
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
			table.insert(zb.QueuedModes, modeKey)
			zb.NotifyQueueModified(ply, "added " .. modeKey .. " to")

			zb.SyncQueueToAdmins()
		end
	elseif command == "setforcemode" then
		forcemode = modeKey
		NextRound(forcemode)
		ply:ChatPrint("Force mode set to: " .. modeKey)

		if addToQueue then
			table.insert(zb.QueuedModes, modeKey)
			zb.NotifyQueueModified(ply, "added " .. modeKey .. " to")

			zb.SyncQueueToAdmins()
		end
	end
end)

net.Receive("ZC_AdminEndRound", function(len, ply)
	if not ply:IsAdmin() then return end

	ply:ChatPrint("Round ended!")
	zb:EndRound()
end)

function zb.SyncQueueToAdmins()
	timer.Simple(0.1, function()
		net.Start("ZC_GameQueueSend")
		net.WriteTable(zb.QueuedModes)
		net.Send(zb.GetAllAdmins())
	end)
end

net.Receive("ZC_AdminSetGameQueue", function(len, ply)
	if not ply:IsAdmin() then return end

	local modeQueue = net.ReadTable()
	zb.QueuedModes = modeQueue

	if #modeQueue == 0 then
		ply:ChatPrint("Game mode queue has been cleared")
		zb.NotifyQueueModified(ply, "cleared")


		timer.Simple(0.2, function()
			net.Start("ZC_QueueEmptiedNotice")
			net.Send(zb.GetAllAdmins())
		end)
	else
		ply:ChatPrint("Game mode queue set with " .. #modeQueue .. " modes")
		zb.NotifyQueueModified(ply, "updated")
	end

	zb.SyncQueueToAdmins()
end)

function zb.NotifyQueueModified(ply, action)
	local admins = zb.GetAllAdmins()

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

function zb:Unfreeze()
	for _, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(false) end
	end
end


function zb:Freeze()
	for i, ply in player.Iterator() do
		if ply:Alive() then ply:Freeze(true) end
	end
end

function zb.GetAllAdmins()
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
		if not args[1] or (not zb:GetMode(args[1]) and args[1]~="random") then return end
		ply:ChatPrint(args[1])
		NextRound(args[1])
	end,
	0
}

COMMANDS.setforcemode = {
	function(ply, args)
		if not ply:IsAdmin() then ply:ChatPrint("You don't have access") return end
		if not args[1] or (not zb:GetMode(args[1]) and args[1]~="random") then return end
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
	 	zb:EndRound()
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
			for key, mode in pairs(zb.modes) do
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

		if !(ply:IsSuperAdmin() or ply:IsAdmin()) and not zb.modes[modeKey]:CanLaunch() then
			ply:ChatPrint("This mode can't launch (No points or Is blocked): " .. modeKey)
			return
		end

		if command == "setmode" then
			NextRound(modeKey)
			ply:ChatPrint("Game mode set to: " .. modeKey)

			if addToQueue then
				table.insert(zb.QueuedModes, modeKey)
				zb.NotifyQueueModified(ply, "added " .. modeKey .. " to")

				zb.SyncQueueToAdmins()
			end
		elseif command == "setforcemode" then
			forcemode = modeKey
			NextRound(forcemode)
			ply:ChatPrint("Force mode set to: " .. modeKey)

			if addToQueue then
				table.insert(zb.QueuedModes, modeKey)
				zb.NotifyQueueModified(ply, "added " .. modeKey .. " to")

				zb.SyncQueueToAdmins()
			end
		end
	end)

	function zb.SyncQueueToAdmins()
		timer.Simple(0.1, function()
			net.Start("ZC_GameQueueSend")
			net.WriteTable(zb.QueuedModes)
			net.Send(zb.GetAllAdmins())
		end)
	end

	net.Receive("ZC_AdminSetGameQueue", function(len, ply)
		if not ply:IsAdmin() then return end

		local modeQueue = net.ReadTable()
		zb.QueuedModes = modeQueue

		if #modeQueue == 0 then
			ply:ChatPrint("Game mode queue has been cleared")
			zb.NotifyQueueModified(ply, "cleared")


			timer.Simple(0.2, function()
				net.Start("ZC_QueueEmptiedNotice")
				net.Send(zb.GetAllAdmins())
			end)
		else
			ply:ChatPrint("Game mode queue set with " .. #modeQueue .. " modes")
			zb.NotifyQueueModified(ply, "updated")
		end

		zb.SyncQueueToAdmins()
	end)

end
