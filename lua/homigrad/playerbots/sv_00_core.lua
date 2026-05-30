hg = hg or {}
hg.PlayerBots = hg.PlayerBots or {}
local _ENV = hg.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

bit_bor = bit.bor
bit_band = bit.band
bit_bnot = bit.bnot
CurTime = CurTime
IsValid = IsValid
math_abs = math.abs
math_Rand = math.Rand
math_random = math.random
math_min = math.min
math_cos = math.cos
math_rad = math.rad
math_huge = math.huge
math_Clamp = math.Clamp
math_Lerp = Lerp

zc_playerbot_ai = CreateConVar("zc_playerbot_ai", "1", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Enable basic enemy AI for player bots created with the bot command.", 0, 1)
zc_playerbot_debug = CreateConVar("zc_playerbot_debug", "0", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Print player bot AI target/debug messages through DevPrint.", 0, 1)

BOT_THINK_INTERVAL = 0.2
BOT_ATTACK_RANGE = 1800
BOT_MELEE_RANGE = 95
BOT_MELEE_ATTACK_RANGE = 130
BOT_MELEE_ATTACK_STAMINA_FRACTION = 0.2
BOT_CLOSE_RANGE = 170
BOT_STRAFE_RANGE = 700
BOT_RAGDOLL_DEPRIORITIZE_RANGE = 1400
BOT_RAGDOLL_HEAD_AIM_RANGE = 450
BOT_AIM_JITTER = 0.018
BOT_AIM_SPREAD_MIN = 1.2
BOT_AIM_SPREAD_MAX = 7.5
BOT_AIM_LOCK_TIME = 3.5
BOT_AIM_NOISE_INTERVAL = 0.16
BOT_AIM_LOCKED_SPREAD = 0.45
BOT_AIM_BURST_SETTLE_TIME = 1.2
BOT_AIM_OPENING_BURST_SPREAD = 5.5
BOT_AIM_SMOOTH_COMBAT = 0.24
BOT_AIM_SMOOTH_TRAVEL = 0.16
BOT_FAKE_SCAN_TURN_RATE = 155
BOT_FAKE_SCAN_REVERSE_INTERVAL_MIN = 4
BOT_FAKE_SCAN_REVERSE_INTERVAL_MAX = 7
BOT_CQB_MAGDUMP_RANGE = 650
BOT_LONG_RANGE_CONFIDENCE_RANGE = 1100
BOT_LONG_RANGE_MAX_SPREAD = 3.4
BOT_LONG_RANGE_MIN_SIGHT_TIME = 0.55
BOT_AUTO_BURST_TIME = 0.35
BOT_AUTO_BURST_PAUSE = 0.45
BOT_FOV_DEGREES = 180
BOT_FOV_DOT = math_cos(math_rad(BOT_FOV_DEGREES * 0.5))
BOT_CLOSE_AWARENESS_RANGE = 100
BOT_REACTION_MIN = 0.18
BOT_REACTION_MAX = 0.85
BOT_REACTION_DISTANCE = 2400
BOT_ATTACK_PULSE_RELEASE = 0.11
BOT_UNCONSCIOUS_TAP_INTERVAL = 0.65
BOT_COMBAT_RELOAD_SHELLS = 2
BOT_COMBAT_RELOAD_ENEMY_RANGE = 950
BOT_RELOAD_EVADE_DISTANCE = 700
BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE = 260
BOT_VERTICAL_AIM_YAW_DEADZONE = 24
BOT_UNARMED_FLEE_RANGE = 1400
BOT_THREAT_ESCAPE_RANGE = 650
BOT_SUPPRESSION_AWARENESS_DISTANCE = 160
BOT_WEAPON_PICKUP_SCAN_RANGE = 650
BOT_WEAPON_PICKUP_USE_RANGE = 95
BOT_WEAPON_PICKUP_REPATH_RANGE = 120
BOT_COVER_SCORE_PENALTY = 3.5
BOT_VISIBLE_SCORE_MULT = 0.35
BOT_FAKEUP_INITIAL_DELAY = 5
BOT_FAKEUP_INTERVAL = 5
BOT_FAKEUP_COOLDOWN = 5
BOT_HEAL_INTERVAL = 0.35
BOT_THREAT_MEMORY_TIME = 4
BOT_NAV_REPATH_INTERVAL = 0.7
BOT_NAV_WAYPOINT_REACH = 85
BOT_NAV_DEST_REACH = 180
BOT_NAV_MAX_AREAS = 1200
BOT_ROAM_INTERVAL = 4
BOT_ROAM_AREA_SAMPLES = 48
BOT_ROAM_MIN_DISTANCE = 1400
BOT_SPRINT_DISTANCE = 1200
BOT_SPRINT_STAMINA_FRACTION = 0.5
BOT_STUCK_INTERVAL = 1.4
BOT_STUCK_MIN_DISTANCE = 35
BOT_STUCK_JUMP_ATTEMPTS = 3
BOT_UNSTUCK_TIME = 1.1
BOT_UNSTUCK_RETRY_TIME = 0.5
BOT_OBSTACLE_TRACE_DISTANCE = 92
BOT_OBSTACLE_SIDE_PROBE_DISTANCE = 72
BOT_OBSTACLE_BACKOFF_DOT = -0.25
BOT_DOOR_TRACE_DISTANCE = 130
BOT_DOOR_USE_COOLDOWN = 0.75
BOT_ZONE_ROAM_MARGIN = 600
BOT_ZONE_CENTER_TIME = 10
BOT_ZONE_CENTER_REACH = 500
BOT_ZONE_CENTER_SETTLE_RADIUS = 650
BOT_ZONE_CENTER_RESUME_RADIUS = 950
BOT_ZONE_CENTER_BIAS_STEP = 32
BOT_ZONE_CENTER_PATROL_RADIUS = 950
BOT_ZONE_CENTER_PATROL_INTERVAL = 3
BOT_ZONE_CENTER_SHRINK_FRACTION = 0.5
BOT_ZONE_CENTER_GOAL_RADIUS = 700
BOT_ZONE_CENTER_GOAL_INTERVAL = 4
BOT_SAFE_ENEMY_AVOID_RANGE = 1800
BOT_SAFE_ENEMY_AVOID_DEST = 1200

MEDICINE_CLASSES = {
	weapon_bandage_sh = true,
	weapon_bigbandage_sh = true,
	weapon_tourniquet = true,
}

BANDAGE_CLASSES = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
}

SECONDARY_WEAPON_CLASSES = {
	weapon_ab10 = true,
	weapon_browninghp = true,
	weapon_colt9mm = true,
	weapon_cz75 = true,
	weapon_cz75a = true,
	weapon_deagle = true,
	weapon_fn45 = true,
	weapon_glock17 = true,
	weapon_glock18c = true,
	weapon_glock26 = true,
	weapon_hk_usp = true,
	weapon_m1911 = true,
	weapon_m45 = true,
	weapon_m9beretta = true,
	weapon_makarov = true,
	weapon_mac11 = true,
	weapon_mp_80 = true,
	["weapon_mp-80"] = true,
	weapon_osapb = true,
	weapon_p22 = true,
	weapon_pl15 = true,
	weapon_pm9 = true,
	weapon_px4beretta = true,
	weapon_revolver2 = true,
	weapon_revolver357 = true,
	weapon_ruger = true,
	weapon_skorpion = true,
	weapon_taser = true,
	weapon_tec9 = true,
	weapon_tmp = true,
	weapon_tokarev = true,
	weapon_uzi = true,
	weapon_zoraki = true,
}

traceData = {
	mask = MASK_SHOT,
	filter = {},
}

hullTraceData = {
	mask = MASK_PLAYERSOLID,
	filter = {},
}

doorTraceData = {
	mask = MASK_SOLID,
	filter = {},
}

BotCanSee = nil

function BotDevPrint(msg)
	zb.dev.DevPrint(msg)
end

function GetBotAimOrigin(bot)
	if not IsValid(bot) then return vector_origin end

	local wep = GetBotActiveWeapon and GetBotActiveWeapon(bot) or bot.GetActiveWeapon and bot:GetActiveWeapon()
	if IsValid(wep) and wep.GetMuzzleAtt then
		local ok, att = pcall(function()
			return wep:GetMuzzleAtt(nil, true)
		end)

		if ok and istable(att) and isvector(att.Pos) then return att.Pos end
	end

	return bot:EyePos()
end

function GetBotTargetBody(ply)
	if not IsValid(ply) then return NULL end

	local rag = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or IsValid(hg.ragdollFake and hg.ragdollFake[ply]) and hg.ragdollFake[ply] or ply:GetNWEntity("FakeRagdoll")
	if IsValid(rag) then return rag end

	return ply
end

function GetBotTargetBodyPos(ply, body)
	if IsValid(body) and body ~= ply then return body:GetPos() end
	if IsValid(ply) then return ply:GetPos() end

	return vector_origin
end

function GetFakeRagdollOwner(ragdoll)
	if not IsValid(ragdoll) then return NULL end

	local owner = ragdoll:GetNWEntity("ply")
	if not IsValid(owner) then owner = ragdoll.ply end

	return IsValid(owner) and owner or NULL
end

function GetEntityBonePos(ent, boneName)
	if not IsValid(ent) or not ent.LookupBone then return end

	local bone = ent:LookupBone(boneName)
	if bone and ent.IsRagdoll and ent:IsRagdoll() then
		local physBone = ent:TranslateBoneToPhysBone(bone)
		local phys = physBone and ent:GetPhysicsObjectNum(physBone)
		if phys and phys:IsValid() then return phys:GetPos() end
	end

	local matrix = bone and ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end
end

function IsBotInFakeRagdoll(bot)
	if not IsValid(bot) then return false end

	if hg.GetFakeState and hg.FAKE_STATE and hg.GetFakeState(bot) ~= hg.FAKE_STATE.NONE then return true end
	return IsValid(bot.FakeRagdoll) or IsValid(hg.ragdollFake and hg.ragdollFake[bot]) or IsValid(bot:GetNWEntity("FakeRagdoll"))
end

function GetBotFakeRagdollEntity(bot)
	if not IsValid(bot) then return NULL end
	if IsValid(bot.FakeRagdoll) then return bot.FakeRagdoll end
	if IsValid(hg.ragdollFake and hg.ragdollFake[bot]) then return hg.ragdollFake[bot] end
	return bot:GetNWEntity("FakeRagdoll")
end

function GetBotSightOrigin(bot)
	if IsBotInFakeRagdoll(bot) then
		local ragdoll = GetBotFakeRagdollEntity(bot)
		if IsValid(ragdoll) then
			local eyes = ragdoll:LookupAttachment("eyes")
			local att = eyes and ragdoll:GetAttachment(eyes)
			if istable(att) and isvector(att.Pos) then return att.Pos end

			return GetEntityBonePos(ragdoll, "ValveBiped.Bip01_Head1") or ragdoll:WorldSpaceCenter()
		end
	end

	return IsValid(bot) and bot:EyePos() or vector_origin
end

function AddAimCandidate(candidates, pos)
	if not isvector(pos) then return end

	for _, oldPos in ipairs(candidates) do
		if oldPos:DistToSqr(pos) <= 16 then return end
	end

	candidates[#candidates + 1] = pos
end

function AddRagdollPhysicsCandidate(candidates, ent, physNum)
	if not IsValid(ent) or not ent.GetPhysicsObjectNum then return end

	local phys = ent:GetPhysicsObjectNum(physNum)
	if phys and phys:IsValid() then
		AddAimCandidate(candidates, phys:GetPos())
	end
end

function GetTargetAimCandidates(ent, bot)
	local candidates = {}
	if not IsValid(ent) then return candidates end

	if ent:IsPlayer() then
		local body = GetBotTargetBody(ent)
		if IsValid(body) and body ~= ent then
			return GetTargetAimCandidates(body, bot)
		end

		local torsoPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or ent:WorldSpaceCenter()
		AddAimCandidate(candidates, torsoPos)
		AddAimCandidate(candidates, ent:EyePos())

		return candidates
	end

	AddAimCandidate(candidates, ent:WorldSpaceCenter())
	if ent:IsRagdoll() then return candidates end

	local headPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Head1")
	local bodyPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local pelvisPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local closeToRagdoll = headPos and IsValid(bot) and GetBotSightOrigin(bot):DistToSqr(headPos) <= BOT_RAGDOLL_HEAD_AIM_RANGE * BOT_RAGDOLL_HEAD_AIM_RANGE

	if closeToRagdoll then
		AddAimCandidate(candidates, headPos)
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
	else
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
		AddAimCandidate(candidates, headPos)
	end

	return candidates
end

function GetTargetAimPos(ent, bot)
	local candidates = GetTargetAimCandidates(ent, bot)
	if candidates[1] then return candidates[1] end

	return IsValid(ent) and ent:WorldSpaceCenter() or vector_origin
end

BotCanSee = function(bot, body, aimPos)
	traceData.start = GetBotSightOrigin(bot)
	traceData.endpos = aimPos
	traceData.filter[1] = bot
	traceData.filter[2] = GetBotFakeRagdollEntity(bot)
	traceData.filter[3] = GetFakeRagdollOwner(body)

	local tr = util.TraceLine(traceData)
	traceData.filter[3] = nil
	return (not tr.Hit) or tr.Entity == body
end

function IsAimPosInBotFOV(bot, aimPos)
	local toAim = aimPos - GetBotSightOrigin(bot)
	if toAim:LengthSqr() <= 1 then return true end

	toAim:Normalize()
	return bot:EyeAngles():Forward():Dot(toAim) >= BOT_FOV_DOT
end

function BotCanPerceive(bot, body, aimPos)
	local closeAware = IsValid(body) and bot:GetPos():DistToSqr(body:GetPos()) <= BOT_CLOSE_AWARENESS_RANGE * BOT_CLOSE_AWARENESS_RANGE
	return (closeAware or IsAimPosInBotFOV(bot, aimPos)) and BotCanSee(bot, body, aimPos)
end

function GetVisibleTargetAimPos(bot, body)
	local candidates = GetTargetAimCandidates(body, bot)
	local fallback = candidates[1] or GetTargetAimPos(body, bot)

	for _, aimPos in ipairs(candidates) do
		if BotCanPerceive(bot, body, aimPos) then return aimPos, true end
	end

	return fallback, false
end

function GetVisibleTargetAimPosNoFOV(bot, body)
	local candidates = GetTargetAimCandidates(body, bot)
	local fallback = candidates[1] or GetTargetAimPos(body, bot)

	for _, aimPos in ipairs(candidates) do
		if BotCanSee(bot, body, aimPos) then return aimPos, true end
	end

	return fallback, false
end

function SetBotViewAngles(bot, cmd, aimAng, smooth)
	smooth = smooth or BOT_AIM_SMOOTH_TRAVEL
	local current = bot:EyeAngles()
	local viewAng = LerpAngle(math_Clamp(smooth, 0, 1), current, aimAng)

	cmd:SetViewAngles(viewAng)
	bot:SetEyeAngles(viewAng)
	return viewAng
end

function GetTargetTorsoPos(ent)
	if not IsValid(ent) then return end

	if ent:IsPlayer() then
		local body = GetBotTargetBody(ent)
		if IsValid(body) and body ~= ent then
			return GetTargetTorsoPos(body)
		end

		return GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or ent:WorldSpaceCenter()
	end

	return GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis") or ent:WorldSpaceCenter()
end

function IsTargetInCover(bot, body)
	if not IsValid(body) then return false end

	local torsoPos = GetTargetTorsoPos(body)
	if not torsoPos or BotCanSee(bot, body, torsoPos) then return false end

	local headPos = GetEntityBonePos(body, "ValveBiped.Bip01_Head1") or (body:IsPlayer() and body:EyePos())
	return headPos and BotCanSee(bot, body, headPos)
end

function IsUsableTarget(bot, ply)
	if ply == bot or not IsValid(ply) or not ply:Alive() then return false end
	if ply:Team() == TEAM_SPECTATOR and (not ply.IsBot or not ply:IsBot()) then return false end

	return IsValid(GetBotTargetBody(ply))
end

function IsUnconsciousTarget(ply)
	return IsValid(ply) and ply:Alive() and ply.organism and ply.organism.unconscious
end

function IsRagdolledTarget(ply)
	if not IsValid(ply) then return false end
	if IsValid(ply.FakeRagdoll) then return true end
	if IsValid(hg.ragdollFake and hg.ragdollFake[ply]) then return true end

	return IsValid(ply:GetNWEntity("FakeRagdoll"))
end

function IsUprightThreat(ply)
	return IsUsableTarget(nil, ply) and not IsUnconsciousTarget(ply) and not IsRagdolledTarget(ply)
end

function HasNearbyUprightEnemy(bot, ignoreTarget)
	local botPos = bot:GetPos()
	local rangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	for _, ply in ipairs(player.GetAll()) do
		if ply == ignoreTarget or not IsUprightThreat(ply) then continue end
		if botPos:DistToSqr(ply:GetPos()) <= rangeSqr then return true end
	end

	return false
end

function PickBotTarget(bot)
	local bestPly
	local bestScore = math.huge

	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end
		local unconscious = IsUnconsciousTarget(ply)
		if unconscious and HasNearbyUprightEnemy(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local aimPos, visible = GetVisibleTargetAimPos(bot, body)
		if not visible then continue end

		local distSqr = bot:GetPos():DistToSqr(aimPos)
		local score = distSqr * BOT_VISIBLE_SCORE_MULT
		if IsTargetInCover(bot, body) then
			score = score * BOT_COVER_SCORE_PENALTY
		end

		if IsRagdolledTarget(ply) and HasNearbyUprightEnemy(bot, ply) then
			score = score * 10
		end

		if unconscious then
			score = score * 25
		elseif not IsRagdolledTarget(ply) then
			score = score * 0.05
		end

		if score < bestScore then
			bestScore = score
			bestPly = ply
		end
	end

	return bestPly
end

function PickBotFakeTarget(bot)
	local bestPly
	local bestScore = math.huge

	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local aimPos, visible = GetVisibleTargetAimPosNoFOV(bot, body)
		if not visible then continue end

		local distSqr = bot:GetPos():DistToSqr(aimPos)
		local score = distSqr

		if IsTargetInCover(bot, body) then
			score = score * BOT_COVER_SCORE_PENALTY
		end

		if IsUnconsciousTarget(ply) then
			score = score * 25
		elseif not IsRagdolledTarget(ply) then
			score = score * 0.05
		end

		if score < bestScore then
			bestScore = score
			bestPly = ply
		end
	end

	return bestPly
end

function HasVisibleEnemy(bot)
	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local _, visible = GetVisibleTargetAimPos(bot, body)
		if visible then return true end
	end

	return false
end

function CanCurrentlyTarget(bot, ply)
	if not IsUsableTarget(bot, ply) then return false end

	local body = GetBotTargetBody(ply)
	local _, visible = GetVisibleTargetAimPos(bot, body)
	return visible
end

function CanCurrentlyFakeTarget(bot, ply)
	if not IsUsableTarget(bot, ply) then return false end

	local body = GetBotTargetBody(ply)
	local _, visible = GetVisibleTargetAimPosNoFOV(bot, body)
	return visible
end

