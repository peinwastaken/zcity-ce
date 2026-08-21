zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local math_cos, math_rad = math.cos, math.rad
local ipairs, istable, isvector, setmetatable = ipairs, istable, isvector, setmetatable
local engine, util = engine, util

local BOT_FOV_DEGREES = 180
local BOT_FOV_DOT = math_cos(math_rad(BOT_FOV_DEGREES * 0.5))
local BOT_CLOSE_AWARENESS_RANGE = 100
local BOT_COVER_SCORE_PENALTY = 3.5
local BOT_RAGDOLL_DEPRIORITIZE_RANGE = 1400
local BOT_RAGDOLL_HEAD_AIM_RANGE = 450
local BOT_THREAT_MEMORY_TIME = 4
-- How long a lost target's last known position stays worth searching.
local BOT_TARGET_MEMORY_TIME = 4

local function ProtectedGetMuzzleAtt(wep)
	return wep:GetMuzzleAtt(nil, true)
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

	local state = bot.ZCBotAI
	local command = state and state.command
	if command and command.tick == engine.TickCount() and command.fakeRagdollResolved then
		return command.fakeRagdoll or NULL
	end

	local ragdoll
	if IsValid(bot.FakeRagdoll) then
		ragdoll = bot.FakeRagdoll
	elseif IsValid(zc.ragdollFake and zc.ragdollFake[bot]) then
		ragdoll = zc.ragdollFake[bot]
	else
		ragdoll = bot:GetNWEntity("FakeRagdoll")
	end

	if command and command.tick == engine.TickCount() then
		command.fakeRagdoll = ragdoll
		command.fakeRagdollResolved = true
	end

	return ragdoll
end

function GetBotSightOrigin(bot)
	local state = bot.ZCBotAI
	local command = state and state.command
	if command and command.tick == engine.TickCount() and isvector(command.sightOrigin) then
		return command.sightOrigin
	end

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

			if command then command.sightOrigin = origin end
			return origin
		end
	end

	origin = IsValid(bot) and bot:EyePos() or vector_origin
	if command then command.sightOrigin = origin end
	return origin
end

function GetBotAimOrigin(bot, forceRefresh)
	if not IsValid(bot) then return vector_origin end

	local state = bot.ZCBotAI
	local command = state and state.command
	local contextCurrent = command and command.tick == engine.TickCount()

	if contextCurrent and not forceRefresh and command.aimWeapon == GetBotActiveWeapon(bot) and isvector(command.aimOrigin) then
		return command.aimOrigin
	end

	local wep = GetBotActiveWeapon(bot)
	if IsValid(wep) and wep.GetMuzzleAtt then
		local ok, att = pcall(ProtectedGetMuzzleAtt, wep)

		if ok and istable(att) and isvector(att.Pos) then
			if contextCurrent then
				command.aimWeapon = wep
				command.aimOrigin = att.Pos
			end
			return att.Pos
		end
	end

	local eyePos = bot:EyePos()
	if contextCurrent then
		command.aimWeapon = wep
		command.aimOrigin = eyePos
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

local function GetPerceptionEntry(bot, body)
	local state = bot.ZCBotAI
	local command = state and state.command
	if not command or command.tick ~= engine.TickCount() or not IsValid(body) then return end

	local cache = state.perception.cache
	if not cache then
		cache = setmetatable({}, {__mode = "k"})
		state.perception.cache = cache
	end

	local entry = cache[body]
	if not entry then
		entry = {}
		cache[body] = entry
	end

	if entry.generation ~= command.generation then
		entry.generation = command.generation
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

function AddAimCandidate(candidates, pos)
	if not isvector(pos) then return end

	for _, oldPos in ipairs(candidates) do
		if oldPos:DistToSqr(pos) <= 16 then return end
	end

	candidates[#candidates + 1] = pos
end

function GetTargetAimCandidates(ent, bot)
	local cacheEntry = IsValid(bot) and GetPerceptionEntry(bot, ent)
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

function BotCanSee(bot, body, aimPos)
	local cacheEntry = GetPerceptionEntry(bot, body)
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
	local command = bot.ZCBotAI and bot.ZCBotAI.command
	local forward = command and command.tick == engine.TickCount() and command.eyeForward
	if not isvector(forward) then
		forward = bot:EyeAngles():Forward()
		if command then command.eyeForward = forward end
	end

	return forward:Dot(toAim) >= BOT_FOV_DOT
end

function BotCanPerceive(bot, body, aimPos)
	local cacheEntry = GetPerceptionEntry(bot, body)
	local closeAware = cacheEntry and cacheEntry.closeAware
	if closeAware == nil then
		local command = bot.ZCBotAI and bot.ZCBotAI.command
		local contextCurrent = command and command.tick == engine.TickCount()
		local botPos = contextCurrent and command.pos
		if not isvector(botPos) then
			botPos = bot:GetPos()
			if command then command.pos = botPos end
		end

		closeAware = IsValid(body) and botPos:DistToSqr(body:GetPos()) <= BOT_CLOSE_AWARENESS_RANGE * BOT_CLOSE_AWARENESS_RANGE
		if cacheEntry then cacheEntry.closeAware = closeAware end
	end

	return (closeAware or IsAimPosInBotFOV(bot, aimPos)) and BotCanSee(bot, body, aimPos)
end

local function GetStoredTargetPerception(bot, state, body, noFOV)
	local stored = state.perception
	if stored.refreshing then return end
	if stored.storedBody ~= body then return end
	if (stored.storedUntil or 0) <= GetBotCommandNow(bot) then return end
	if not noFOV and stored.storedNoFOV then return end
	if noFOV and not stored.storedNoFOV and not stored.storedVisible then return end

	return stored.storedAimPos, stored.storedVisible, true
end

function GetVisibleTargetAimPos(bot, body)
	local state = bot.ZCBotAI
	local storedAimPos, storedVisible, stored = state and GetStoredTargetPerception(bot, state, body, false)
	if stored then return storedAimPos, storedVisible end

	local cacheEntry = GetPerceptionEntry(bot, body)
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
	local state = bot.ZCBotAI
	local storedAimPos, storedVisible, stored = state and GetStoredTargetPerception(bot, state, body, true)
	if stored then return storedAimPos, storedVisible end

	local cacheEntry = GetPerceptionEntry(bot, body)
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
	local cacheEntry = GetPerceptionEntry(bot, body)
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

function GetBotTeamId(ply, mode)
	if not IsValid(ply) or not ply:IsPlayer() then return end

	local teamID = ply:Team()
	if teamID == TEAM_SPECTATOR or teamID == TEAM_UNASSIGNED then return end
	return teamID
end

function IsUsableTarget(bot, ply, mode)
	if ply == bot or not IsValid(ply) then return false end

	-- The active mode may own hostility outright. nil falls back to teammate rules.
	local hostility = CanBotTarget(bot, ply)
	if hostility == false then return false end

	if ply:IsPlayer() then
		if not ply:Alive() then return false end
		if ply:Team() == TEAM_SPECTATOR and (not ply.IsBot or not ply:IsBot()) then return false end
		if hostility ~= true and IsBotTeammate(bot, ply) then return false end
	else
		-- Non-player candidates are opt-in through MODE:CanBotTarget only.
		if hostility ~= true then return false end
		local health = ply.Health and ply:Health() or 0
		if health <= 0 then return false end
	end

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

function IsUprightThreat(bot, ply, mode)
	return IsUsableTarget(bot, ply, mode) and not IsUnconsciousTarget(ply) and not IsRagdolledTarget(ply)
end

function HasNearbyUprightEnemy(bot, ignoreTarget, players)
	local command = bot.ZCBotAI and bot.ZCBotAI.command
	local botPos = command and command.tick == engine.TickCount() and command.pos or bot:GetPos()
	local rangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	players = players or GetTargetCandidates(bot)
	for _, ply in ipairs(players) do
		if ply == ignoreTarget or not IsUprightThreat(bot, ply) then continue end
		if botPos:DistToSqr(ply:GetPos()) <= rangeSqr then return true end
	end

	return false
end

-- Default is the tick-cached player list; a mode may provide its own bounded
-- candidate list (hostile NPCs). Mode lists are cached briefly.
function GetTargetCandidates(bot)
	local state = bot.ZCBotAI
	local now = CurTime()
	local cache = state and state.perception.candidateCache
	if cache and (cache.expires or 0) > now and cache.list then return cache.list end

	local list = GetBotPlayerCandidates()
	local provided = GetBotTargetCandidates(bot)
	if istable(provided) and #provided > 0 then list = provided end

	if state then state.perception.candidateCache = {list = list, expires = now + 0.25} end
	return list
end

function GetNearestEnemy(bot, maxRange)
	local bestPly
	local bestDistSqr = maxRange and maxRange * maxRange or math.huge
	local botPos = bot:GetPos()

	for _, ply in ipairs(GetTargetCandidates(bot)) do
		if not IsUsableTarget(bot, ply) then continue end

		local distSqr = botPos:DistToSqr(ply:GetPos())
		if distSqr < bestDistSqr then
			bestDistSqr = distSqr
			bestPly = ply
		end
	end

	return bestPly, bestDistSqr
end

local function ScorePickTarget(bot, ply, unconscious, anyNearbyUpright)
	local body = GetBotTargetBody(ply)
	local aimPos, visible
	if anyNearbyUpright == "fake" then
		aimPos, visible = GetVisibleTargetAimPosNoFOV(bot, body)
	else
		aimPos, visible = GetVisibleTargetAimPos(bot, body)
	end
	if not visible then return end

	local score = bot:GetPos():DistToSqr(aimPos)
	if IsTargetInCover(bot, body) then
		score = score * BOT_COVER_SCORE_PENALTY
	end

	if unconscious then
		score = score * 25
	elseif not IsRagdolledTarget(ply) then
		score = score * 0.05
	end

	return score, body, aimPos, visible
end

function PickTarget(bot, fake)
	local bestPly
	local bestBody
	local bestAimPos
	local bestScore = math.huge
	local anyVisible = false
	local players = GetTargetCandidates(bot)
	local usablePlayers = {}
	local hasNearbyUpright = fake or HasNearbyUprightEnemy(bot, nil, players)

	for _, ply in ipairs(players) do
		if not IsUsableTarget(bot, ply) then continue end
		usablePlayers[#usablePlayers + 1] = ply
	end

	for _, ply in ipairs(usablePlayers) do
		local unconscious = IsUnconsciousTarget(ply)
		local score, body, aimPos, visible = ScorePickTarget(bot, ply, unconscious, fake and "fake" or nil)
		if not visible then continue end
		anyVisible = true
		if not fake and unconscious and hasNearbyUpright then continue end
		if not fake and IsRagdolledTarget(ply) and hasNearbyUpright then
			score = score * 10
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

function HasVisibleEnemy(bot)
	local state = bot.ZCBotAI
	if not state then return false end

	local now = GetBotCommandNow(bot)
	local perception = state.perception
	if (perception.visibleEnemyUntil or 0) > now and perception.hasVisibleEnemy ~= nil then
		return perception.hasVisibleEnemy
	end

	for _, ply in ipairs(GetTargetCandidates(bot)) do
		if not IsUsableTarget(bot, ply) then continue end

		local _, visible = GetVisibleTargetAimPos(bot, GetBotTargetBody(ply))
		if visible then
			perception.hasVisibleEnemy = true
			perception.visibleEnemyUntil = now + BOT_TARGET_TRACK_INTERVAL
			return true
		end
	end

	perception.hasVisibleEnemy = false
	perception.visibleEnemyUntil = now + BOT_THINK_INTERVAL
	return false
end

function CanCurrentlyTarget(bot, ply)
	if not IsUsableTarget(bot, ply) then return false end

	local state = bot.ZCBotAI
	local body = GetBotTargetBody(ply)
	local perception = state and state.perception
	if perception and perception.storedTarget == ply and perception.storedBody == body and (perception.storedUntil or 0) > GetBotCommandNow(bot) then
		return perception.storedVisible == true and not perception.storedNoFOV
	end

	local _, visible = GetVisibleTargetAimPos(bot, body)
	return visible
end

local function StoreTargetPerception(bot, state, target, body, aimPos, visible, noFOV, expiresAt, anyVisible)
	local now = GetBotCommandNow(bot)
	local perception = state.perception
	perception.storedTarget = target
	perception.storedBody = body
	perception.storedAimPos = aimPos
	perception.storedVisible = visible == true
	perception.storedNoFOV = noFOV == true
	perception.storedUntil = expiresAt or (now + BOT_THINK_INTERVAL)
	if anyVisible ~= nil then
		perception.hasVisibleEnemy = anyVisible == true
		perception.visibleEnemyUntil = math_max(perception.storedUntil, now + BOT_THINK_INTERVAL)
	end
end

local function ApplyTargetSelection(bot, state, target, body, aimPos, visible, noFOV, anyVisible, now)
	local perception = state.perception
	local oldTarget = state.target
	state.target = target
	perception.nextTrack = now + BOT_TARGET_TRACK_INTERVAL

	local aggregateVisible = anyVisible
	if noFOV then aggregateVisible = nil end
	StoreTargetPerception(bot, state, target, body, aimPos, visible, noFOV, now + BOT_TARGET_TRACK_INTERVAL, aggregateVisible)

	if target ~= oldTarget then
		ResetCombatTargetTransition(state)
		-- Commit to the new target for a short time so small distance changes
		-- do not cause constant switching.
		local combat = state.combat
		combat.lastTargetSwitch = now
		combat.targetLockUntil = now + BOT_TARGET_LOCK_TIME
		if IsValid(target) then
			LogBotIntentChange(bot, nil, noFOV and "fake-target" or "target", target:Name())
		end
	end

	-- Remember where a currently visible target was last seen so SEARCH can follow it later.
	if visible and IsValid(target) then
		state.lastSeenPos = isvector(aimPos) and Vector(aimPos.x, aimPos.y, aimPos.z) or GetBotTargetBodyPos(target, body)
		state.lastSeenAt = now
	end
end

local function TrackCurrentTarget(bot, state, mode, noFOV, now)
	local target = state.target
	if not IsUsableTarget(bot, target, mode) then return false end

	local body = GetBotTargetBody(target)
	local perception = state.perception
	perception.refreshing = true
	local aimPos, visible
	if noFOV then
		aimPos, visible = GetVisibleTargetAimPosNoFOV(bot, body)
	else
		aimPos, visible = GetVisibleTargetAimPos(bot, body)
	end
	perception.refreshing = false

	if not visible then return false end
	ApplyTargetSelection(bot, state, target, body, aimPos, true, noFOV, true, now)
	return true
end

local function MarkTargetLost(bot, state, now)
	-- Keep the target for a short memory window so SEARCH can visit its last known position.
	if not isvector(state.lastSeenPos) then
		local body = GetBotTargetBody(state.target)
		state.lastSeenPos = IsValid(body) and GetBotTargetBodyPos(state.target, body) or nil
	end
	state.lastSeenAt = state.lastSeenAt > 0 and state.lastSeenAt or now
end

function ClearTargetMemory(state)
	state.target = nil
	state.lastSeenPos = nil
	state.lastSeenAt = 0

	local perception = state.perception
	perception.storedTarget = nil
	perception.storedBody = nil
	perception.storedAimPos = nil
	perception.storedVisible = false
	perception.storedNoFOV = false
	perception.storedUntil = 0

	local combat = state.combat
	combat.targetLockUntil = 0
	combat.lastTargetSwitch = 0

	ResetCombatTargetTransition(state)
end

-- Full scans run on the decision interval; an existing target is only tracked between scans.
-- Target commitment: a locked, still-valid target is only given up for a recent
-- attacker, a much closer enemy, a downed target with upright threats nearby,
-- or a lost target (handled by tracking failure).
local function ResolveCommittedTarget(bot, state, mode, picked, pbody, paimPos, anyVisible, now)
	local current = state.target
	if not IsValid(picked) or picked == current or not IsValid(current) then return picked, pbody, paimPos, anyVisible end
	if (state.combat.targetLockUntil or 0) <= now then return picked, pbody, paimPos, anyVisible end
	if not IsUsableTarget(bot, current, mode) then return picked, pbody, paimPos, anyVisible end

	-- A recent attacker is an immediate threat and overrides commitment.
	local threat = state.threat
	if IsValid(threat) and threat == picked and (state.threatUntil or 0) > now then return picked, pbody, paimPos, anyVisible end

	-- A downed or unconscious target no longer deserves its lock while an
	-- upright threat is nearby.
	if IsUnconsciousTarget(current) or IsRagdolledTarget(current) then return picked, pbody, paimPos, anyVisible end

	-- The new enemy must be much closer to justify breaking the lock.
	local curBody = GetBotTargetBody(current)
	local botPos = bot:GetPos()
	local curDistSqr = botPos:DistToSqr(GetBotTargetBodyPos(current, curBody))
	local newDistSqr = botPos:DistToSqr(GetBotTargetBodyPos(picked, pbody))
	if newDistSqr > curDistSqr * 0.16 then return picked, pbody, paimPos, anyVisible end

	local perception = state.perception
	perception.refreshing = true
	local keepAim, keepVisible = GetVisibleTargetAimPos(bot, curBody)
	perception.refreshing = false

	if not keepVisible then return picked, pbody, paimPos, anyVisible end

	return current, curBody, keepAim, true
end

function UpdateTarget(bot, state, mode, noFOV, now)
	local perception = state.perception

	if (perception.nextFullScan or 0) > now then
		if IsValid(state.target) and (perception.nextTrack or 0) <= now then
			if TrackCurrentTarget(bot, state, mode, noFOV, now) then return end
			MarkTargetLost(bot, state, now)
			perception.nextFullScan = 0
		end
		return
	end

	perception.refreshing = true
	local picked, pbody, paimPos, anyVisible = PickTarget(bot, noFOV)
	perception.refreshing = false
	perception.nextFullScan = now + BOT_THINK_INTERVAL

	local target, body, aimPos, visibleAny
	if noFOV then
		target, body, aimPos, visibleAny = picked, pbody, paimPos, anyVisible
	else
		target, body, aimPos, visibleAny = ResolveCommittedTarget(bot, state, mode, picked, pbody, paimPos, anyVisible, now)
	end

	if IsValid(target) then
		ApplyTargetSelection(bot, state, target, body, aimPos, true, noFOV, visibleAny, now)
	elseif IsValid(state.target) then
		-- Nobody visible this scan: keep the target briefly so SEARCH can visit
		-- its last known position before the memory expires.
		MarkTargetLost(bot, state, now)
	else
		ClearTargetMemory(state)
	end
end

function IsTargetMemoryFresh(state, now)
	return IsValid(state.target) and isvector(state.lastSeenPos) and (now - (state.lastSeenAt or 0)) <= BOT_TARGET_MEMORY_TIME
end

-- Public API: damage and suppression hooks report threats through here.
function RememberThreat(bot, attacker, threatPos)
	if not zc_playerbot_ai:GetBool() or not IsValid(bot) or not bot:IsPlayer() or not bot:IsBot() then return end
	if not bot:Alive() then return end

	if IsValid(attacker) and attacker.GetOwner then
		local owner = attacker:GetOwner()
		if IsValid(owner) then attacker = owner end
	end

	if attacker == bot then return end

	local state = GetOrCreateState(bot)
	if IsUsableTarget(bot, attacker) then
		local targetChanged = state.target ~= attacker
		state.threat = attacker
		state.target = attacker
		if targetChanged then
			state.perception.nextFullScan = 0
			ResetCombatTargetTransition(state)
		end
	end

	if (not isvector(threatPos) or threatPos:IsZero()) and IsValid(attacker) then threatPos = attacker:WorldSpaceCenter() end
	if not isvector(threatPos) or threatPos:IsZero() then return end

	state.threat = state.threat or attacker
	state.threatPos = threatPos
	state.threatUntil = CurTime() + BOT_THREAT_MEMORY_TIME

	-- Let the mode record learned hostility (e.g. Homicide grudges).
	NotifyBotDamaged(bot, attacker)
end
