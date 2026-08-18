zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local ipairs, isvector, isnumber = ipairs, isvector, isnumber
local navmesh = navmesh

local deathmatchNoZoneConVar = GetConVar("zc_deathmatch_nozone")
local engine_TickCount = engine.TickCount
local math_max = math.max
local math_sqrt = math.sqrt

local cachedZoneContext
local cachedZoneContextTick = -1
local cachedZoneContextRound
local cachedZoneContextRoundStart
local cachedZoneContextRoundState
local cachedZoneContextPoint

local centerGoalCandidateCache
local centerGoalCandidateCacheRefreshAt = 0
local centerGoalCandidateCacheMap = game.GetMap()

local function ClearCenterGoalCandidateCache()
	centerGoalCandidateCache = nil
	centerGoalCandidateCacheRefreshAt = 0
	centerGoalCandidateCacheMap = game.GetMap()
end

hook.Add("InitPostEntity", "ZC_PlayerBotCenterGoalNavCache", ClearCenterGoalCandidateCache)
hook.Add("PostCleanupMap", "ZC_PlayerBotCenterGoalNavCache", ClearCenterGoalCandidateCache)

function IsDeathmatchSafeTime(round, zoneContext)
	if not (zoneContext and zoneContext.round == round and zoneContext.active) and not IsDeathmatchRoundActive(round) then return false end
	if round.IsSpawnProtectionActive then return round:IsSpawnProtectionActive() end

	return (zc.ROUND_START or 0) + (round.SpawnProtectionTime or 7.5) > CurTime()
end

function IsRoundFadeInTime(round)
	if not zc then return false end

	local duration = BOT_ROUND_FADEIN_TIME
	return (zc.ROUND_START or 0) + duration > CurTime()
end

function IsDeathmatchZoneDisabled()
	-- The deathmatch mode creates this ConVar after the playerbot files are loaded.
	-- Resolve it lazily once, rather than looking it up for every bot command.
	deathmatchNoZoneConVar = deathmatchNoZoneConVar or GetConVar("zc_deathmatch_nozone")
	return deathmatchNoZoneConVar and deathmatchNoZoneConVar:GetBool()
end

function GetDeathmatchZoneContext(round)
	round = round or GetCurrentRound()

	local tick = engine_TickCount()
	local roundStart = zc and zc.ROUND_START
	local roundState = zc and zc.ROUND_STATE
	local point = zonepoint
	if cachedZoneContext and cachedZoneContextTick == tick and cachedZoneContextRound == round and cachedZoneContextRoundStart == roundStart and cachedZoneContextRoundState == roundState and cachedZoneContextPoint == point then
		return cachedZoneContext
	end

	local active = IsDeathmatchRoundActive(round)
	local center
	local radius

	if active and not IsDeathmatchZoneDisabled() and isvector(point) and round.GetZoneRadius then
		local currentRadius = round.GetZoneRadius()
		if isnumber(currentRadius) and currentRadius > 0 and currentRadius < 1000000 then
			center = point
			radius = currentRadius
		end
	end

	local shrinkProgress = 0
	if active then
		local shrinkTime = round.ZoneTimeToShrink
		if not isnumber(shrinkTime) or shrinkTime <= 0 then
			shrinkProgress = 1
		else
			shrinkProgress = math_Clamp((CurTime() - (roundStart or CurTime())) / shrinkTime, 0, 1)
		end
	end

	cachedZoneContext = {
		active = active,
		center = center,
		radius = radius,
		round = round,
		roundStart = roundStart,
		seekCenter = shrinkProgress >= BOT_ZONE_CENTER_SHRINK_FRACTION,
		shrinkProgress = shrinkProgress,
		tick = tick
	}
	cachedZoneContextTick = tick
	cachedZoneContextRound = round
	cachedZoneContextRoundStart = roundStart
	cachedZoneContextRoundState = roundState
	cachedZoneContextPoint = point

	return cachedZoneContext
end

function GetDeathmatchZoneInfo(round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	return zoneContext.center, zoneContext.radius
end

function GetDeathmatchZoneShrinkProgress(round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	return zoneContext.shrinkProgress
end

function ShouldSeekDeathmatchZoneCenter(round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	return zoneContext.seekCenter
end

function ShouldMoveTowardDeathmatchZoneCenter(bot, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	if not center or not zoneContext.seekCenter then return false end

	local distSqr = bot:GetPos():DistToSqr(center)
	if distSqr <= BOT_ZONE_CENTER_SETTLE_RADIUS * BOT_ZONE_CENTER_SETTLE_RADIUS then
		bot.ZCBotSettledNearZoneCenter = true
	elseif distSqr >= BOT_ZONE_CENTER_RESUME_RADIUS * BOT_ZONE_CENTER_RESUME_RADIUS then
		bot.ZCBotSettledNearZoneCenter = false
	end

	return not bot.ZCBotSettledNearZoneCenter
end

local function GetCenterGoalCandidates(round, zoneContext)
	local center = zoneContext.center
	if not center or not navmesh or not navmesh.GetAllNavAreas then return {} end

	local mapName = game.GetMap()
	local now = CurTime()
	local cache = centerGoalCandidateCache
	local cacheMatches = cache and centerGoalCandidateCacheMap == mapName and cache.round == round and cache.roundStart == zoneContext.roundStart and cache.centerX == center.x and cache.centerY == center.y and cache.centerZ == center.z and cache.goalRadius == BOT_ZONE_CENTER_GOAL_RADIUS
	if cacheMatches and centerGoalCandidateCacheRefreshAt > now then
		return cache.candidates
	end

	local candidates = {}
	local goalRadiusSqr = BOT_ZONE_CENTER_GOAL_RADIUS * BOT_ZONE_CENTER_GOAL_RADIUS
	local areas = GetCachedBotNavAreas and GetCachedBotNavAreas() or navmesh.GetAllNavAreas()
	if areas then
		for _, area in ipairs(areas) do
			if not IsValid(area) then continue end

			local pos = GetAreaWaypoint(area)
			local centerDistSqr = pos:DistToSqr(center)
			if centerDistSqr > goalRadiusSqr then continue end

			candidates[#candidates + 1] = {
				area = area,
				centerDistSqr = centerDistSqr,
				pos = pos
			}
		end
	end

	centerGoalCandidateCache = {
		candidates = candidates,
		centerX = center.x,
		centerY = center.y,
		centerZ = center.z,
		goalRadius = BOT_ZONE_CENTER_GOAL_RADIUS,
		round = round,
		roundStart = zoneContext.roundStart
	}
	centerGoalCandidateCacheMap = mapName
	-- Empty results are cached too, but retried sooner in case nav areas were not
	-- ready yet when the first bot requested a goal.
	centerGoalCandidateCacheRefreshAt = now + (#candidates > 0 and 30 or 1)

	return candidates
end

local function IsSameCenterGoalContext(bot, round, zoneContext, center)
	return bot.ZCBotCenterGoalRound == round and bot.ZCBotCenterGoalRoundStart == zoneContext.roundStart and bot.ZCBotCenterGoalCenterX == center.x and bot.ZCBotCenterGoalCenterY == center.y and bot.ZCBotCenterGoalCenterZ == center.z
end

function PickDeathmatchCenterGoal(bot, round, reachDistance, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	if not center then return end

	reachDistance = reachDistance or BOT_ZONE_CENTER_REACH
	local now = CurTime()
	if isvector(bot.ZCBotCenterGoalPos) and (bot.ZCBotNextCenterGoalPick or 0) > now and IsSameCenterGoalContext(bot, round, zoneContext, center) and (bot.ZCBotCenterGoalFallback or IsPosInsideDeathmatchZone(bot.ZCBotCenterGoalPos, round, BOT_ZONE_ROAM_MARGIN, zoneContext)) then
		return bot.ZCBotCenterGoalPos
	end

	local bestArea
	local bestScore = math_huge
	local botPos = bot:GetPos()
	local reachDistanceSqr = reachDistance * reachDistance
	local zoneReach = math_max((zoneContext.radius or 0) - BOT_ZONE_ROAM_MARGIN, 0)
	local zoneReachSqr = zoneReach * zoneReach

	for _, candidate in ipairs(GetCenterGoalCandidates(round, zoneContext)) do
		local area = candidate.area
		if not IsValid(area) or candidate.centerDistSqr >= zoneReachSqr then continue end
		if botPos:DistToSqr(candidate.pos) <= reachDistanceSqr then continue end

		local centerDist = math_sqrt(candidate.centerDistSqr)
		local score = math_abs(centerDist - BOT_ZONE_CENTER_GOAL_RADIUS * 0.45) + math_Rand(0, 250)
		if score < bestScore then
			bestScore = score
			bestArea = area
		end
	end

	local goalPos = IsValid(bestArea) and GetAreaWaypoint(bestArea) or center
	bot.ZCBotCenterGoalPos = goalPos
	bot.ZCBotCenterGoalFallback = not IsValid(bestArea)
	bot.ZCBotCenterGoalRound = round
	bot.ZCBotCenterGoalRoundStart = zoneContext.roundStart
	bot.ZCBotCenterGoalCenterX = center.x
	bot.ZCBotCenterGoalCenterY = center.y
	bot.ZCBotCenterGoalCenterZ = center.z
	bot.ZCBotNextCenterGoalPick = now + BOT_ZONE_CENTER_GOAL_INTERVAL + math_Rand(0, 2)

	return goalPos
end

function IsPosInsideDeathmatchZone(pos, round, margin, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	local radius = zoneContext.radius
	if not center then return true end

	local insideRadius = math_max(radius - (margin or 0), 0)
	return center:DistToSqr(pos) < insideRadius * insideRadius
end

function BiasPosTowardDeathmatchCenter(bot, pos, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	if not center then return pos end
	if not zoneContext.seekCenter then return pos end

	local botPos = bot:GetPos()
	local currentDistSqr = botPos:DistToSqr(center)
	if currentDistSqr <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return pos end
	local improvedDist = math_max(math_sqrt(currentDistSqr) - BOT_ZONE_CENTER_BIAS_STEP, 0)
	if pos:DistToSqr(center) < improvedDist * improvedDist then return pos end

	return PickDeathmatchCenterGoal(bot, round, nil, zoneContext) or center
end

function ApplyDeathmatchCenterMovementBias(bot, cmd, aimAng, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	if not center then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round, zoneContext) then return false end

	local botPos = bot:GetPos()
	local currentDistSqr = botPos:DistToSqr(center)
	if currentDistSqr <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return false end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return false end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return false end

	moveDir:Normalize()
	if (botPos + moveDir * BOT_ZONE_CENTER_BIAS_STEP):DistToSqr(center) < currentDistSqr then return false end

	local speed = math.max(math_abs(forwardMove), math_abs(sideMove), 300)
	SetBotMovementToward(bot, cmd, PickDeathmatchCenterGoal(bot, round, nil, zoneContext) or center, aimAng, speed)
	return true
end

function GetDeathmatchZoneEscapePos(bot, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	local radius = zoneContext.radius
	if not center then return end

	local pos = bot:GetPos()
	local distSqr = pos:DistToSqr(center)
	local safeRadius = radius - BOT_ZONE_ROAM_MARGIN
	if safeRadius > 0 and distSqr < safeRadius * safeRadius then return end

	if distSqr <= 1 then return center end

	return center
end

function IsDeathmatchZoneClose(bot, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	local radius = zoneContext.radius
	if not center then return false end

	local safeRadius = radius - BOT_ZONE_ROAM_MARGIN
	return safeRadius <= 0 or bot:GetPos():DistToSqr(center) >= safeRadius * safeRadius
end

function AvoidDeathmatchZone(bot, cmd, round, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local escapePos = GetDeathmatchZoneEscapePos(bot, round, zoneContext)
	if not escapePos then return false end

	local aimAng = (escapePos - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

	local followedPath = FollowBotPath(bot, cmd, escapePos, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, escapePos, aimAng, 360)
		TryBotTravelSprint(bot, cmd, escapePos)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, escapePos)
	end

	if (bot.ZCBotNextZoneDebug or 0) <= CurTime() then
		bot.ZCBotNextZoneDebug = CurTime() + 2
		BotDevPrint("%s avoid-dm-zone", bot:Name())
	end

	return true
end

function MoveToDeathmatchZoneCenter(bot, cmd, round, ignoreTimeLimit, reachDistance, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	if not zoneContext.active then return false end
	if not ignoreTimeLimit and CurTime() > (zc.ROUND_START or 0) + BOT_ZONE_CENTER_TIME then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round, zoneContext) then return false end

	local center = zoneContext.center
	if not center then return false end
	reachDistance = reachDistance or BOT_ZONE_CENTER_REACH
	local goalPos = PickDeathmatchCenterGoal(bot, round, reachDistance, zoneContext) or center
	if bot:GetPos():DistToSqr(goalPos) <= reachDistance * reachDistance then return false end

	local aimAng = (goalPos - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

	local followedPath = FollowBotPath(bot, cmd, goalPos, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, goalPos, aimAng, 360)
		TryBotTravelSprint(bot, cmd, goalPos)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, goalPos)
	end

	return true
end

function MoveToDeathmatchZoneCenterWhileAiming(bot, cmd, round, aimAng, runSpeed, zoneContext)
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	local center = zoneContext.center
	if not center then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round, zoneContext) then return false end

	local goalPos = PickDeathmatchCenterGoal(bot, round, nil, zoneContext) or center
	if bot:GetPos():DistToSqr(goalPos) <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return false end

	SetBotMovementToward(bot, cmd, goalPos, aimAng, runSpeed or 360)
	TryBotTravelSprint(bot, cmd, goalPos)
	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, goalPos)
	return true
end

function GetNearestEnemy(bot, maxRange, round)
	local bestPly
	local bestDistSqr = maxRange and maxRange * maxRange or math_huge
	local botPos = bot:GetPos()

	for _, ply in ipairs(GetBotPlayerCandidates()) do
		if not IsUsableTarget(bot, ply, round) then continue end

		local distSqr = botPos:DistToSqr(ply:GetPos())
		if distSqr < bestDistSqr then
			bestDistSqr = distSqr
			bestPly = ply
		end
	end

	return bestPly, bestDistSqr
end

local function GetCachedSafeTimeEnemy(bot, round)
	local now = CurTime()
	local maxRange = BOT_SAFE_ENEMY_AVOID_RANGE
	local maxRangeSqr = maxRange * maxRange
	if (bot.ZCBotNextSafeEnemyScan or 0) > now and bot.ZCBotSafeEnemyScanRangeSqr == maxRangeSqr then
		local enemy = bot.ZCBotSafeEnemy
		if not IsValid(enemy) or not IsUsableTarget(bot, enemy, round) then return end
		if bot:GetPos():DistToSqr(enemy:GetPos()) > maxRangeSqr then return end
		return enemy
	end

	local enemy = GetNearestEnemy(bot, maxRange, round)
	bot.ZCBotSafeEnemy = enemy
	bot.ZCBotSafeEnemyScanRangeSqr = maxRangeSqr
	local interval = math_max(BOT_THINK_INTERVAL or 0.2, 0.1)
	bot.ZCBotNextSafeEnemyScan = now + interval + (bot:EntIndex() % 5) * interval * 0.05
	return enemy
end

function AvoidEnemiesDuringSafeTime(bot, cmd, round, zoneContext)
	local enemy = GetCachedSafeTimeEnemy(bot, round)
	if not IsValid(enemy) then return false end

	local away = bot:GetPos() - enemy:GetPos()
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:EyeAngles():Forward() * -1
	end

	away:Normalize()
	local destPos = bot:GetPos() + away * BOT_SAFE_ENEMY_AVOID_DEST
	zoneContext = zoneContext or GetDeathmatchZoneContext(round)
	destPos = BiasPosTowardDeathmatchCenter(bot, destPos, round, zoneContext)

	local aimAng = (destPos - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

	local followedPath = FollowBotPath(bot, cmd, destPos, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, destPos, aimAng, 360)
		TryBotTravelSprint(bot, cmd, destPos)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, destPos)
	end

	return true
end

function ClearCombatButtons(cmd)
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(bit_bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD))))
end

BOT_MOVEMENT_BUTTONS = bit_bor(IN_FORWARD, IN_BACK, IN_MOVELEFT, IN_MOVERIGHT, IN_JUMP, IN_DUCK, IN_SPEED, IN_WALK)

function ClearBotMovementInput(cmd)
	cmd:ClearMovement()
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(BOT_MOVEMENT_BUTTONS)))
end

function ClearBotTarget(bot)
	bot.ZCBotTarget = nil
	bot.ZCBotSeenTarget = nil
	bot.ZCBotSeenTargetStart = nil
	bot.ZCBotAimNoiseNext = 0
	bot.ZCBotReactionTarget = nil
	bot.ZCBotReactionReadyAt = nil
	bot.ZCBotAttackReleaseUntil = nil
	bot.ZCBotReloadWeapon = nil
	bot.ZCBotReloadStartClip = nil
	bot.ZCBotReloadGoalClip = nil
	bot.ZCBotReloadPulseUntil = nil
	bot.ZCBotAutoBurstUntil = nil
	bot.ZCBotAutoBurstPauseUntil = nil
	bot.ZCBotTapAttackUntil = nil
	if ClearBotTargetPerception then ClearBotTargetPerception(bot) end
end

local function ResetBotTargetTransitionState(bot)
	bot.ZCBotSeenTarget = nil
	bot.ZCBotSeenTargetStart = nil
	bot.ZCBotAimNoiseNext = 0
	bot.ZCBotReactionTarget = nil
	bot.ZCBotReactionReadyAt = nil
	bot.ZCBotAttackReleaseUntil = nil
	bot.ZCBotReloadWeapon = nil
	bot.ZCBotReloadStartClip = nil
	bot.ZCBotReloadGoalClip = nil
	bot.ZCBotReloadPulseUntil = nil
	bot.ZCBotAutoBurstUntil = nil
	bot.ZCBotAutoBurstPauseUntil = nil
	bot.ZCBotTapAttackUntil = nil
end

local function ApplyBotTargetSelection(bot, target, body, aimPos, visible, noFOV, anyVisible, now)
	local oldTarget = bot.ZCBotTarget
	bot.ZCBotTarget = target
	local trackUntil = now + BOT_TARGET_TRACK_INTERVAL
	bot.ZCBotNextTargetTrack = trackUntil
	local aggregateVisible = anyVisible
	if noFOV then aggregateVisible = nil end
	StoreBotTargetPerception(bot, target, body, aimPos, visible, noFOV, trackUntil, aggregateVisible)

	if target ~= oldTarget then
		ResetBotTargetTransitionState(bot)
	end

	if target ~= oldTarget and IsValid(target) then
		BotDevPrint(noFOV and "%s fake target=%s" or "%s target=%s", bot:Name(), target:Name())
	end
end

local function RefreshTrackedBotTarget(bot, round, noFOV, now)
	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target, round) then return false end

	local body = GetBotTargetBody(target)
	bot.ZCBotRefreshingPerception = true
	local aimPos, visible
	if noFOV then
		aimPos, visible = GetVisibleTargetAimPosNoFOV(bot, body)
	else
		aimPos, visible = GetVisibleTargetAimPos(bot, body)
	end
	bot.ZCBotRefreshingPerception = false

	if not visible then return false end
	ApplyBotTargetSelection(bot, target, body, aimPos, true, noFOV, true, now)
	return true
end

function UpdateBotTarget(bot, round)
	local now = GetBotCommandNow(bot)
	local nextFullScan = bot.ZCBotNextTargetScan or 0

	if nextFullScan > now then
		if IsValid(bot.ZCBotTarget) and (bot.ZCBotNextTargetTrack or 0) <= now then
			if RefreshTrackedBotTarget(bot, round, false, now) then return false end
			ClearBotTarget(bot)
			bot.ZCBotNextTargetScan = 0
		else
			return false
		end
	end

	bot.ZCBotRefreshingPerception = true
	local target, body, aimPos, anyVisible = PickBotTarget(bot, round)
	bot.ZCBotRefreshingPerception = false
	bot.ZCBotNextTargetScan = now + BOT_THINK_INTERVAL
	ApplyBotTargetSelection(bot, target, body, aimPos, IsValid(target), false, anyVisible, now)
	return true
end

function UpdateBotFakeTarget(bot, round)
	local now = GetBotCommandNow(bot)
	local nextFullScan = bot.ZCBotNextTargetScan or 0

	if nextFullScan > now then
		if IsValid(bot.ZCBotTarget) and (bot.ZCBotNextTargetTrack or 0) <= now then
			if RefreshTrackedBotTarget(bot, round, true, now) then return false end
			ClearBotTarget(bot)
			bot.ZCBotNextTargetScan = 0
		else
			return false
		end
	end

	bot.ZCBotRefreshingPerception = true
	local target, body, aimPos, anyVisible = PickBotFakeTarget(bot, round)
	bot.ZCBotRefreshingPerception = false
	bot.ZCBotNextTargetScan = now + BOT_THINK_INTERVAL
	ApplyBotTargetSelection(bot, target, body, aimPos, IsValid(target), true, anyVisible, now)
	return true
end

