local player_GetAll = player.GetAll

local function DevLog(...)
	if GetConVar("zc_dev") and GetConVar("zc_dev"):GetBool() then
		print("[zc.round]", ...)
	end
end

zc.round = zc.round or {}
zc.round.id = zc.round.id or 0
zc.round.state = zc.round.state or ROUND_WAITING
zc.round.participants = zc.round.participants or {}
zc.round.stateStarted = zc.round.stateStarted or 0

zc.round.IntroTime = 8
zc.round.DefaultMinPlayers = 2

local function SyncLegacyState()
	zc.ROUND_STATE = zc.LegacyRoundState(zc.round.state)
end

util.AddNetworkString("ZC_RoundState")
util.AddNetworkString("ZC_RoundIntro")

local function ResolvedModeName()
	local r = zc.round
	if not r.modeName then return "" end
	return zc:GetMode(r.modeName) or r.modeName
end

local function WriteResult(result)
	if result then
		local winner = result.winner
		net.WriteBool(true)
		net.WriteString(result.reason or "unknown")
		net.WriteEntity(isentity(winner) and IsValid(winner) and winner or NULL)
	else
		net.WriteBool(false)
		net.WriteString("")
		net.WriteEntity(NULL)
	end
end

local function SendRoundState(ply)
	local r = zc.round
	net.Start("ZC_RoundState")
		net.WriteUInt(r.id, 16)
		net.WriteString(ResolvedModeName())
		net.WriteUInt(r.state, 3)
		net.WriteFloat(r.stateStarted or 0)
		net.WriteFloat(r.stateEnds or -1)
		WriteResult(r.result)
	if ply then net.Send(ply) else net.Broadcast() end
end

local function BuildIntroData(mode, ply)
	local src = mode.Intro or {}
	local data = {
		Title = src.Title or mode.PrintName or mode.name,
		Objective = src.Objective,
		Role = src.Role,
		Color = src.Color or Color(190, 15, 15),
		Sound = src.Sound,
	}

	if mode.GetPlayerIntroData then
		local ok, over = pcall(mode.GetPlayerIntroData, mode, ply)
		if ok and istable(over) then
			if over.Role ~= nil then data.Role = over.Role end
			if over.Objective ~= nil then data.Objective = over.Objective end
			if over.Color ~= nil then data.Color = over.Color end
			if over.Title ~= nil then data.Title = over.Title end
			if over.Sound ~= nil then data.Sound = over.Sound end
		elseif not ok then
			ErrorNoHalt("[zc.round] GetPlayerIntroData error: " .. tostring(over) .. "\n")
		end
	end

	if istable(data.Sound) then
		data.Sound = table.Random(data.Sound)
	end

	return data
end

local function SendRoundIntro(ply)
	local r = zc.round
	local mode = r.mode
	if not mode then return end

	local setup = tonumber(mode.SetupTime) or 0
	local introStart = (r.stateStarted or CurTime()) + setup
	local introEnd = introStart + r.IntroTime
	local data = BuildIntroData(mode, ply)

	net.Start("ZC_RoundIntro")
		net.WriteUInt(r.id, 16)
		net.WriteFloat(introStart)
		net.WriteFloat(introEnd)
		net.WriteString(data.Title or "")
		net.WriteString(data.Objective or "")
		net.WriteString(data.Role or "")
		net.WriteColor(data.Color or Color(190, 15, 15))
		net.WriteString(data.Sound or "")
	net.Send(ply)
end

local function SendRoundIntroToAll()
	for _, ply in player.Iterator() do
		SendRoundIntro(ply)
	end
	zc.round.introSent = true
end

local function BroadcastTransition()
	SendRoundState()

	net.Start("ZC_RoundInfo")
		net.WriteString(ResolvedModeName())
		net.WriteInt(zc.LegacyRoundState(zc.round.state), 4)
	net.Broadcast()
end

local function RecordParticipants()
	local list = {}
	for _, ply in player.Iterator() do
		if IsValid(ply) and ply:Team() != TEAM_SPECTATOR and ply:Alive() then
			list[#list + 1] = ply
		end
	end
	zc.round.participants = list
	return list
end

function zc.round.PruneParticipants()
	local list = zc.round.participants
	for i = #list, 1, -1 do
		if not IsValid(list[i]) or list[i]:Team() == TEAM_SPECTATOR then
			table.remove(list, i)
		end
	end
	return list
end

local function GetMinPlayers(mode)
	return tonumber(mode.MinPlayers) or zc.round.DefaultMinPlayers
end

local function HasChangelevelTrigger()
	return zc.HasChangelevelTrigger and zc.HasChangelevelTrigger() or false
end

function zc.round.SelectNextMode()
	if HasChangelevelTrigger() then return "coop" end

	if zc.nextround then
		local chosen = zc.nextround
		zc.nextround = nil
		return chosen
	end

	if #zc.RoundList == 0 then
		zc.RerollChances()
	end

	return table.remove(zc.RoundList, 1) or "hmcd"
end

function zc.round.QueueFollowingMode()
	if zc.nextround then return end

	local forcemode = zc.GetForcemode and zc.GetForcemode() or "random"

	if forcemode ~= "random" then
		zc.nextround = forcemode
		print("Next game mode is " .. forcemode)
		return
	end

	if #zc.RoundList == 0 then
		zc.RerollChances()
	end

	local nextMode = table.remove(zc.RoundList, 1) or "hmcd"
	print("Next game mode is " .. nextMode)
	zc.nextround = nextMode
end

local function CallMode(mode, callback, ...)
	local func = mode and mode[callback]
	if not func then return true end

	local ok, result = pcall(func, mode, ...)
	if not ok then
		ErrorNoHalt("[zc.round] " .. callback .. " error in " .. tostring(mode.name) .. ": " .. tostring(result) .. "\n")
		return false
	end

	return true, result
end

local function CallCheckEnd(mode)
	local ok, result = CallMode(mode, "CheckEnd", zc.round)
	if not ok then return false end
	return true, istable(result) and result or nil
end

local function EnterWaiting(delay)
	local r = zc.round
	r.state = ROUND_WAITING
	r.result = nil
	r.participants = {}
	r.introAt = nil
	r.introSent = false
	r.stateStarted = CurTime()
	r.pendingMode = r.pendingMode or r.SelectNextMode()

	local startDelay = tonumber(delay) or 0
	r.stateEnds = r.stateStarted + startDelay

	SyncLegacyState()
	DevLog("WAITING for " .. math.Round(startDelay, 1) .. "s, next mode: " .. tostring(r.pendingMode))
end

local function CancelPreparation(why)
	local r = zc.round
	if r.state ~= ROUND_PREPARING then return end
	DevLog("Preparation cancelled: " .. tostring(why))
	r.pendingMode = r.modeName
	EnterWaiting(5)
	BroadcastTransition()
end

function zc.round.Prepare(modeName)
	local r = zc.round
	if r.state ~= ROUND_WAITING then
		DevLog("Prepare ignored in state " .. zc.RoundStateName(r.state))
		return false
	end

	modeName = modeName or r.pendingMode or r.SelectNextMode()
	r.pendingMode = nil

	local resolved = zc:GetMode(modeName)
	if not resolved or not zc.modes[resolved] then
		ErrorNoHalt("[zc.round] Unknown mode '" .. tostring(modeName) .. "', falling back to hmcd\n")
		modeName = "hmcd"
		resolved = "hmcd"
	end
	local mode = zc.modes[resolved]

	r.id = r.id + 1
	r.mode = mode
	r.modeName = modeName
	r.result = nil

	zc.CROUND = modeName
	zc.CROUND_MAIN = resolved
	zc.LASTCROUND = modeName

	local now = CurTime()
	local setup = tonumber(mode.SetupTime) or 0
	r.state = ROUND_PREPARING
	r.stateStarted = now
	r.stateEnds = now + setup + r.IntroTime
	r.introAt = now + setup
	r.introSent = false

	hook.Run("ZC_PreRoundStart")
	hook.Run("TTTPrepareRound")

	if mode.shouldfreeze then zc:Freeze() end

	zc.UpdateRoundTime(
		mode.RoundTime or mode.ROUND_TIME or zc.ROUND_TIME,
		now,
		r.stateEnds
	)

	zc:KillPlayers()
	zc:AutoBalance()
	mode.saved = {}

	local prepared = CallMode(mode, "Prepare", r)
	if not prepared then
		r.pendingMode = modeName
		EnterWaiting(5)
		BroadcastTransition()
		return false
	end

	RecordParticipants()

	SyncLegacyState()
	BroadcastTransition()

	if setup <= 0 then SendRoundIntroToAll() end

	DevLog("PREPARING round #" .. r.id .. " (" .. resolved .. ")")
	return true
end

function zc.round.Start()
	local r = zc.round
	if r.state ~= ROUND_PREPARING then
		DevLog("Start ignored in state " .. zc.RoundStateName(r.state))
		return false
	end

	local mode = r.mode
	local now = CurTime()
	if now < (r.stateEnds or 0) then return false end

	RecordParticipants()
	if #r.participants < GetMinPlayers(mode) then
		DevLog("Not enough participants (" .. #r.participants .. "/" .. GetMinPlayers(mode) .. "), waiting")
		CancelPreparation("not enough players")
		return false
	end

	if mode.shouldfreeze then zc:Unfreeze() end

	VFIRE_DISABLED = (ResolvedModeName() == "coop")

	local duration = tonumber(mode.RoundTime or mode.ROUND_TIME) or zc.ROUND_TIME or 300
	zc.UpdateRoundTime(duration, now, now)

	r.state = ROUND_ACTIVE
	r.stateStarted = now
	r.stateEnds = mode.DisableRoundTimer and nil or now + duration
	SyncLegacyState()
	BroadcastTransition()

	zc.AddCurrentModePlayed()

	local started = CallMode(mode, "Start", r)
	if not started then
		r.RequestEnd({ reason = "mode_start_error" })
		return false
	end
	if r.state ~= ROUND_ACTIVE then return true end

	r.QueueFollowingMode()

	if zc.SendRoundListToAllAdmins then zc.SendRoundListToAllAdmins() end

	hook.Run("ZC_StartRound")

	DevLog("ACTIVE round #" .. r.id)
	return true
end

function zc.round.RequestEnd(result)
	local r = zc.round
	if r.state ~= ROUND_ACTIVE then
		DevLog("RequestEnd ignored in state " .. zc.RoundStateName(r.state))
		return false
	end
	if r.result ~= nil then
		DevLog("RequestEnd ignored, round already has a result")
		return false
	end

	r.result = istable(result) and result or { reason = "unknown" }

	zc.Roundscount = (zc.Roundscount or 0) + 1

	local mode = r.mode
	local delay = tonumber(mode.EndTime or mode.end_time) or 5
	local upcoming = zc.nextround
	if zc.HasChangelevelTrigger and zc.HasChangelevelTrigger() then upcoming = "coop" end

	if upcoming == "coop" and GetGlobalVar("coop_first_round_timer", 0) == 0 then
		local dev = GetConVar("zc_dev")
		delay = (dev and dev:GetBool()) and 5 or 60
	end

	zc.SHOULD_FADE = true

	r.state = ROUND_ENDING
	r.stateStarted = CurTime()
	r.stateEnds = r.stateStarted + delay
	if upcoming == "coop" and GetGlobalVar("coop_first_round_timer", 0) == 0 then
		SetGlobalVar("coop_first_round_timer", r.stateEnds)
	end
	SyncLegacyState()
	BroadcastTransition()

	CallMode(mode, "Finish", r, r.result)

	zc.AddFade()
	zc.achievements.SavePlayerAchievements()

	hook.Run("ZC_EndRound")

	DevLog("ENDING round #" .. r.id .. " (" .. tostring(r.result.reason) .. ")")
	return true
end

local function MaybeStartMapVote()
	local dev = GetConVar("zc_dev") and GetConVar("zc_dev"):GetBool()
	local roundCountReachedMapVote = (zc.Roundscount or 0) > 15 and not dev

	local playersCanVote = false
	if not roundCountReachedMapVote then
		playersCanVote = player.GetCount() > 1 and zc.CheckRTVVotes()
	end

	local cstrikeRoundLimitActive = zc.RoundsLeft and zc.CROUND == "cstrike"

	if (roundCountReachedMapVote or playersCanVote) and not cstrikeRoundLimitActive then
		zc.StartRTV(20)
		return true
	end

	return false
end

local function UpdateEnding(now)
	local r = zc.round

	if zc.SHOULD_FADE and (r.stateEnds or 0) < now + 1.5 then
		zc.SHOULD_FADE = false
		for _, ply in player.Iterator() do
			ply:ScreenFade(SCREENFADE.OUT, Color(0, 0, 0), 1, 7)
		end
	end

	if now < (r.stateEnds or 0) then return end

	EnterWaiting()
	BroadcastTransition()
end

local function UpdateActive(now)
	local r = zc.round
	local mode = r.mode

	local thought = CallMode(mode, "Think", r)
	if not thought then
		r.RequestEnd({ reason = "mode_think_error" })
		return
	end

	local timerEnd = (zc.ROUND_START or now) + (zc.ROUND_TIME or 300)
	if not mode.DisableRoundTimer and r.stateEnds ~= timerEnd then
		r.stateEnds = timerEnd
		SendRoundState()
	end

	if not mode.DisableRoundTimer and timerEnd < now then
		if mode.BoringRoundFunction then
			PrintMessage(HUD_PRINTTALK, "Stopping round because it was TOO boring.")
			CallMode(mode, "BoringRoundFunction")
		end
		zc.round.RequestEnd({ reason = "timeout" })
		return
	end

	local checked, result = CallCheckEnd(mode)
	if not checked then
		r.RequestEnd({ reason = "mode_check_error" })
		return
	end
	if result then
		zc.round.RequestEnd(result)
	end
end

function zc.round.Update()
	local r = zc.round
	local now = CurTime()

	if r.state == ROUND_WAITING then
		if MaybeStartMapVote() then return end
		if #player_GetAll() <= 1 then return end

		if not r.stateEnds then
			r.stateEnds = now + 5
			return
		end

		if now < r.stateEnds then return end
		r.Prepare(r.pendingMode)

	elseif r.state == ROUND_PREPARING then
		r.PruneParticipants()
		if not r.introSent and now >= (r.introAt or 0) then
			SendRoundIntroToAll()
		end
		if now >= (r.stateEnds or 0) then
			r.Start()
		end

	elseif r.state == ROUND_ACTIVE then
		UpdateActive(now)

	elseif r.state == ROUND_ENDING then
		UpdateEnding(now)
	end
end

function zc.round.GetCurrent()
	local r = zc.round
	if r.mode then return r.mode, r.modeName end

	local name = zc.CROUND or "hmcd"
	return zc.modes[zc:GetMode(name)], name
end

hook.Add("PlayerDisconnected", "ZC_RoundParticipantLeave", function(ply)
	local r = zc.round
	for i = 1, #r.participants do
		if r.participants[i] == ply then
			table.remove(r.participants, i)
			break
		end
	end
end)

hook.Add("PlayerInitialSpawn", "ZC_RoundStateLateJoin", function(ply)
	SendRoundState(ply)
	if zc.round.state == ROUND_PREPARING and zc.round.introSent then
		SendRoundIntro(ply)
	end
end)

hook.Add("Think", "ZC_RoundControllerThink", function()
	local time = CurTime()
	if (zc.thinkTime or time) > time then return end
	zc.thinkTime = time + 1
	zc.round.Update()
end)
