hg = hg or {}
hg.PlayerBots = hg.PlayerBots or {}
local _ENV = hg.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

function IsDeathmatchSafeTime(round)
	if not IsDeathmatchRoundActive(round) then return false end
	if round.IsSpawnProtectionActive then return round:IsSpawnProtectionActive() end

	return (zb.ROUND_START or 0) + (round.SpawnProtectionTime or 7.5) > CurTime()
end

function IsRoundFadeInTime(round)
	if not zb then return false end

	local duration = BOT_ROUND_FADEIN_TIME
	return (zb.ROUND_START or 0) + duration > CurTime()
end

function IsDeathmatchZoneDisabled()
	local convar = GetConVar("zc_deathmatch_nozone")
	return convar and convar:GetBool()
end

function GetDeathmatchZoneInfo(round)
	if not IsDeathmatchRoundActive(round) or IsDeathmatchZoneDisabled() then return end
	if not isvector(zonepoint) then return end
	if not round.GetZoneRadius then return end

	local radius = round.GetZoneRadius()
	if not isnumber(radius) or radius <= 0 or radius >= 1000000 then return end

	return zonepoint, radius
end

function GetDeathmatchZoneShrinkProgress(round)
	if not IsDeathmatchRoundActive(round) then return 0 end

	local shrinkTime = round.ZoneTimeToShrink
	if not isnumber(shrinkTime) or shrinkTime <= 0 then return 1 end

	return math_Clamp((CurTime() - (zb.ROUND_START or CurTime())) / shrinkTime, 0, 1)
end

function ShouldSeekDeathmatchZoneCenter(round)
	return GetDeathmatchZoneShrinkProgress(round) >= BOT_ZONE_CENTER_SHRINK_FRACTION
end

function ShouldMoveTowardDeathmatchZoneCenter(bot, round)
	local center = GetDeathmatchZoneInfo(round)
	if not center or not ShouldSeekDeathmatchZoneCenter(round) then return false end

	local dist = bot:GetPos():Distance(center)
	if dist <= BOT_ZONE_CENTER_SETTLE_RADIUS then
		bot.ZCBotSettledNearZoneCenter = true
	elseif dist >= BOT_ZONE_CENTER_RESUME_RADIUS then
		bot.ZCBotSettledNearZoneCenter = false
	end

	return not bot.ZCBotSettledNearZoneCenter
end

function PickDeathmatchCenterGoal(bot, round, reachDistance)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return end

	reachDistance = reachDistance or BOT_ZONE_CENTER_REACH
	if isvector(bot.ZCBotCenterGoalPos) and (bot.ZCBotNextCenterGoalPick or 0) > CurTime() and IsPosInsideDeathmatchZone(bot.ZCBotCenterGoalPos, round, BOT_ZONE_ROAM_MARGIN) then
		return bot.ZCBotCenterGoalPos
	end

	local bestArea
	local bestScore = math_huge

	if navmesh and navmesh.GetAllNavAreas then
		for _, area in ipairs(navmesh.GetAllNavAreas()) do
			if not IsValid(area) then continue end

			local pos = GetAreaWaypoint(area)
			local centerDist = pos:Distance(center)
			if centerDist > BOT_ZONE_CENTER_GOAL_RADIUS then continue end
			if not IsPosInsideDeathmatchZone(pos, round, BOT_ZONE_ROAM_MARGIN) then continue end

			local botDist = bot:GetPos():Distance(pos)
			if botDist <= reachDistance then continue end

			local score = math_abs(centerDist - BOT_ZONE_CENTER_GOAL_RADIUS * 0.45) + math_Rand(0, 250)
			if score < bestScore then
				bestScore = score
				bestArea = area
			end
		end
	end

	local goalPos = IsValid(bestArea) and GetAreaWaypoint(bestArea) or center
	bot.ZCBotCenterGoalPos = goalPos
	bot.ZCBotNextCenterGoalPick = CurTime() + BOT_ZONE_CENTER_GOAL_INTERVAL + math_Rand(0, 2)

	return goalPos
end

function IsPosInsideDeathmatchZone(pos, round, margin)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return true end

	return center:DistToSqr(pos) < math.max(radius - (margin or 0), 0) ^ 2
end

function BiasPosTowardDeathmatchCenter(bot, pos, round)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return pos end
	if not ShouldSeekDeathmatchZoneCenter(round) then return pos end

	local botPos = bot:GetPos()
	local currentDist = botPos:Distance(center)
	if currentDist <= BOT_ZONE_CENTER_REACH then return pos end
	if pos:Distance(center) < currentDist - BOT_ZONE_CENTER_BIAS_STEP then return pos end

	return PickDeathmatchCenterGoal(bot, round) or center
end

function ApplyDeathmatchCenterMovementBias(bot, cmd, aimAng, round)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round) then return false end

	local botPos = bot:GetPos()
	local currentDist = botPos:Distance(center)
	if currentDist <= BOT_ZONE_CENTER_REACH then return false end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return false end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return false end

	moveDir:Normalize()
	if (botPos + moveDir * BOT_ZONE_CENTER_BIAS_STEP):Distance(center) < currentDist then return false end

	local speed = math.max(math_abs(forwardMove), math_abs(sideMove), 300)
	SetBotMovementToward(bot, cmd, PickDeathmatchCenterGoal(bot, round) or center, aimAng, speed)
	return true
end

function GetDeathmatchZoneEscapePos(bot, round)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return end

	local pos = bot:GetPos()
	local offset = pos - center
	local dist = offset:Length()
	if dist < radius - BOT_ZONE_ROAM_MARGIN then return end

	if dist <= 1 then return center end

	return center
end

function IsDeathmatchZoneClose(bot, round)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return false end

	return bot:GetPos():Distance(center) >= radius - BOT_ZONE_ROAM_MARGIN
end

function AvoidDeathmatchZone(bot, cmd, round)
	local escapePos = GetDeathmatchZoneEscapePos(bot, round)
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
		BotDevPrint(string.format("%s avoid-dm-zone", bot:Name()))
	end

	return true
end

function MoveToDeathmatchZoneCenter(bot, cmd, round, ignoreTimeLimit, reachDistance)
	if not IsDeathmatchRoundActive(round) then return false end
	if not ignoreTimeLimit and CurTime() > (zb.ROUND_START or 0) + BOT_ZONE_CENTER_TIME then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round) then return false end

	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	reachDistance = reachDistance or BOT_ZONE_CENTER_REACH
	local goalPos = PickDeathmatchCenterGoal(bot, round, reachDistance) or center
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

function MoveToDeathmatchZoneCenterWhileAiming(bot, cmd, round, aimAng, runSpeed)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	if not ShouldMoveTowardDeathmatchZoneCenter(bot, round) then return false end

	local goalPos = PickDeathmatchCenterGoal(bot, round) or center
	if bot:GetPos():DistToSqr(goalPos) <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return false end

	SetBotMovementToward(bot, cmd, goalPos, aimAng, runSpeed or 360)
	TryBotTravelSprint(bot, cmd, goalPos)
	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, goalPos)
	return true
end

function GetNearestEnemy(bot, maxRange)
	local bestPly
	local bestDistSqr = maxRange and maxRange * maxRange or math_huge
	local botPos = bot:GetPos()

	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local distSqr = botPos:DistToSqr(ply:GetPos())
		if distSqr < bestDistSqr then
			bestDistSqr = distSqr
			bestPly = ply
		end
	end

	return bestPly, bestDistSqr
end

function AvoidEnemiesDuringSafeTime(bot, cmd, round)
	local enemy = GetNearestEnemy(bot, BOT_SAFE_ENEMY_AVOID_RANGE)
	if not IsValid(enemy) then return false end

	local away = bot:GetPos() - enemy:GetPos()
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:EyeAngles():Forward() * -1
	end

	away:Normalize()
	local destPos = bot:GetPos() + away * BOT_SAFE_ENEMY_AVOID_DEST
	destPos = BiasPosTowardDeathmatchCenter(bot, destPos, round)

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
end

function UpdateBotTarget(bot)
	if (bot.ZCBotNextTargetScan or 0) > CurTime() and CanCurrentlyTarget(bot, bot.ZCBotTarget) then return end

	local oldTarget = bot.ZCBotTarget
	bot.ZCBotTarget = PickBotTarget(bot)
	bot.ZCBotNextTargetScan = CurTime() + BOT_THINK_INTERVAL

	if bot.ZCBotTarget ~= oldTarget then
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

	if bot.ZCBotTarget ~= oldTarget and IsValid(bot.ZCBotTarget) then
		BotDevPrint(string.format("%s target=%s", bot:Name(), bot.ZCBotTarget:Name()))
	end
end

function UpdateBotFakeTarget(bot)
	if (bot.ZCBotNextTargetScan or 0) > CurTime() and CanCurrentlyFakeTarget(bot, bot.ZCBotTarget) then return end

	local oldTarget = bot.ZCBotTarget
	bot.ZCBotTarget = PickBotFakeTarget(bot)
	bot.ZCBotNextTargetScan = CurTime() + BOT_THINK_INTERVAL

	if bot.ZCBotTarget ~= oldTarget then
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

	if bot.ZCBotTarget ~= oldTarget and IsValid(bot.ZCBotTarget) then
		BotDevPrint(string.format("%s fake target=%s", bot:Name(), bot.ZCBotTarget:Name()))
	end
end

