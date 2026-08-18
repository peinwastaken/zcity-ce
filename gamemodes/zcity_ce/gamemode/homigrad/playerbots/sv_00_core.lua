zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
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

local CurTime, IsValid = CurTime, IsValid
local math_cos, math_rad, math_Clamp = math_cos, math_rad, math_Clamp
local LerpAngle = LerpAngle
local isvector, istable = isvector, istable
local ipairs, select, setmetatable = ipairs, select, setmetatable
local player, engine, util = player, engine, util

zc_playerbot_ai = CreateConVar("zc_playerbot_ai", "1", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Enable basic enemy AI for player bots created with the bot command.", 0, 1)
zc_playerbot_debug = CreateConVar("zc_playerbot_debug", "0", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Print player bot AI target/debug messages through DevPrint.", 0, 1)

BOT_THINK_INTERVAL = 0.2
BOT_TARGET_TRACK_INTERVAL = 0.1
BOT_TARGET_SCAN_STAGGER_STEPS = 5
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
BOT_FAKEUP_INITIAL_DELAY = 5
BOT_FAKEUP_INTERVAL = 5
BOT_FAKEUP_COOLDOWN = 5
BOT_HEAL_INTERVAL = 0.35
BOT_THREAT_MEMORY_TIME = 4
BOT_ROUND_FADEIN_TIME = 7.5
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

PlayerBotRegistry = PlayerBotRegistry or setmetatable({}, {__mode = "k"})
local cachedPlayerCandidates = {}
local cachedPlayerCandidatesTick = -1

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

local function ProtectedGetMuzzleAtt(wep)
	return wep:GetMuzzleAtt(nil, true)
end

function BotDevPrint(msg, ...)
	if not zc_playerbot_debug:GetBool() then return end
	if select("#", ...) > 0 then
		msg = string.format(msg, ...)
	end

	zc.dev.DevPrint(msg)
end

function RegisterPlayerBot(bot)
	if IsValid(bot) and bot:IsPlayer() and bot:IsBot() then
		PlayerBotRegistry[bot] = true
	end
end

function UnregisterPlayerBot(bot)
	PlayerBotRegistry[bot] = nil
end

function GetBotPlayerCandidates()
	local tick = engine.TickCount()
	if cachedPlayerCandidatesTick ~= tick then
		cachedPlayerCandidates = player.GetAll()
		cachedPlayerCandidatesTick = tick
	end

	return cachedPlayerCandidates
end

function BeginBotCommandContext(bot, round, now)
	RegisterPlayerBot(bot)
	now = now or CurTime()

	bot.ZCBotCommandGeneration = (bot.ZCBotCommandGeneration or 0) + 1
	bot.ZCBotCommandTick = engine.TickCount()
	bot.ZCBotCommandNow = now
	bot.ZCBotCommandRound = round
	bot.ZCBotCommandRoundResolved = true
	bot.ZCBotCommandSightOrigin = nil
	bot.ZCBotCommandEyeForward = nil
	bot.ZCBotCommandPos = nil
	bot.ZCBotCommandFakeRagdoll = nil
	bot.ZCBotCommandFakeRagdollResolved = false
	bot.ZCBotCommandAimOrigin = nil
	bot.ZCBotCommandAimWeapon = nil

	if bot.ZCBotNextTargetScan == nil then
		local steps = math.max(BOT_TARGET_SCAN_STAGGER_STEPS or 1, 1)
		local phase = (bot:EntIndex() % steps) * BOT_THINK_INTERVAL / steps
		bot.ZCBotNextTargetScan = now + phase
		bot.ZCBotNextTargetTrack = now + phase * 0.5
	end

	return now
end

function IsBotCommandContextCurrent(bot)
	return IsValid(bot) and bot.ZCBotCommandTick == engine.TickCount()
end

function GetBotCommandNow(bot)
	if IsBotCommandContextCurrent(bot) then
		return bot.ZCBotCommandNow or CurTime()
	end
	return CurTime()
end

function GetBotCommandRound(bot)
	if IsBotCommandContextCurrent(bot) and bot.ZCBotCommandRoundResolved then
		return bot.ZCBotCommandRound
	end
	return GetCurrentRound and GetCurrentRound() or nil
end

function GetBotAimOrigin(bot, forceRefresh)
	if not IsValid(bot) then return vector_origin end

	local contextCurrent = IsBotCommandContextCurrent(bot)
	local wep = GetBotActiveWeapon and GetBotActiveWeapon(bot) or bot.GetActiveWeapon and bot:GetActiveWeapon()
	if contextCurrent and not forceRefresh and bot.ZCBotCommandAimWeapon == wep and isvector(bot.ZCBotCommandAimOrigin) then
		return bot.ZCBotCommandAimOrigin
	end

	if IsValid(wep) and wep.GetMuzzleAtt then
		local ok, att = pcall(ProtectedGetMuzzleAtt, wep)

		if ok and istable(att) and isvector(att.Pos) then
			if contextCurrent then
				bot.ZCBotCommandAimWeapon = wep
				bot.ZCBotCommandAimOrigin = att.Pos
			end
			return att.Pos
		end
	end

	local eyePos = bot:EyePos()
	if contextCurrent then
		bot.ZCBotCommandAimWeapon = wep
		bot.ZCBotCommandAimOrigin = eyePos
	end
	return eyePos
end

function GetBotTargetBody(ply)
	if not IsValid(ply) then return NULL end
	local tick = engine.TickCount()
	if ply.ZCBotTargetBodyCacheTick == tick then
		return ply.ZCBotTargetBodyCache or NULL
	end

	local rag = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or IsValid(zc.ragdollFake and zc.ragdollFake[ply]) and zc.ragdollFake[ply] or ply:GetNWEntity("FakeRagdoll")
	local body = IsValid(rag) and rag or ply
	ply.ZCBotTargetBodyCacheTick = tick
	ply.ZCBotTargetBodyCache = body
	return body
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

	local model = ent.GetModel and ent:GetModel() or ""
	if ent.ZCBotBoneCacheModel ~= model then
		ent.ZCBotBoneCacheModel = model
		ent.ZCBotBoneCache = {}
		ent.ZCBotBonePosCache = nil
		ent.ZCBotBonePosCacheTick = nil
	end

	local tick = engine.TickCount()
	if ent.ZCBotBonePosCacheTick ~= tick then
		ent.ZCBotBonePosCacheTick = tick
		ent.ZCBotBonePosCache = {}
	end

	local posCache = ent.ZCBotBonePosCache
	local cachedPos = posCache[boneName]
	if cachedPos ~= nil then return cachedPos ~= false and cachedPos or nil end

	local boneCache = ent.ZCBotBoneCache
	local bone = boneCache and boneCache[boneName]
	if bone == nil then
		bone = ent:LookupBone(boneName)
		if boneCache then boneCache[boneName] = bone or false end
	elseif bone == false then
		bone = nil
	end

	if bone and ent.IsRagdoll and ent:IsRagdoll() then
		local physBone = ent:TranslateBoneToPhysBone(bone)
		local phys = physBone and ent:GetPhysicsObjectNum(physBone)
		if phys and phys:IsValid() then
			local pos = phys:GetPos()
			posCache[boneName] = pos
			return pos
		end
	end

	local matrix = bone and ent:GetBoneMatrix(bone)
	if matrix then
		local pos = matrix:GetTranslation()
		posCache[boneName] = pos
		return pos
	end

	posCache[boneName] = false
end

function IsBotInFakeRagdoll(bot)
	if not IsValid(bot) then return false end

	if zc.GetFakeState and zc.FAKE_STATE and zc.GetFakeState(bot) ~= zc.FAKE_STATE.NONE then return true end
	return IsValid(bot.FakeRagdoll) or IsValid(zc.ragdollFake and zc.ragdollFake[bot]) or IsValid(bot:GetNWEntity("FakeRagdoll"))
end

function GetBotFakeRagdollEntity(bot)
	if not IsValid(bot) then return NULL end
	local commandContextCurrent = bot.ZCBotCommandTick == engine.TickCount()
	if commandContextCurrent and bot.ZCBotCommandFakeRagdollResolved then return bot.ZCBotCommandFakeRagdoll or NULL end

	local ragdoll
	if IsValid(bot.FakeRagdoll) then
		ragdoll = bot.FakeRagdoll
	elseif IsValid(zc.ragdollFake and zc.ragdollFake[bot]) then
		ragdoll = zc.ragdollFake[bot]
	else
		ragdoll = bot:GetNWEntity("FakeRagdoll")
	end

	if commandContextCurrent then
		bot.ZCBotCommandFakeRagdoll = ragdoll
		bot.ZCBotCommandFakeRagdollResolved = true
	end

	return ragdoll
end

function GetBotSightOrigin(bot)
	local contextCurrent = IsBotCommandContextCurrent(bot)
	if contextCurrent and isvector(bot.ZCBotCommandSightOrigin) then return bot.ZCBotCommandSightOrigin end

	local origin
	if IsBotInFakeRagdoll(bot) then
		local ragdoll = GetBotFakeRagdollEntity(bot)
		if IsValid(ragdoll) then
			local eyes = ragdoll:LookupAttachment("eyes")
			local att = eyes and ragdoll:GetAttachment(eyes)
			if istable(att) and isvector(att.Pos) then
				origin = att.Pos
			else
				origin = GetEntityBonePos(ragdoll, "ValveBiped.Bip01_Head1") or ragdoll:WorldSpaceCenter()
			end

			if contextCurrent then bot.ZCBotCommandSightOrigin = origin end
			return origin
		end
	end

	origin = IsValid(bot) and bot:EyePos() or vector_origin
	if contextCurrent then bot.ZCBotCommandSightOrigin = origin end
	return origin
end

local function GetBotPerceptionEntry(bot, body)
	if not IsBotCommandContextCurrent(bot) or not IsValid(body) or not bot.ZCBotCommandGeneration then return end

	local cache = bot.ZCBotPerceptionCache
	if not cache then
		cache = setmetatable({}, {__mode = "k"})
		bot.ZCBotPerceptionCache = cache
	end

	local entry = cache[body]
	if not entry then
		entry = {}
		cache[body] = entry
	end

	local generation = bot.ZCBotCommandGeneration
	if entry.generation ~= generation then
		entry.generation = generation
		entry.candidates = nil
		entry.los = nil
		entry.closeAware = nil
		entry.visibleAimPos = nil
		entry.visibleResolved = false
		entry.noFOVAimPos = nil
		entry.noFOVResolved = false
		entry.cover = nil
		entry.fakeOwner = nil
		entry.fakeOwnerResolved = false
	end

	return entry
end

function StoreBotTargetPerception(bot, target, body, aimPos, visible, noFOV, expiresAt, anyVisible)
	local now = GetBotCommandNow(bot)
	bot.ZCBotPerceptionTarget = target
	bot.ZCBotPerceptionBody = body
	bot.ZCBotPerceptionAimPos = aimPos
	bot.ZCBotPerceptionVisible = visible == true
	bot.ZCBotPerceptionNoFOV = noFOV == true
	bot.ZCBotPerceptionUntil = expiresAt or (now + BOT_THINK_INTERVAL)
	if anyVisible ~= nil then
		bot.ZCBotHasVisibleEnemy = anyVisible == true
		bot.ZCBotVisibleEnemyUntil = math.max(bot.ZCBotPerceptionUntil, now + BOT_THINK_INTERVAL)
	end
end

function ClearBotTargetPerception(bot)
	bot.ZCBotPerceptionTarget = nil
	bot.ZCBotPerceptionBody = nil
	bot.ZCBotPerceptionAimPos = nil
	bot.ZCBotPerceptionVisible = false
	bot.ZCBotPerceptionNoFOV = false
	bot.ZCBotPerceptionUntil = 0
	bot.ZCBotHasVisibleEnemy = nil
	bot.ZCBotVisibleEnemyUntil = 0
end

local function GetStoredBotTargetPerception(bot, body, noFOV)
	if not IsValid(bot) or bot.ZCBotRefreshingPerception then return end
	if bot.ZCBotPerceptionBody ~= body then return end
	if (bot.ZCBotPerceptionUntil or 0) <= GetBotCommandNow(bot) then return end
	if not noFOV and bot.ZCBotPerceptionNoFOV then return end
	if noFOV and not bot.ZCBotPerceptionNoFOV and not bot.ZCBotPerceptionVisible then return end

	return bot.ZCBotPerceptionAimPos, bot.ZCBotPerceptionVisible, true
end

function AddAimCandidate(candidates, pos)
	if not isvector(pos) then return end

	for _, oldPos in ipairs(candidates) do
		if oldPos:DistToSqr(pos) <= 16 then return end
	end

	candidates[#candidates + 1] = pos
end

function GetTargetAimCandidates(ent, bot)
	local cacheEntry = IsValid(bot) and GetBotPerceptionEntry(bot, ent)
	if cacheEntry and cacheEntry.candidates then return cacheEntry.candidates end

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

		if cacheEntry then cacheEntry.candidates = candidates end
		return candidates
	end

	local headPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Head1")
	local bodyPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local pelvisPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local closeToRagdoll = headPos and IsValid(bot) and GetBotSightOrigin(bot):DistToSqr(headPos) <= BOT_RAGDOLL_HEAD_AIM_RANGE * BOT_RAGDOLL_HEAD_AIM_RANGE

	if ent:IsRagdoll() and closeToRagdoll then
		AddAimCandidate(candidates, headPos)
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
		AddAimCandidate(candidates, ent:WorldSpaceCenter())
	elseif ent:IsRagdoll() then
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
		AddAimCandidate(candidates, headPos)
		AddAimCandidate(candidates, ent:WorldSpaceCenter())
	else
		AddAimCandidate(candidates, ent:WorldSpaceCenter())
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
		AddAimCandidate(candidates, headPos)
	end

	if cacheEntry then cacheEntry.candidates = candidates end
	return candidates
end

function GetTargetAimPos(ent, bot)
	local candidates = GetTargetAimCandidates(ent, bot)
	if candidates[1] then return candidates[1] end

	return IsValid(ent) and ent:WorldSpaceCenter() or vector_origin
end

BotCanSee = function(bot, body, aimPos)
	local cacheEntry = GetBotPerceptionEntry(bot, body)
	if cacheEntry and cacheEntry.los then
		for _, cached in ipairs(cacheEntry.los) do
			if cached.pos:DistToSqr(aimPos) <= 1 then return cached.visible end
		end
	end

	traceData.start = GetBotSightOrigin(bot)
	traceData.endpos = aimPos
	traceData.filter[1] = bot
	traceData.filter[2] = GetBotFakeRagdollEntity(bot)
	if cacheEntry and cacheEntry.fakeOwnerResolved then
		traceData.filter[3] = cacheEntry.fakeOwner
	else
		traceData.filter[3] = GetFakeRagdollOwner(body)
		if cacheEntry then
			cacheEntry.fakeOwner = traceData.filter[3]
			cacheEntry.fakeOwnerResolved = true
		end
	end

	local tr = util.TraceLine(traceData)
	traceData.filter[3] = nil
	local visible = (not tr.Hit) or tr.Entity == body
	if cacheEntry then
		cacheEntry.los = cacheEntry.los or {}
		cacheEntry.los[#cacheEntry.los + 1] = {pos = aimPos, visible = visible}
	end

	return visible
end

function IsAimPosInBotFOV(bot, aimPos)
	local toAim = aimPos - GetBotSightOrigin(bot)
	if toAim:LengthSqr() <= 1 then return true end

	toAim:Normalize()
	local contextCurrent = IsBotCommandContextCurrent(bot)
	local forward = contextCurrent and bot.ZCBotCommandEyeForward
	if not isvector(forward) then
		forward = bot:EyeAngles():Forward()
		if contextCurrent then bot.ZCBotCommandEyeForward = forward end
	end

	return forward:Dot(toAim) >= BOT_FOV_DOT
end

function BotCanPerceive(bot, body, aimPos)
	local cacheEntry = GetBotPerceptionEntry(bot, body)
	local closeAware = cacheEntry and cacheEntry.closeAware
	if closeAware == nil then
		local contextCurrent = IsBotCommandContextCurrent(bot)
		local botPos = contextCurrent and bot.ZCBotCommandPos
		if not isvector(botPos) then
			botPos = bot:GetPos()
			if contextCurrent then bot.ZCBotCommandPos = botPos end
		end

		closeAware = IsValid(body) and botPos:DistToSqr(body:GetPos()) <= BOT_CLOSE_AWARENESS_RANGE * BOT_CLOSE_AWARENESS_RANGE
		if cacheEntry then cacheEntry.closeAware = closeAware end
	end

	return (closeAware or IsAimPosInBotFOV(bot, aimPos)) and BotCanSee(bot, body, aimPos)
end

function GetVisibleTargetAimPos(bot, body)
	local storedAimPos, storedVisible, stored = GetStoredBotTargetPerception(bot, body, false)
	if stored then return storedAimPos, storedVisible end

	local cacheEntry = GetBotPerceptionEntry(bot, body)
	if cacheEntry and cacheEntry.visibleResolved then return cacheEntry.visibleAimPos, cacheEntry.visible == true end

	local candidates = GetTargetAimCandidates(body, bot)
	local fallback = candidates[1] or GetTargetAimPos(body, bot)

	for _, aimPos in ipairs(candidates) do
		if BotCanPerceive(bot, body, aimPos) then
			if cacheEntry then
				cacheEntry.visibleResolved = true
				cacheEntry.visibleAimPos = aimPos
				cacheEntry.visible = true
			end
			return aimPos, true
		end
	end

	if cacheEntry then
		cacheEntry.visibleResolved = true
		cacheEntry.visibleAimPos = fallback
		cacheEntry.visible = false
	end
	return fallback, false
end

function GetVisibleTargetAimPosNoFOV(bot, body)
	local storedAimPos, storedVisible, stored = GetStoredBotTargetPerception(bot, body, true)
	if stored then return storedAimPos, storedVisible end

	local cacheEntry = GetBotPerceptionEntry(bot, body)
	if cacheEntry and cacheEntry.visibleResolved and cacheEntry.visible then return cacheEntry.visibleAimPos, true end
	if cacheEntry and cacheEntry.noFOVResolved then return cacheEntry.noFOVAimPos, cacheEntry.noFOVVisible == true end

	local candidates = GetTargetAimCandidates(body, bot)
	local fallback = candidates[1] or GetTargetAimPos(body, bot)

	for _, aimPos in ipairs(candidates) do
		if BotCanSee(bot, body, aimPos) then
			if cacheEntry then
				cacheEntry.noFOVResolved = true
				cacheEntry.noFOVAimPos = aimPos
				cacheEntry.noFOVVisible = true
			end
			return aimPos, true
		end
	end

	if cacheEntry then
		cacheEntry.noFOVResolved = true
		cacheEntry.noFOVAimPos = fallback
		cacheEntry.noFOVVisible = false
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
	local cacheEntry = GetBotPerceptionEntry(bot, body)
	if cacheEntry and cacheEntry.cover ~= nil then return cacheEntry.cover end

	local torsoPos = GetTargetTorsoPos(body)
	if not torsoPos or BotCanSee(bot, body, torsoPos) then
		if cacheEntry then cacheEntry.cover = false end
		return false
	end

	local headPos = GetEntityBonePos(body, "ValveBiped.Bip01_Head1") or (body:IsPlayer() and body:EyePos())
	local inCover = headPos and BotCanSee(bot, body, headPos) or false
	if cacheEntry then cacheEntry.cover = inCover end
	return inCover
end

function GetBotTeamId(ply, round)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	round = round or GetCurrentRound()
	if round and round.GetBotTeamId then return round:GetBotTeamId(ply) end
	if round and round.GetBotTeam then return round:GetBotTeam(ply) end

	if round and round.name == "dm" then return end
	if round and round.name == "hmcd" then return ply.isTraitor and "traitor" or "innocent" end

	local teamID = ply:Team()
	if teamID == TEAM_SPECTATOR or teamID == TEAM_UNASSIGNED then return end
	return teamID
end

function IsBotTeammate(bot, ply, round)
	if not IsValid(bot) or not IsValid(ply) or not bot:IsPlayer() or not ply:IsPlayer() then return false end
	if bot == ply then return true end

	if round == nil then round = GetBotCommandRound(bot) end
	local contextCurrent = IsBotCommandContextCurrent(bot)
	local cache
	local cached
	if contextCurrent then
		cache = bot.ZCBotTeammateCache
		if not cache then
			cache = setmetatable({}, {__mode = "k"})
			bot.ZCBotTeammateCache = cache
		end

		cached = cache[ply]
		if cached and cached.generation == bot.ZCBotCommandGeneration and cached.round == round then
			return cached.value
		end
	end

	local teammate
	if round and round.IsBotTeammate then
		teammate = round:IsBotTeammate(bot, ply)
	else
		local botTeam = GetBotTeamId(bot, round)
		local targetTeam = GetBotTeamId(ply, round)
		teammate = botTeam ~= nil and botTeam == targetTeam
	end

	if cache then
		cached = cached or {}
		cached.generation = bot.ZCBotCommandGeneration
		cached.round = round
		cached.value = teammate
		cache[ply] = cached
	end
	return teammate
end

function IsUsableTarget(bot, ply, round)
	if ply == bot or not IsValid(ply) or not ply:Alive() then return false end
	if ply:Team() == TEAM_SPECTATOR and (not ply.IsBot or not ply:IsBot()) then return false end
	if IsBotTeammate(bot, ply, round) then return false end

	return IsValid(GetBotTargetBody(ply))
end

function IsUnconsciousTarget(ply)
	return IsValid(ply) and ply:Alive() and ply.organism and ply.organism.unconscious
end

function IsRagdolledTarget(ply)
	if not IsValid(ply) then return false end
	local body = GetBotTargetBody(ply)
	return IsValid(body) and body ~= ply
end

function IsUprightThreat(bot, ply, round)
	return IsUsableTarget(bot, ply, round) and not IsUnconsciousTarget(ply) and not IsRagdolledTarget(ply)
end

function HasNearbyUprightEnemy(bot, ignoreTarget, round, players)
	local contextCurrent = IsBotCommandContextCurrent(bot)
	local botPos = contextCurrent and bot.ZCBotCommandPos or bot:GetPos()
	if contextCurrent then bot.ZCBotCommandPos = botPos end
	local rangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	players = players or GetBotPlayerCandidates()
	for _, ply in ipairs(players) do
		if ply == ignoreTarget or not IsUprightThreat(bot, ply, round) then continue end
		if botPos:DistToSqr(ply:GetPos()) <= rangeSqr then return true end
	end

	return false
end

function PickBotTarget(bot, round)
	local bestPly
	local bestBody
	local bestAimPos
	local bestScore = math.huge
	local anyVisible = false
	local players = GetBotPlayerCandidates()
	local usablePlayers = {}
	local hasNearbyUpright = false
	local contextCurrent = IsBotCommandContextCurrent(bot)
	local botPos = contextCurrent and bot.ZCBotCommandPos or bot:GetPos()
	if contextCurrent then bot.ZCBotCommandPos = botPos end
	local nearbyRangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	for _, ply in ipairs(players) do
		if not IsUsableTarget(bot, ply, round) then continue end
		usablePlayers[#usablePlayers + 1] = ply
		if not hasNearbyUpright and not IsUnconsciousTarget(ply) and not IsRagdolledTarget(ply)
			and botPos:DistToSqr(ply:GetPos()) <= nearbyRangeSqr then
			hasNearbyUpright = true
		end
	end

	for _, ply in ipairs(usablePlayers) do
		local unconscious = IsUnconsciousTarget(ply)

		local body = GetBotTargetBody(ply)
		local aimPos, visible = GetVisibleTargetAimPos(bot, body)
		if not visible then continue end
		anyVisible = true
		if unconscious and hasNearbyUpright then continue end

		local distSqr = botPos:DistToSqr(aimPos)
		local score = distSqr
		if IsTargetInCover(bot, body) then
			score = score * BOT_COVER_SCORE_PENALTY
		end

		if IsRagdolledTarget(ply) and hasNearbyUpright then
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
			bestBody = body
			bestAimPos = aimPos
		end
	end

	return bestPly, bestBody, bestAimPos, anyVisible
end

function PickBotFakeTarget(bot, round)
	local bestPly
	local bestBody
	local bestAimPos
	local bestScore = math.huge
	local anyVisible = false
	local contextCurrent = IsBotCommandContextCurrent(bot)
	local botPos = contextCurrent and bot.ZCBotCommandPos or bot:GetPos()
	if contextCurrent then bot.ZCBotCommandPos = botPos end

	for _, ply in ipairs(GetBotPlayerCandidates()) do
		if not IsUsableTarget(bot, ply, round) then continue end

		local body = GetBotTargetBody(ply)
		local aimPos, visible = GetVisibleTargetAimPosNoFOV(bot, body)
		if not visible then continue end
		anyVisible = true

		local distSqr = botPos:DistToSqr(aimPos)
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
			bestBody = body
			bestAimPos = aimPos
		end
	end

	return bestPly, bestBody, bestAimPos, anyVisible
end

function HasVisibleEnemy(bot, round)
	local now = GetBotCommandNow(bot)
	if (bot.ZCBotVisibleEnemyUntil or 0) > now and bot.ZCBotHasVisibleEnemy ~= nil then
		return bot.ZCBotHasVisibleEnemy
	end

	for _, ply in ipairs(GetBotPlayerCandidates()) do
		if not IsUsableTarget(bot, ply, round) then continue end

		local body = GetBotTargetBody(ply)
		local _, visible = GetVisibleTargetAimPos(bot, body)
		if visible then
			bot.ZCBotHasVisibleEnemy = true
			bot.ZCBotVisibleEnemyUntil = now + BOT_TARGET_TRACK_INTERVAL
			return true
		end
	end

	bot.ZCBotHasVisibleEnemy = false
	bot.ZCBotVisibleEnemyUntil = now + BOT_THINK_INTERVAL
	return false
end

function CanCurrentlyTarget(bot, ply, round)
	if not IsUsableTarget(bot, ply, round) then return false end
	local body = GetBotTargetBody(ply)
	if bot.ZCBotPerceptionTarget == ply and bot.ZCBotPerceptionBody == body and (bot.ZCBotPerceptionUntil or 0) > GetBotCommandNow(bot) then
		return bot.ZCBotPerceptionVisible == true and not bot.ZCBotPerceptionNoFOV
	end

	local _, visible = GetVisibleTargetAimPos(bot, body)
	return visible
end

function CanCurrentlyFakeTarget(bot, ply, round)
	if not IsUsableTarget(bot, ply, round) then return false end
	local body = GetBotTargetBody(ply)
	if bot.ZCBotPerceptionTarget == ply and bot.ZCBotPerceptionBody == body and (bot.ZCBotPerceptionUntil or 0) > GetBotCommandNow(bot) then
		return bot.ZCBotPerceptionVisible == true
	end

	local _, visible = GetVisibleTargetAimPosNoFOV(bot, body)
	return visible
end

