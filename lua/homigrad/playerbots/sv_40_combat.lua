hg = hg or {}
hg.PlayerBots = hg.PlayerBots or {}
local _ENV = hg.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

function GetBotReactionDelay(dist)
	local distanceFrac = math_Clamp(dist / BOT_REACTION_DISTANCE, 0, 1)
	return math_Lerp(distanceFrac, BOT_REACTION_MIN, BOT_REACTION_MAX)
end

function IsBotReactionReady(bot, target, canPerceive, dist)
	if not canPerceive or not IsValid(target) then
		bot.ZCBotReactionTarget = nil
		bot.ZCBotReactionReadyAt = nil
		return false
	end

	if bot.ZCBotReactionTarget ~= target then
		bot.ZCBotReactionTarget = target
		bot.ZCBotReactionReadyAt = CurTime() + GetBotReactionDelay(dist or 0)
		return false
	end

	return CurTime() >= (bot.ZCBotReactionReadyAt or 0)
end

function GetBotAimSkill(bot)
	if not bot.ZCBotAimSkill then
		bot.ZCBotAimSkill = math_Rand(0.25, 0.85)
	end

	return bot.ZCBotAimSkill
end

function UpdateBotTargetSight(bot, target, canSee)
	if not canSee or not IsValid(target) then
		bot.ZCBotSeenTarget = nil
		bot.ZCBotSeenTargetStart = nil
		return 0
	end

	if bot.ZCBotSeenTarget ~= target then
		bot.ZCBotSeenTarget = target
		bot.ZCBotSeenTargetStart = CurTime()
		return 0
	end

	local seenTime = CurTime() - (bot.ZCBotSeenTargetStart or CurTime())
	return math_Clamp(seenTime / BOT_AIM_LOCK_TIME, 0, 1)
end

function GetBotAimSpread(bot, target, canSee)
	local aimSkill = GetBotAimSkill(bot)
	local sightProgress = UpdateBotTargetSight(bot, target, canSee)
	local curvedProgress = sightProgress * sightProgress
	local baseSpread = math_Lerp(aimSkill, BOT_AIM_SPREAD_MAX, BOT_AIM_SPREAD_MIN)

	if not canSee then return baseSpread * 1.25 end

	return math_Lerp(curvedProgress, baseSpread, BOT_AIM_LOCKED_SPREAD)
end

function GetBotSightTime(bot, target)
	if bot.ZCBotSeenTarget ~= target or not bot.ZCBotSeenTargetStart then return 0 end
	return CurTime() - bot.ZCBotSeenTargetStart
end

function IsBotConfidentToFire(bot, target, dist, aimSpread)
	if dist <= BOT_CQB_MAGDUMP_RANGE then return true end
	if dist < BOT_LONG_RANGE_CONFIDENCE_RANGE then
		return GetBotSightTime(bot, target) >= BOT_LONG_RANGE_MIN_SIGHT_TIME * 0.5
	end

	if GetBotSightTime(bot, target) < BOT_LONG_RANGE_MIN_SIGHT_TIME then return false end
	return aimSpread <= BOT_LONG_RANGE_MAX_SPREAD
end

function GetBotBurstSpread(bot, target, shouldFire)
	if not shouldFire or not IsValid(target) then
		bot.ZCBotBurstTarget = nil
		bot.ZCBotBurstStart = nil
		return 0
	end

	if bot.ZCBotBurstTarget ~= target then
		bot.ZCBotBurstTarget = target
		bot.ZCBotBurstStart = CurTime()
		return BOT_AIM_OPENING_BURST_SPREAD
	end

	local burstTime = CurTime() - (bot.ZCBotBurstStart or CurTime())
	local burstProgress = math_Clamp(burstTime / BOT_AIM_BURST_SETTLE_TIME, 0, 1)
	return math_Lerp(burstProgress * burstProgress, BOT_AIM_OPENING_BURST_SPREAD, 0)
end

function ApplyBotAimSpread(bot, aimAng, spread)
	if spread <= 0 then return aimAng end

	if (bot.ZCBotAimNoiseNext or 0) <= CurTime() then
		bot.ZCBotAimNoiseNext = CurTime() + BOT_AIM_NOISE_INTERVAL
		bot.ZCBotAimNoisePitch = math_Rand(-spread, spread)
		bot.ZCBotAimNoiseYaw = math_Rand(-spread, spread)
	end

	aimAng.p = aimAng.p + (bot.ZCBotAimNoisePitch or 0)
	aimAng.y = aimAng.y + (bot.ZCBotAimNoiseYaw or 0)
	return aimAng
end

function AimBotAt(bot, cmd, aimPos, spread, smooth)
	local aimOrigin = GetBotAimOrigin(bot)
	local toAim = aimPos - aimOrigin
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local currentAng = bot:EyeAngles()
	local aimAng = toAim:Angle()
	if Vector(toAim.x, toAim.y, 0):LengthSqr() <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
		aimAng.y = currentAng.y
	end

	aimAng.p = aimAng.p + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng.y = aimAng.y + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng = ApplyBotAimSpread(bot, aimAng, spread or 0)
	aimAng = SetBotViewAngles(bot, cmd, aimAng, smooth or BOT_AIM_SMOOTH_COMBAT)

	local muzzleOrigin = GetBotAimOrigin(bot)
	local muzzleToAim = aimPos - muzzleOrigin
	local muzzleDistSqr = muzzleToAim:LengthSqr()
	if muzzleDistSqr > 1 and muzzleDistSqr > BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE * BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE then
		local muzzleAng = muzzleToAim:Angle()
		if Vector(muzzleToAim.x, muzzleToAim.y, 0):LengthSqr() <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
			muzzleAng.y = aimAng.y
		end

		aimAng = SetBotViewAngles(bot, cmd, muzzleAng, smooth or BOT_AIM_SMOOTH_COMBAT)
		aimOrigin = muzzleOrigin
		toAim = muzzleToAim
	end


	return aimAng, toAim:Length()
end

function FaceRecentThreat(bot, cmd)
	if (bot.ZCBotThreatUntil or 0) <= CurTime() or not isvector(bot.ZCBotThreatPos) then return false end

	local toThreat = bot.ZCBotThreatPos - bot:EyePos()
	if toThreat:LengthSqr() <= 1 then return false end

	SetBotViewAngles(bot, cmd, toThreat:Angle(), BOT_AIM_SMOOTH_COMBAT)
	return true
end

function RememberBotThreat(bot, attacker, threatPos)
	if not zc_playerbot_ai:GetBool() or not IsValid(bot) or not bot:IsPlayer() or not bot:IsBot() then return end
	if not bot:Alive() then return end

	if IsValid(attacker) and attacker.GetOwner then
		local owner = attacker:GetOwner()
		if IsValid(owner) then attacker = owner end
	end

	if attacker == bot then return end
	if IsValid(attacker) and attacker:IsPlayer() and attacker:Alive() then
		bot.ZCBotThreatAttacker = attacker
		bot.ZCBotTarget = attacker
		bot.ZCBotNextTargetScan = 0
	end

	if not isvector(threatPos) or threatPos:IsZero() then
		if IsValid(attacker) then threatPos = attacker:WorldSpaceCenter() end
	end
	if not isvector(threatPos) or threatPos:IsZero() then return end

	bot.ZCBotThreatPos = threatPos
	bot.ZCBotThreatUntil = CurTime() + BOT_THREAT_MEMORY_TIME
end

function FleeFromBotEnemy(bot, cmd, enemy, aimAng, desiredDistance)
	if not IsValid(enemy) then return false end

	local body = GetBotTargetBody(enemy)
	local enemyPos = GetBotTargetBodyPos(enemy, body)
	local away = bot:GetPos() - enemyPos
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:EyeAngles():Forward()
	else
		away:Normalize()
	end

	local fleePos = bot:GetPos() + away * (desiredDistance or BOT_SAFE_ENEMY_AVOID_DEST)
	fleePos = BiasPosTowardDeathmatchCenter(bot, fleePos, GetCurrentRound())

	local lookPos = IsValid(enemy) and enemy:EyePos() or enemyPos
	aimAng = aimAng or (lookPos - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_COMBAT)

	local followedPath = FollowBotPath(bot, cmd, fleePos, aimAng, 430, false, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, fleePos, aimAng, 380)
		TryBotTravelSprint(bot, cmd, fleePos)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, fleePos)
	end

	return true
end

function EvadeTarget(bot, cmd, target, aimAng)
	if not IsValid(target) then return end

	local body = GetBotTargetBody(target)
	local away = bot:GetPos() - GetBotTargetBodyPos(target, body)
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:EyeAngles():Forward() * -1
	end

	away:Normalize()
	local right = Angle(0, aimAng.y, 0):Right()
	local side = bot.ZCBotReloadEvadeSide
	if not side or (bot.ZCBotNextReloadEvadeSide or 0) < CurTime() then
		side = math_random(0, 1) == 1 and 1 or -1
		bot.ZCBotReloadEvadeSide = side
		bot.ZCBotNextReloadEvadeSide = CurTime() + math_Rand(0.8, 1.5)
	end

	local evadePos = bot:GetPos() + away * BOT_RELOAD_EVADE_DISTANCE + right * side * 260
	evadePos = BiasPosTowardDeathmatchCenter(bot, evadePos, GetCurrentRound())
	SetBotMovementToward(bot, cmd, evadePos, aimAng, 360)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, evadePos)
end

function ResetBotReloadState(bot)
	bot.ZCBotReloadWeapon = nil
	bot.ZCBotReloadStartClip = nil
	bot.ZCBotReloadGoalClip = nil
	bot.ZCBotReloadPulseUntil = nil
end

function IsWeaponReloadBusy(wep)
	if not IsValid(wep) then return false end
	if wep.reload then return true end

	local nextCycle = wep.GetNetVar and wep:GetNetVar("shootgunReload", 0) or 0
	return nextCycle > CurTime()
end

function TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime)
	if safeTime or not IsRangedWeapon(wep) then return false end

	local needsCycle = ShouldCycleManualAction(wep)
	local dry = IsWeaponDry(wep)
	local busy = IsWeaponReloadBusy(wep)
	local enemyNearby = rawDist <= BOT_COMBAT_RELOAD_ENEMY_RANGE
	local continuingSingleReload = bot.ZCBotReloadWeapon == wep and IsSingleRoundReloadWeapon(wep) and wep:Clip1() < (bot.ZCBotReloadGoalClip or 0)

	if not needsCycle and not dry and not busy and not continuingSingleReload then
		ResetBotReloadState(bot)
		return false
	end

	if needsCycle then
		BotPressReload(bot, cmd, wep)
		EvadeTarget(bot, cmd, target, aimAng)
		return true
	end

	if not HasReserveAmmoForWeapon(bot, wep) and not busy then
		EvadeTarget(bot, cmd, target, aimAng)
		return true
	end

	if bot.ZCBotReloadWeapon ~= wep then
		bot.ZCBotReloadWeapon = wep
		bot.ZCBotReloadStartClip = wep:Clip1()
		bot.ZCBotReloadGoalClip = GetReloadGoalClip(bot, wep, enemyNearby)
	end

	local goalClip = bot.ZCBotReloadGoalClip or GetReloadGoalClip(bot, wep, enemyNearby)
	if IsSingleRoundReloadWeapon(wep) and wep:Clip1() >= goalClip and not dry and not busy then
		ResetBotReloadState(bot)
		return false
	end

	if ShouldReloadWeapon(bot, wep) or busy then
		BotPressReload(bot, cmd, wep)
	end

	EvadeTarget(bot, cmd, target, aimAng)
	return true
end

function GetRagdollHeadAimPos(body)
	if not IsValid(body) then return end
	if body:IsPlayer() then return body:EyePos() end

	return GetEntityBonePos(body, "ValveBiped.Bip01_Head1") or body:WorldSpaceCenter()
end

function TryBotMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, safeTime)
	if not IsRagdolledTarget(target) or attackDist > attackRange then return false end

	local headPos = GetRagdollHeadAimPos(body)
	if not isvector(headPos) then return false end

	local aimAng = AimBotAt(bot, cmd, headPos, 0, BOT_AIM_SMOOTH_COMBAT)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_DUCK))

	if not safeTime then
		BotPressMeleeAttack(bot, cmd, wep)
	end

	return true
end

function HoldAndScan(bot, cmd)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)

	if (bot.ZCBotNextScanTurn or 0) <= CurTime() then
		bot.ZCBotNextScanTurn = CurTime() + math_Rand(1.1, 1.8)
		bot.ZCBotScanYaw = bot:EyeAngles().y + math_Rand(75, 135) * (math_random(0, 1) == 1 and 1 or -1)
	end

	local scanAng = Angle(0, bot.ZCBotScanYaw or bot:EyeAngles().y, 0)
	return SetBotViewAngles(bot, cmd, scanAng, BOT_AIM_SMOOTH_TRAVEL)
end

function GetBotFakeAimButtons()
	local buttons = IN_ATTACK2
	local alwaysRagdollAim = GetConVar("zc_always_ragdoll_aim")
	if not (alwaysRagdollAim and alwaysRagdollAim:GetBool()) then
		buttons = bit_bor(buttons, IN_USE)
	end

	return buttons
end

function PublishBotFakeControl(bot, cmd)
	if not IsValid(bot) then return end

	local viewAng = cmd:GetViewAngles()
	bot.ZCBotFakeEyeAngles = Angle(viewAng.p, viewAng.y, viewAng.r)
	bot.ZCBotFakeButtons = cmd:GetButtons()
	bot.ZCBotFakeControlUntil = CurTime() + 0.25
end

function GetBotOwnFakeRagdoll(bot)
	return GetBotFakeRagdollEntity(bot)
end

function GetBotFakeAimOrigin(bot)
	return GetBotSightOrigin(bot)
end

function AimBotFakeAt(bot, cmd, aimPos, smooth)
	local origin = GetBotFakeAimOrigin(bot)
	local toAim = aimPos - origin
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local currentAng = bot:EyeAngles()
	local aimAng = toAim:Angle()
	if Vector(toAim.x, toAim.y, 0):LengthSqr() <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
		aimAng.y = currentAng.y
	end

	aimAng = SetBotViewAngles(bot, cmd, aimAng, smooth or 1)

	local muzzleOrigin = GetBotAimOrigin(bot)
	local muzzleToAim = aimPos - muzzleOrigin
	local muzzleDistSqr = muzzleToAim:LengthSqr()
	if muzzleDistSqr > 1 and muzzleDistSqr > BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE * BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE then
		local muzzleAng = muzzleToAim:Angle()
		if Vector(muzzleToAim.x, muzzleToAim.y, 0):LengthSqr() <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
			muzzleAng.y = aimAng.y
		end

		aimAng = SetBotViewAngles(bot, cmd, muzzleAng, smooth or 1)
		origin = muzzleOrigin
		toAim = muzzleToAim
	end

	bot.ZCBotFakeEyeAngles = Angle(aimAng.p, aimAng.y, aimAng.r)
	bot.ZCBotFakeControlUntil = CurTime() + 0.25
	return aimAng, toAim:Length()
end

function FakeSpinScan(bot, cmd)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)

	local now = CurTime()
	local lastTime = bot.ZCBotFakeScanLastTime or now
	local delta = math_Clamp(now - lastTime, 0, 0.1)
	bot.ZCBotFakeScanLastTime = now

	if not bot.ZCBotFakeScanYaw then
		bot.ZCBotFakeScanYaw = bot:EyeAngles().y
	end

	if not bot.ZCBotFakeScanSide or (bot.ZCBotNextFakeScanReverse or 0) <= now then
		bot.ZCBotFakeScanSide = (bot.ZCBotFakeScanSide or (math_random(0, 1) == 1 and 1 or -1)) * -1
		bot.ZCBotNextFakeScanReverse = now + math_Rand(BOT_FAKE_SCAN_REVERSE_INTERVAL_MIN, BOT_FAKE_SCAN_REVERSE_INTERVAL_MAX)
	end

	bot.ZCBotFakeScanYaw = math.NormalizeAngle(bot.ZCBotFakeScanYaw + BOT_FAKE_SCAN_TURN_RATE * bot.ZCBotFakeScanSide * delta)
	local scanAng = Angle(0, bot.ZCBotFakeScanYaw, 0)
	return SetBotViewAngles(bot, cmd, scanAng, 1)
end

function FakeHoldAndScan(bot, cmd)
	FakeSpinScan(bot, cmd)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), GetBotFakeAimButtons()))
	ClearBotMovementInput(cmd)
end

function PickDeathmatchCenterPatrolArea(bot, center, round)
	if not navmesh or not navmesh.GetAllNavAreas then return nil end
	if (bot.ZCBotNextCenterPatrolPick or 0) > CurTime() and IsValid(bot.ZCBotCenterPatrolArea) then return bot.ZCBotCenterPatrolArea end

	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then return nil end

	local botPos = bot:GetPos()
	local bestArea
	local bestScore = -math_huge
	local tries = math_min(#areas, BOT_ROAM_AREA_SAMPLES)

	for _ = 1, tries do
		local area = areas[math_random(1, #areas)]
		if not IsValid(area) then continue end

		local pos = GetAreaWaypoint(area)
		local centerDist = pos:Distance(center)
		if centerDist > BOT_ZONE_CENTER_PATROL_RADIUS then continue end
		if botPos:DistToSqr(pos) < BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then continue end
		if not IsPosInsideDeathmatchZone(pos, round, BOT_ZONE_ROAM_MARGIN) then continue end

		local score = centerDist + math_Rand(0, 350)
		if score > bestScore then
			bestScore = score
			bestArea = area
		end
	end

	bot.ZCBotCenterPatrolArea = bestArea
	bot.ZCBotNextCenterPatrolPick = CurTime() + BOT_ZONE_CENTER_PATROL_INTERVAL + math_Rand(0, 1.5)
	return bestArea
end

function RoamBot(bot, cmd)
	local round = GetCurrentRound()
	local center = GetDeathmatchZoneInfo(round)
	if center and ShouldSeekDeathmatchZoneCenter(round) then
		if MoveToDeathmatchZoneCenter(bot, cmd, round, true, BOT_ZONE_CENTER_REACH) then return end

		local area = PickDeathmatchCenterPatrolArea(bot, center, round)
		if not IsValid(area) then
			HoldAndScan(bot, cmd)
			return
		end

		local destPos = GetAreaWaypoint(area)
		if bot:GetPos():DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
			bot.ZCBotCenterPatrolArea = nil
			bot.ZCBotNextCenterPatrolPick = 0
			HoldAndScan(bot, cmd)
			return
		end

		local aimAng = (destPos - bot:EyePos()):Angle()
		aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

		local followedPath, reached = FollowBotPath(bot, cmd, destPos, aimAng, 330, true, false)
		if reached then
			bot.ZCBotCenterPatrolArea = nil
			bot.ZCBotNextCenterPatrolPick = 0
		elseif not followedPath then
			SetBotMovementToward(bot, cmd, destPos, aimAng, 260)
			ApplyBotUnstuckMove(bot, cmd)
			ApplyBotObstacleAvoidance(bot, cmd, aimAng)
			UpdateBotStuckState(bot, cmd, destPos)
		end

		return
	end

	local area = PickRandomRoamArea(bot)

	for _ = 1, 5 do
		if not IsValid(area) or IsPosInsideDeathmatchZone(GetAreaWaypoint(area), round, BOT_ZONE_ROAM_MARGIN) then break end

		bot.ZCBotRoamArea = nil
		bot.ZCBotNextRoamPick = 0
		area = PickRandomRoamArea(bot)
	end

	if not IsValid(area) then return end

	local destPos = GetAreaWaypoint(area)
	if bot:GetPos():DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		bot.ZCBotRoamArea = nil
		bot.ZCBotNextRoamPick = 0
		bot.ZCBotPath = nil
		bot.ZCBotPathIndex = nil

		area = PickRandomRoamArea(bot)
		if not IsValid(area) then return end
		destPos = GetAreaWaypoint(area)
	end

	if not IsPosInsideDeathmatchZone(destPos, round, BOT_ZONE_ROAM_MARGIN) then
		AvoidDeathmatchZone(bot, cmd, round)
		return
	end

	local aimAng = (destPos - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

	local followedPath, reached = FollowBotPath(bot, cmd, destPos, aimAng, 390, true, true)
	if reached then
		bot.ZCBotRoamArea = nil
		bot.ZCBotNextRoamPick = 0
		bot.ZCBotPath = nil
		bot.ZCBotPathIndex = nil
	elseif not followedPath then
		SetBotMovementToward(bot, cmd, destPos, aimAng, 320)
		TryBotTravelSprint(bot, cmd, destPos)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, destPos)
	end
end

function TryBotAttackCurrentTarget(bot, cmd, safeTime, ignoreFOV)
	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then return false end

	local body = GetBotTargetBody(target)
	local aimPos, canSee = ignoreFOV and GetVisibleTargetAimPosNoFOV(bot, body) or GetVisibleTargetAimPos(bot, body)
	if not canSee then return false end

	local fakeCombat = ignoreFOV == true
	local rawDist = aimPos:Distance(fakeCombat and GetBotFakeAimOrigin(bot) or bot:EyePos())
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	local attackRange = meleeWeapon and GetMeleeWeaponAttackRange(wep) or BOT_ATTACK_RANGE
	local reactionReady = IsBotReactionReady(bot, target, canSee, rawDist)
	local baseAimSpread = GetBotAimSpread(bot, target, true)
	local tapTarget = IsUnconsciousTarget(target)
	local targetBodyPos = GetBotTargetBodyPos(target, body)
	local meleeOffset = targetBodyPos - bot:GetPos()
	meleeOffset.z = 0
	local attackDist = meleeWeapon and meleeOffset:Length() or rawDist
	local shouldFire = not safeTime and attackDist <= attackRange and (meleeWeapon or (fakeCombat and IsWeaponReadyToFire(wep)) or (reactionReady and IsBotConfidentToFire(bot, target, rawDist, baseAimSpread)))
	local aimSpread = baseAimSpread + (tapTarget and 0 or GetBotBurstSpread(bot, target, shouldFire))
	local aimAng
	if fakeCombat then
		aimAng = AimBotFakeAt(bot, cmd, aimPos, 1)
	else
		aimAng = AimBotAt(bot, cmd, aimPos, aimSpread)
	end

	if TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
		return true
	end

	if meleeWeapon and TryBotMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, safeTime) then
		return true
	end

	if shouldFire then
		if tapTarget then
			BotTapAttack(bot, cmd, wep)
		elseif meleeWeapon then
			BotPressMeleeAttack(bot, cmd, wep)
		else
			BotPressAttack(bot, cmd, wep, rawDist)
		end
	end

	return true
end

function FaceFakeCombatTarget(bot, cmd, safeTime)
	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then return false end

	local body = GetBotTargetBody(target)
	if not IsValid(body) then return false end

	local aimPos, canSee = GetVisibleTargetAimPosNoFOV(bot, body)
	if not canSee then
		aimPos = GetTargetAimPos(body, bot)
	end
	if not isvector(aimPos) then return false end

	local aimAng = AimBotFakeAt(bot, cmd, aimPos, 1)
	local rawDist = aimPos:Distance(GetBotFakeAimOrigin(bot))
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	local attackRange = meleeWeapon and GetMeleeWeaponAttackRange(wep) or BOT_ATTACK_RANGE
	local tapTarget = IsUnconsciousTarget(target)
	local chasePos = GetBotTargetBodyPos(target, body)
	local meleeOffset = chasePos - bot:GetPos()
	meleeOffset.z = 0

	if TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
		return true
	end

	local attackDist = meleeWeapon and meleeOffset:Length() or rawDist
	local shouldFire = not safeTime and canSee and attackDist <= attackRange and (meleeWeapon or IsWeaponReadyToFire(wep))

	if shouldFire then
		if tapTarget then
			BotTapAttack(bot, cmd, wep)
		elseif meleeWeapon then
			BotPressMeleeAttack(bot, cmd, wep)
		else
			BotPressAttack(bot, cmd, wep, rawDist)
		end
	end

	return true
end

function HandleBotFakeState(bot, cmd, safeTime)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then return false end

	if fakeState == hg.FAKE_STATE.ACTIVE then
		UpdateBotFakeTarget(bot)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), GetBotFakeAimButtons()))
		if not TryBotAttackCurrentTarget(bot, cmd, safeTime, true) and not FaceFakeCombatTarget(bot, cmd, safeTime) and not FaceRecentThreat(bot, cmd) then
			FakeHoldAndScan(bot, cmd)
		end
		ClearBotMovementInput(cmd)
		TryBotFakeUp(bot)
		ClearBotMovementInput(cmd)
		if safeTime then ClearCombatButtons(cmd) end
		PublishBotFakeControl(bot, cmd)
		return true
	end

	return true
end

function HandleBotThreatResponse(bot, cmd, safeTime)
	local attacker = bot.ZCBotThreatAttacker
	if (bot.ZCBotThreatUntil or 0) <= CurTime() or not IsUsableTarget(bot, attacker) then return false end

	local body = GetBotTargetBody(attacker)
	local aimPos, canSee = GetVisibleTargetAimPosNoFOV(bot, body)
	if not canSee then
		return FaceRecentThreat(bot, cmd)
	end

	local wep = SelectBotWeapon(bot)
	local botHasGun = IsRangedWeapon(wep) and HasAmmoForWeapon(bot, wep)
	local meleeOrUnarmed = IsMeleeWeapon(wep)
	local enemyPos = GetBotTargetBodyPos(attacker, body)
	local flatOffset = enemyPos - bot:GetPos()
	flatOffset.z = 0
	local flatDist = flatOffset:Length()

	bot.ZCBotTarget = attacker
	bot.ZCBotNextTargetScan = CurTime() + BOT_THINK_INTERVAL

	if botHasGun then
		return TryBotAttackCurrentTarget(bot, cmd, safeTime, true)
	end

	if meleeOrUnarmed and flatDist > BOT_THREAT_ESCAPE_RANGE then
		return FleeFromBotEnemy(bot, cmd, attacker, nil, BOT_UNARMED_FLEE_RANGE)
	end

	return false
end

function IsVisibleEnemyArmed(enemy)
	if not IsValid(enemy) then return false end

	local wep = enemy.GetActiveWeapon and enemy:GetActiveWeapon()
	return IsMeaningfullyArmedWeapon(wep)
end

hook.Add("StartCommand", "ZC_PlayerBotEnemyAI", function(bot, cmd)
	if !bot:IsBot() then return end

	cmd:ClearMovement()
	cmd:ClearButtons()
	
	if not zc_playerbot_ai:GetBool() then return end

	if not bot:Alive() then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return
	end

	local round = GetCurrentRound()
	if IsRoundFadeInTime(round) then return end

	local safeTime = IsDeathmatchSafeTime(round)
	if safeTime then ClearCombatButtons(cmd) end

	if HandleBotFakeState(bot, cmd, safeTime) then return end
	if safeTime and AvoidEnemiesDuringSafeTime(bot, cmd, round) then
		ClearCombatButtons(cmd)
		return
	end

	if not HasVisibleEnemy(bot) and TryBotSelfCare(bot, cmd) then return end
	if HandleBotThreatResponse(bot, cmd, safeTime) then
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	UpdateBotTarget(bot)

	local target = bot.ZCBotTarget
	local hasCombatTarget = IsUsableTarget(bot, target) and CanCurrentlyTarget(bot, target)

	if not hasCombatTarget and AvoidDeathmatchZone(bot, cmd, round) then
		TryBotAttackCurrentTarget(bot, cmd, safeTime)
		if safeTime then ClearCombatButtons(cmd) end
		return
	end
	if not hasCombatTarget and ShouldSeekDeathmatchZoneCenter(round) and not IsUprightThreat(bot.ZCBotTarget) and MoveToDeathmatchZoneCenter(bot, cmd, round, true) then
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	if not IsUsableTarget(bot, target) then
		RoamBot(bot, cmd)
		FaceRecentThreat(bot, cmd)
		return
	end

	local body = GetBotTargetBody(target)
	local aimPos, canSee = GetVisibleTargetAimPos(bot, body)
	if not canSee then
		ClearBotTarget(bot)
		RoamBot(bot, cmd)
		FaceRecentThreat(bot, cmd)
		return
	end

	local rawDist = aimPos:Distance(bot:EyePos())
	if rawDist <= 1 then return end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	if IsUnarmedWeapon(wep) and IsVisibleEnemyArmed(target) then
		FleeFromBotEnemy(bot, cmd, target, nil, BOT_UNARMED_FLEE_RANGE)
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	local chasePos = GetBotTargetBodyPos(target, body)
	local flat = (meleeWeapon and chasePos or aimPos) - bot:GetPos()
	flat.z = 0
	local flatDist = flat:Length()
	if flatDist > 1 then flat:Normalize() end
	local attackRange = meleeWeapon and GetMeleeWeaponAttackRange(wep) or BOT_ATTACK_RANGE
	local reactionReady = IsBotReactionReady(bot, target, canSee, rawDist)
	local baseAimSpread = GetBotAimSpread(bot, target, canSee)
	local tapTarget = IsUnconsciousTarget(target)
	local attackDist = meleeWeapon and flatDist or rawDist
	local shouldFire = not safeTime and canSee and attackDist <= attackRange and (meleeWeapon or (reactionReady and IsBotConfidentToFire(bot, target, rawDist, baseAimSpread)))
	local aimSpread = baseAimSpread + (tapTarget and 0 or GetBotBurstSpread(bot, target, shouldFire))
	local meleeLookPos = (meleeWeapon and not IsRagdolledTarget(target)) and target:EyePos() or aimPos
	local aimAng, dist = AimBotAt(bot, cmd, meleeLookPos, meleeWeapon and 0 or aimSpread)
	if dist <= 1 then return end
	if TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
		return
	end

	if meleeWeapon then
		if TryBotPickupNearbyWeapon(bot, cmd, aimAng) then return end
		if TryBotMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, safeTime) then return end

		if flatDist > attackRange * 0.85 then
			local followedPath, reached = false, false
			if flatDist > BOT_NAV_DEST_REACH then
				followedPath, reached = FollowBotPath(bot, cmd, chasePos, aimAng, 460, false, false)
			end

			if not followedPath or reached then
				SetBotMovementToward(bot, cmd, chasePos, aimAng, 430)
				ApplyBotUnstuckMove(bot, cmd)
				if flatDist > BOT_CLOSE_RANGE then
					ApplyBotObstacleAvoidance(bot, cmd, aimAng)
				end
				UpdateBotStuckState(bot, cmd, chasePos)
			end

			if flatDist > BOT_CLOSE_RANGE and GetBotStaminaFraction(bot) > BOT_SPRINT_STAMINA_FRACTION then
				cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_SPEED))
			end
		else
			cmd:SetForwardMove(120)
			cmd:SetSideMove(0)
			UpdateBotStuckState(bot, cmd, chasePos)
		end

		if shouldFire then
			BotPressMeleeAttack(bot, cmd, wep)
		end

		return
	end

	if not canSee and (ShouldSeekDeathmatchZoneCenter(round) or IsDeathmatchZoneClose(bot, round)) and MoveToDeathmatchZoneCenterWhileAiming(bot, cmd, round, aimAng, 420) then
		if shouldFire then
			if tapTarget then
				BotTapAttack(bot, cmd, wep)
			else
				BotPressAttack(bot, cmd, wep, rawDist)
			end
		end

		return
	end

	if canSee and flatDist <= BOT_STRAFE_RANGE then
		if flatDist > BOT_CLOSE_RANGE then
			cmd:SetForwardMove(220)
		else
			cmd:SetForwardMove(-160)
		end

		if not bot.ZCBotStrafeSide or (bot.ZCBotNextStrafe or 0) < CurTime() then
			bot.ZCBotStrafeSide = math_random(0, 1) == 1 and 1 or -1
			bot.ZCBotNextStrafe = CurTime() + math_Rand(0.8, 1.8)
		end

		cmd:SetSideMove(bot.ZCBotStrafeSide * 220)
		ApplyDeathmatchCenterMovementBias(bot, cmd, aimAng, round)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, aimPos)
	elseif flatDist > BOT_CLOSE_RANGE then
		local moveGoal = BiasPosTowardDeathmatchCenter(bot, aimPos, round)
		local followedPath = FollowBotPath(bot, cmd, moveGoal, aimAng, 400, not canSee, not canSee)
		if not followedPath then
			SetBotMovementToward(bot, cmd, moveGoal, aimAng, 320)
			if not canSee then
				TryBotTravelSprint(bot, cmd, moveGoal)
			end

			ApplyBotUnstuckMove(bot, cmd)
			ApplyBotObstacleAvoidance(bot, cmd, aimAng)
			UpdateBotStuckState(bot, cmd, moveGoal)
		end
	else
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
	end

	if shouldFire then
		if tapTarget then
			BotTapAttack(bot, cmd, wep)
		else
			BotPressAttack(bot, cmd, wep, rawDist)
		end
	end
end)

hook.Add("ZC_OnFakeRagdollCreated", "ZC_PlayerBotFakeUpInitialDelay", function(ply)
	if not zc_playerbot_ai:GetBool() or not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end

	ply.ZCBotFakeUpAllowedAt = CurTime() + BOT_FAKEUP_INITIAL_DELAY
	ply.ZCBotNextFakeUpTry = ply.ZCBotFakeUpAllowedAt
end)

hook.Add("EntityTakeDamage", "ZC_PlayerBotRememberShotDirection", function(ent, dmg)
	if not zc_playerbot_ai:GetBool() or not IsValid(ent) or not ent:IsPlayer() or not ent:IsBot() then return end
	if not ent:Alive() then return end

	local attacker = dmg:GetAttacker()
	local threatPos = dmg:GetDamagePosition()
	if not isvector(threatPos) or threatPos:IsZero() then
		if IsValid(attacker) then
			threatPos = attacker:WorldSpaceCenter()
		else
			local inflictor = dmg:GetInflictor()
			if IsValid(inflictor) then threatPos = inflictor:WorldSpaceCenter() end
		end
	end

	RememberBotThreat(ent, attacker, threatPos)
end)

hook.Add("ZC_PostEntityFireBullets", "ZC_PlayerBotNoticeSuppression", function(ent, bullet)
	if not zc_playerbot_ai:GetBool() or not bullet or not bullet.Trace then return end

	local tr = bullet.Trace
	if not isvector(tr.StartPos) or not isvector(tr.HitPos) then return end

	local attacker = bullet.Attacker
	if not IsValid(attacker) and IsValid(ent) then
		attacker = ent.GetOwner and ent:GetOwner() or ent
	end
	if not IsValid(attacker) then return end

	for _, bot in player.Iterator() do
		if not bot:IsBot() or not bot:Alive() or bot == attacker then continue end

		local dist, nearestPos = util.DistanceToLine(tr.StartPos, tr.HitPos, bot:EyePos())
		if dist > BOT_SUPPRESSION_AWARENESS_DISTANCE then continue end

		local visible = not util.TraceLine({
			start = nearestPos,
			endpos = bot:EyePos(),
			filter = {bot, GetBotFakeRagdollEntity(bot), attacker},
			mask = MASK_SHOT
		}).Hit
		if not visible then continue end

		RememberBotThreat(bot, attacker, tr.StartPos)
	end
end)
