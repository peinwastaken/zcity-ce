zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local math_Rand, math_random, math_min, math_Clamp = math_Rand, math_random, math_min, math_Clamp
local Angle, engine = Angle, engine
local util = util

local alwaysRagdollAimConVar

-- Loose preferred range bands per weapon fire category. These shape movement
-- and fire rhythm; they are not fixed positions.
local RANGE_PROFILES = {
	melee   = { min = 0,   ideal = 60,   max = BOT_MELEE_ATTACK_RANGE },
	shotgun = { min = 150, ideal = 330,  max = 780 },
	pistol  = { min = 320, ideal = 640,  max = 1150 },
	rifle   = { min = 680, ideal = 1020, max = BOT_ATTACK_RANGE },
}

local BOT_MOVE_COMMIT_MIN = 0.8
local BOT_MOVE_COMMIT_MAX = 1.3

local BOT_REACTION_MIN = 0.18
local BOT_REACTION_MAX = 0.85
local BOT_REACTION_DISTANCE = 2400
local BOT_AIM_JITTER = 0.018
local BOT_AIM_SPREAD_MIN = 1.2
local BOT_AIM_SPREAD_MAX = 7.5
local BOT_AIM_LOCK_TIME = 3.5
local BOT_AIM_NOISE_INTERVAL = 0.16
local BOT_AIM_LOCKED_SPREAD = 0.45
local BOT_AIM_BURST_SETTLE_TIME = 1.2
local BOT_AIM_OPENING_BURST_SPREAD = 5.5
local BOT_LONG_RANGE_CONFIDENCE_RANGE = 1100
local BOT_LONG_RANGE_MAX_SPREAD = 3.4
local BOT_LONG_RANGE_MIN_SIGHT_TIME = 0.55
local BOT_VERTICAL_AIM_YAW_DEADZONE = 24
local BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE = 260
local BOT_CLOSE_RANGE = 170
local BOT_STRAFE_RANGE = 700
local BOT_ATTACK_RANGE = 1800
local BOT_RELOAD_EVADE_DISTANCE = 700
local BOT_COMBAT_RELOAD_ENEMY_RANGE = 950
local BOT_FAKE_SCAN_TURN_RATE = 155
local BOT_FAKE_SCAN_REVERSE_INTERVAL_MIN = 4
local BOT_FAKE_SCAN_REVERSE_INTERVAL_MAX = 7

local AimBotFakeAt

-- One clear function for everything that must reset when the target changes.
function ResetCombatTargetTransition(state)
	local combat = state.combat
	combat.seenTarget = nil
	combat.seenStart = nil
	combat.aimNoiseNext = 0
	combat.burstTarget = nil
	combat.burstStart = nil
	combat.reactionTarget = nil
	combat.reactionReadyAt = nil
	combat.attackReleaseUntil = nil
	combat.reloadWeapon = nil
	combat.reloadStartClip = nil
	combat.reloadGoalClip = nil
	combat.reloadPulseUntil = nil
	combat.autoBurstUntil = nil
	combat.autoBurstPauseUntil = nil
	combat.tapAttackUntil = nil
end

local function GetBotReactionDelay(dist)
	local distanceFrac = math_Clamp(dist / BOT_REACTION_DISTANCE, 0, 1)
	return math_Lerp(distanceFrac, BOT_REACTION_MIN, BOT_REACTION_MAX)
end

local function IsBotReactionReady(bot, target, canPerceive, dist)
	local combat = bot.ZCBotAI.combat
	if not canPerceive or not IsValid(target) then
		combat.reactionTarget = nil
		combat.reactionReadyAt = nil
		return false
	end

	if combat.reactionTarget ~= target then
		combat.reactionTarget = target
		combat.reactionReadyAt = CurTime() + GetBotReactionDelay(dist or 0)
		return false
	end

	return CurTime() >= (combat.reactionReadyAt or 0)
end

local function GetBotAimSkill(bot)
	local combat = bot.ZCBotAI.combat
	if not combat.aimSkill then
		-- One small randomized skill value per bot so bots do not behave identically.
		combat.aimSkill = math_Rand(0.25, 0.85)
	end

	return combat.aimSkill
end

local function UpdateBotTargetSight(bot, target, canSee)
	local combat = bot.ZCBotAI.combat
	if not canSee or not IsValid(target) then
		combat.seenTarget = nil
		combat.seenStart = nil
		return 0
	end

	if combat.seenTarget ~= target then
		combat.seenTarget = target
		combat.seenStart = CurTime()
		return 0
	end

	local seenTime = CurTime() - (combat.seenStart or CurTime())
	return math_Clamp(seenTime / BOT_AIM_LOCK_TIME, 0, 1)
end

local function GetBotAimSpread(bot, target, canSee)
	local aimSkill = GetBotAimSkill(bot)
	local sightProgress = UpdateBotTargetSight(bot, target, canSee)
	local curvedProgress = sightProgress * sightProgress
	local baseSpread = math_Lerp(aimSkill, BOT_AIM_SPREAD_MAX, BOT_AIM_SPREAD_MIN)

	if not canSee then return baseSpread * 1.25 end

	return math_Lerp(curvedProgress, baseSpread, BOT_AIM_LOCKED_SPREAD)
end

local function GetBotSightTime(bot, target)
	local combat = bot.ZCBotAI.combat
	if combat.seenTarget ~= target or not combat.seenStart then return 0 end
	return CurTime() - combat.seenStart
end

local function IsBotConfidentToFire(bot, target, dist, aimSpread)
	if dist <= BOT_CQB_MAGDUMP_RANGE then return true end
	if dist < BOT_LONG_RANGE_CONFIDENCE_RANGE then
		return GetBotSightTime(bot, target) >= BOT_LONG_RANGE_MIN_SIGHT_TIME * 0.5
	end

	if GetBotSightTime(bot, target) < BOT_LONG_RANGE_MIN_SIGHT_TIME then return false end
	return aimSpread <= BOT_LONG_RANGE_MAX_SPREAD
end

local function GetBotBurstSpread(bot, target, shouldFire)
	local combat = bot.ZCBotAI.combat
	if not shouldFire or not IsValid(target) then
		combat.burstTarget = nil
		combat.burstStart = nil
		return 0
	end

	if combat.burstTarget ~= target then
		combat.burstTarget = target
		combat.burstStart = CurTime()
		return BOT_AIM_OPENING_BURST_SPREAD
	end

	local burstTime = CurTime() - (combat.burstStart or CurTime())
	local burstProgress = math_Clamp(burstTime / BOT_AIM_BURST_SETTLE_TIME, 0, 1)
	return math_Lerp(burstProgress * burstProgress, BOT_AIM_OPENING_BURST_SPREAD, 0)
end

local function ApplyBotAimSpread(bot, aimAng, spread)
	if spread <= 0 then return aimAng end

	local combat = bot.ZCBotAI.combat
	if (combat.aimNoiseNext or 0) <= CurTime() then
		combat.aimNoiseNext = CurTime() + BOT_AIM_NOISE_INTERVAL
		combat.aimNoisePitch = math_Rand(-spread, spread)
		combat.aimNoiseYaw = math_Rand(-spread, spread)
	end

	aimAng.p = aimAng.p + (combat.aimNoisePitch or 0)
	aimAng.y = aimAng.y + (combat.aimNoiseYaw or 0)
	return aimAng
end

function AimBotAt(bot, cmd, aimPos, spread, smooth)
	local aimOrigin = GetBotAimOrigin(bot)
	local toAim = aimPos - aimOrigin
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local currentAng = bot:EyeAngles()
	local aimAng = toAim:Angle()
	if toAim.x * toAim.x + toAim.y * toAim.y <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
		aimAng.y = currentAng.y
	end

	aimAng.p = aimAng.p + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng.y = aimAng.y + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng = ApplyBotAimSpread(bot, aimAng, spread or 0)
	aimAng = SetBotViewAngles(bot, cmd, aimAng, smooth or BOT_AIM_SMOOTH_COMBAT)

	return aimAng, toAim:Length()
end

function FaceRecentThreat(bot, cmd)
	local state = bot.ZCBotAI
	if not state then return false end
	if (state.threatUntil or 0) <= CurTime() or not isvector(state.threatPos) then return false end

	local toThreat = state.threatPos - bot:EyePos()
	if toThreat:LengthSqr() <= 1 then return false end

	SetBotViewAngles(bot, cmd, toThreat:Angle(), BOT_AIM_SMOOTH_COMBAT)
	return true
end

function FleeFromEnemy(bot, cmd, enemy, desiredDistance)
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

	local fleePos = bot:GetPos() + away * (desiredDistance or BOT_NAV_DEST_REACH)
	fleePos = AdjustBotGoal(bot, fleePos)

	local lookPos = IsValid(enemy) and enemy:EyePos() or enemyPos
	local aimAng = (lookPos - bot:EyePos()):Angle()

	MoveTo(bot, cmd, fleePos, {aimAng = aimAng, facePath = false, speed = 430, allowSprint = true})
	return true
end

local function EvadeTarget(bot, cmd, target, aimAng)
	if not IsValid(target) then return end

	local body = GetBotTargetBody(target)
	local away = bot:GetPos() - GetBotTargetBodyPos(target, body)
	away.z = 0
	if away:LengthSqr() <= 1 then
		away = bot:EyeAngles():Forward() * -1
	end

	away:Normalize()
	local right = Angle(0, aimAng.y, 0):Right()
	local combat = bot.ZCBotAI.combat
	local side = combat.reloadEvadeSide
	if not side or (combat.nextReloadEvadeSide or 0) < CurTime() then
		side = math_random(0, 1) == 1 and 1 or -1
		combat.reloadEvadeSide = side
		combat.nextReloadEvadeSide = CurTime() + math_Rand(0.8, 1.5)
	end

	local evadePos = bot:GetPos() + away * BOT_RELOAD_EVADE_DISTANCE + right * side * 260
	evadePos = AdjustBotGoal(bot, evadePos)
	SetBotMovementToward(bot, cmd, evadePos, aimAng, 360)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, evadePos)
end

-- While reloading near a visible enemy: prefer a nearby protected position,
-- fall back to lateral retreat.
local function ReloadEvadeOrCover(bot, cmd, target, aimAng)
	local state = GetOrCreateState(bot)
	local threatPos = isvector(state.lastSeenPos) and state.lastSeenPos
		or GetBotTargetBodyPos(target, GetBotTargetBody(target))

	local cover = FindProtectedPosition(bot, threatPos)
	if cover then
		MoveTo(bot, cmd, cover, {aimAng = aimAng, facePath = false, speed = 380})
		return
	end

	EvadeTarget(bot, cmd, target, aimAng)
end

local function TryReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime, enemyVisible)
	if safeTime or not IsRangedWeapon(wep) then return false end

	local now = GetBotCommandNow(bot)
	local combat = bot.ZCBotAI.combat
	local clip = wep:Clip1()
	local maxClip = wep:GetMaxClip1()
	local nextCycle = wep.GetNetVar and wep:GetNetVar("shootgunReload", 0) or 0
	local singleRound = IsSingleRoundReloadWeapon(wep)
	local needsCycle = wep.drawBullet == false and clip > 0 and nextCycle <= now
	local dry = needsCycle or clip <= 0 or wep.drawBullet == false
	local busy = not not wep.reload or nextCycle > now
	local reserve = GetBotWeaponReserveAmmo(bot, wep)
	local enemyNearby = rawDist <= BOT_COMBAT_RELOAD_ENEMY_RANGE
	-- A safe reload continues standing; evasion only happens near a visible enemy.
	local threatened = enemyNearby and enemyVisible == true
	local continuingSingleReload = combat.reloadWeapon == wep and singleRound and clip < (combat.reloadGoalClip or 0)

	if not needsCycle and not dry and not busy and not continuingSingleReload then
		combat.reloadWeapon = nil
		combat.reloadStartClip = nil
		combat.reloadGoalClip = nil
		combat.reloadPulseUntil = nil
		return false
	end

	if needsCycle then
		BotPressReload(bot, cmd, wep)
		if threatened then ReloadEvadeOrCover(bot, cmd, target, aimAng) end
		return true
	end

	if reserve <= 0 and not busy then
		if threatened then ReloadEvadeOrCover(bot, cmd, target, aimAng) end
		return true
	end

	if combat.reloadWeapon ~= wep then
		combat.reloadWeapon = wep
		combat.reloadStartClip = clip
		if singleRound and enemyNearby then
			combat.reloadGoalClip = math_min(maxClip, clip + BOT_COMBAT_RELOAD_SHELLS, clip + reserve)
		else
			combat.reloadGoalClip = maxClip
		end
	end

	local goalClip = combat.reloadGoalClip or maxClip
	if singleRound and clip >= goalClip and not dry and not busy then
		combat.reloadWeapon = nil
		combat.reloadStartClip = nil
		combat.reloadGoalClip = nil
		combat.reloadPulseUntil = nil
		return false
	end

	if (maxClip > 0 and clip < maxClip and reserve > 0) or busy then
		BotPressReload(bot, cmd, wep)
	end

	if threatened then ReloadEvadeOrCover(bot, cmd, target, aimAng) end
	return true
end

local function GetRagdollHeadAimPos(body)
	if not IsValid(body) then return end
	if body:IsPlayer() then return body:EyePos() end

	return GetEntityBonePos(body, "ValveBiped.Bip01_Head1") or body:WorldSpaceCenter()
end

local function TryMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, safeTime, fakeCombat)
	if not IsRagdolledTarget(target) or attackDist > attackRange then return false end

	local headPos = GetRagdollHeadAimPos(body)
	if not isvector(headPos) then return false end

	if fakeCombat then
		AimBotFakeAt(bot, cmd, headPos, 1)
	else
		AimBotAt(bot, cmd, headPos, 0, BOT_AIM_SMOOTH_COMBAT)
	end
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_DUCK))

	if not safeTime then
		BotPressMeleeAttack(bot, cmd, wep)
	end

	return true
end

-- Attack one current target. Shared by upright and fake-ragdoll combat.
-- ctx: { mode, safeTime, fakeCombat }
-- Friendly-fire obstruction: withhold the shot when a teammate is the first
-- player in the firing line. One trace per command tick, cached.
local ffTraceData = { mask = MASK_SHOT, filter = {} }

local function IsShotBlockedByTeammate(bot, aimPos)
	local state = GetOrCreateState(bot)
	local combat = state.combat
	local tick = engine.TickCount()
	if combat.ffCheckTick == tick then return combat.ffBlocked == true end

	combat.ffCheckTick = tick
	combat.ffBlocked = false

	ffTraceData.start = GetBotAimOrigin(bot)
	ffTraceData.endpos = aimPos
	ffTraceData.filter[1] = bot
	ffTraceData.filter[2] = GetBotFakeRagdollEntity(bot)

	local tr = util.TraceLine(ffTraceData)
	if tr.Hit and IsValid(tr.Entity) and tr.Entity:IsPlayer() and tr.Entity ~= bot and tr.Entity:Alive() then
		if IsBotTeammate(bot, tr.Entity) then
			combat.ffBlocked = true
		end
	end

	return combat.ffBlocked
end

-- Stable combat movement: pick a response for roughly one second instead of
-- reversing every command. Urgent conditions may interrupt it immediately.
local function AcquireMoveKind(bot, dist, profile)
	local combat = GetOrCreateState(bot).combat
	local now = CurTime()
	if combat.moveKind and (combat.moveUntil or 0) > now and combat.moveBand == profile then
		return combat.moveKind
	end

	local kind
	if dist < profile.min * 0.75 then
		kind = "back"
	elseif dist > profile.max then
		kind = "close"
	else
		kind = "hold"
	end

	combat.moveKind = kind
	combat.moveBand = profile
	combat.moveUntil = now + math_Rand(BOT_MOVE_COMMIT_MIN, BOT_MOVE_COMMIT_MAX)
	return kind
end

local function ApplyCombatMovement(bot, cmd, aimAng, kind, profile, dist, chasePos)
	local now = CurTime()
	local combat = bot.ZCBotAI.combat

	if kind == "back" then
		local away = bot:GetPos() - chasePos
		away.z = 0
		if away:LengthSqr() <= 1 then
			away = bot:EyeAngles():Forward() * -1
		end
		away:Normalize()

		local destPos = bot:GetPos() + away * 260
		destPos = AdjustBotGoal(bot, destPos)
		SetBotMovementToward(bot, cmd, destPos, aimAng, 300)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, destPos)
		return
	end

	if kind == "close" then
		local speed = dist > 900 and 340 or 420
		MoveTo(bot, cmd, chasePos, {aimAng = aimAng, facePath = false, speed = speed})
		return
	end

	-- Hold range with a committed strafe side for the movement interval.
	if not combat.strafeSide or (combat.nextStrafe or 0) < now then
		combat.strafeSide = math_random(0, 1) == 1 and 1 or -1
		combat.nextStrafe = now + math_Rand(0.9, 1.7)
	end

	cmd:SetForwardMove(dist > profile.ideal * 1.25 and 160 or 0)
	cmd:SetSideMove(combat.strafeSide * 220)
	AdjustBotStrafe(bot, cmd, aimAng)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, chasePos)
end

function AttackCurrentTarget(bot, cmd, ctx)
	local state = GetOrCreateState(bot)
	local target = IsValid(state.intentTarget) and state.intentTarget or state.target
	if not IsUsableTarget(bot, target, ctx.mode) then return false end
	-- The mode may revoke hostility mid-fight; stop immediately when it does.
	if CanBotTarget(bot, target) == false then return false end

	local body = GetBotTargetBody(target)
	local ignoreFOV = ctx.fakeCombat or (IsValid(state.threat) and state.threat == target and (state.threatUntil or 0) > GetBotCommandNow(bot))

	-- Revalidate with current line of sight right now; never fire from a stale view.
	local perception = state.perception
	perception.refreshing = true
	local aimPos, canSee
	if ignoreFOV then
		aimPos, canSee = GetVisibleTargetAimPosNoFOV(bot, body)
	else
		aimPos, canSee = GetVisibleTargetAimPos(bot, body)
	end
	perception.refreshing = false
	if not canSee then return false end

	local rawDist = aimPos:Distance(ctx.fakeCombat and GetBotSightOrigin(bot) or bot:EyePos())
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local category = GetWeaponFireCategory(wep)
	local profile = RANGE_PROFILES[category] or RANGE_PROFILES.pistol
	local meleeWeapon = IsMeleeWeapon(wep)
	local attackRange = meleeWeapon and GetMeleeWeaponAttackRange(wep) or BOT_ATTACK_RANGE
	local reactionReady = IsBotReactionReady(bot, target, canSee, rawDist)
	local baseAimSpread = GetBotAimSpread(bot, target, true)
	local tapTarget = IsUnconsciousTarget(target)
	local targetBodyPos = GetBotTargetBodyPos(target, body)
	local meleeOffset = targetBodyPos - bot:GetPos()
	meleeOffset.z = 0
	local attackDist = meleeWeapon and meleeOffset:Length() or rawDist

	-- Empty ranged weapons never produce repeated attack input.
	local hasAmmo = meleeWeapon or HasAmmoForWeapon(bot, wep)
	local shouldFire = not ctx.safeTime and hasAmmo and attackDist <= attackRange
		and (meleeWeapon or ((ctx.fakeCombat or reactionReady) and IsBotConfidentToFire(bot, target, rawDist, baseAimSpread)))

	-- Long-range firearms require a longer settled sight before committing.
	if shouldFire and not meleeWeapon and category == "rifle" and rawDist > 900 then
		shouldFire = GetBotSightTime(bot, target) >= BOT_LONG_RANGE_MIN_SIGHT_TIME * 1.5
	end

	-- Aim spread never collapses to perfect accuracy during a long engagement.
	local aimSpread = baseAimSpread + (tapTarget and 0 or GetBotBurstSpread(bot, target, shouldFire))
	aimSpread = math_max(aimSpread, 0.5 + (1 - GetBotAimSkill(bot)) * 0.45)

	local aimAng
	if ctx.fakeCombat then
		aimAng = AimBotFakeAt(bot, cmd, aimPos, 1)
	else
		aimAng = AimBotAt(bot, cmd, aimPos, aimSpread)
	end

	if ctx.fakeCombat then
		if TryReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, ctx.safeTime, canSee) then
			return true
		end

		if meleeWeapon and TryMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, ctx.safeTime, true) then
			return true
		end

		if shouldFire then
			-- Withhold the shot when a teammate blocks the firing line.
			if not meleeWeapon and IsShotBlockedByTeammate(bot, aimPos) then
				GetBotBurstSpread(bot, target, false)
			elseif tapTarget then
				BotTapAttack(bot, cmd, wep)
			elseif meleeWeapon then
				BotPressMeleeAttack(bot, cmd, wep)
			else
				BotPressAttack(bot, cmd, wep, rawDist)
			end
		end

		return true
	end

	local chasePos = targetBodyPos
	local flat = (meleeWeapon and chasePos or aimPos) - bot:GetPos()
	flat.z = 0
	local flatDist = flat:Length()

	-- An empty firearm with another usable one in the inventory switches instead
	-- of starting a doomed reload.
	if IsRangedWeapon(wep) and wep:Clip1() <= 0 and GetBotWeaponReserveAmmo(bot, wep) <= 0 then
		local alt = SelectBotWeapon(bot)
		if IsValid(alt) and alt ~= wep and IsRangedWeapon(alt) and HasAmmoForWeapon(bot, alt) then
			bot:SelectWeapon(alt:GetClass())
			InvalidateWeaponSelection(bot)
			return true
		end
	end

	if TryReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, ctx.safeTime, canSee) then
		return true
	end

	if meleeWeapon then
		if ExecuteWeaponPickup(bot, cmd, aimAng) then return true end
		if TryMeleeRagdollFinisher(bot, cmd, target, body, wep, attackDist, attackRange, ctx.safeTime) then return true end

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

		return true
	end

	-- Ranged: one committed movement response at a time, shaped by the weapon
	-- category's preferred range band.
	local kind = AcquireMoveKind(bot, flatDist, profile)
	if flatDist <= BOT_MELEE_ATTACK_RANGE * 1.4 then
		-- Urgent: an enemy this close overrides any committed response.
		cmd:SetForwardMove(-160)
		cmd:SetSideMove(0)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, aimPos)
	else
		ApplyCombatMovement(bot, cmd, aimAng, kind, profile, flatDist, chasePos)
	end

	if shouldFire then
		-- Withhold the shot when a teammate blocks the firing line; end the burst.
		if IsShotBlockedByTeammate(bot, aimPos) then
			GetBotBurstSpread(bot, target, false)
		elseif tapTarget then
			BotTapAttack(bot, cmd, wep)
		else
			BotPressAttack(bot, cmd, wep, rawDist)
		end
	end

	return true
end

-- Fake-ragdoll control -------------------------------------------------------

local function GetBotFakeAimButtons()
	local buttons = IN_ATTACK2
	alwaysRagdollAimConVar = alwaysRagdollAimConVar or GetConVar("zc_always_ragdoll_aim")
	if not (alwaysRagdollAimConVar and alwaysRagdollAimConVar:GetBool()) then
		buttons = bit_bor(buttons, IN_USE)
	end

	return buttons
end

local function PublishBotFakeControl(bot, cmd)
	if not IsValid(bot) then return end

	local viewAng = cmd:GetViewAngles()
	bot.ZCBotFakeEyeAngles = Angle(viewAng.p, viewAng.y, viewAng.r)
	bot.ZCBotFakeButtons = cmd:GetButtons()
	bot.ZCBotFakeControlUntil = CurTime() + 0.25
end

-- Plain assignment so this fills the forward-declared AimBotFakeAt used above.
function AimBotFakeAt(bot, cmd, aimPos, smooth)
	local sightOrigin = GetBotSightOrigin(bot)
	local sightOffset = aimPos - sightOrigin
	local origin = sightOffset:LengthSqr() > BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE * BOT_CLOSE_AIM_MUZZLE_SNAP_RANGE and GetBotAimOrigin(bot) or sightOrigin
	local toAim = aimPos - origin
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local currentAng = bot:EyeAngles()
	local aimAng = toAim:Angle()
	if toAim.x * toAim.x + toAim.y * toAim.y <= BOT_VERTICAL_AIM_YAW_DEADZONE * BOT_VERTICAL_AIM_YAW_DEADZONE then
		aimAng.y = currentAng.y
	end

	aimAng = SetBotViewAngles(bot, cmd, aimAng, smooth or 1)
	return aimAng, toAim:Length()
end

local function FakeSpinScan(bot, cmd)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)

	local now = CurTime()
	local combat = bot.ZCBotAI.combat
	local lastTime = combat.fakeScanLastTime or now
	local delta = math_Clamp(now - lastTime, 0, 0.1)
	combat.fakeScanLastTime = now

	if not combat.fakeScanYaw then
		combat.fakeScanYaw = bot:EyeAngles().y
	end

	if not combat.fakeScanSide or (combat.nextFakeScanReverse or 0) <= now then
		combat.fakeScanSide = (combat.fakeScanSide or (math_random(0, 1) == 1 and 1 or -1)) * -1
		combat.nextFakeScanReverse = now + math_Rand(BOT_FAKE_SCAN_REVERSE_INTERVAL_MIN, BOT_FAKE_SCAN_REVERSE_INTERVAL_MAX)
	end

	combat.fakeScanYaw = math.NormalizeAngle(combat.fakeScanYaw + BOT_FAKE_SCAN_TURN_RATE * combat.fakeScanSide * delta)
	local scanAng = Angle(0, combat.fakeScanYaw, 0)
	return SetBotViewAngles(bot, cmd, scanAng, 1)
end

local function FakeHoldAndScan(bot, cmd)
	FakeSpinScan(bot, cmd)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), GetBotFakeAimButtons()))
	ClearBotMovementInput(cmd)
end

function TryBotFakeUp(bot)
	if not zc.GetFakeState or not zc.FAKE_STATE then return false end

	local combat = GetOrCreateState(bot).combat
	if (combat.fakeUpCooldownUntil or 0) > CurTime() then return true end
	if (bot.LastFakeUp or 0) + BOT_FAKEUP_COOLDOWN > CurTime() then return true end

	local fakeState = zc.GetFakeState(bot)
	if fakeState == zc.FAKE_STATE.NONE then
		combat.fakeUpAllowedAt = nil
		return false
	end

	if fakeState == zc.FAKE_STATE.ACTIVE then
		if not combat.fakeUpAllowedAt then
			combat.fakeUpAllowedAt = CurTime() + BOT_FAKEUP_INITIAL_DELAY
		end

		if combat.fakeUpAllowedAt > CurTime() then
			return true
		end
	end

	if fakeState == zc.FAKE_STATE.ACTIVE and (combat.nextFakeUpTry or 0) <= CurTime() then
		combat.nextFakeUpTry = CurTime() + BOT_FAKEUP_INTERVAL
		if zc.FakeUp and zc.FakeUp(bot) then
			combat.fakeUpCooldownUntil = CurTime() + BOT_FAKEUP_COOLDOWN
			BotDevPrint("%s fakeup", bot:Name())
		end
	end

	return true
end

local function FaceFakeCombatTarget(bot, cmd, safeTime)
	local state = GetOrCreateState(bot)
	local target = state.target
	if not IsUsableTarget(bot, target, state.command.mode) then return false end

	local body = GetBotTargetBody(target)
	if not IsValid(body) then return false end

	local aimPos, canSee = GetVisibleTargetAimPosNoFOV(bot, body)
	if not canSee then
		aimPos = GetTargetAimPos(body, bot)
	end
	if not isvector(aimPos) then return false end

	local aimAng = AimBotFakeAt(bot, cmd, aimPos, 1)
	local rawDist = aimPos:Distance(GetBotSightOrigin(bot))
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	local attackRange = meleeWeapon and GetMeleeWeaponAttackRange(wep) or BOT_ATTACK_RANGE
	local tapTarget = IsUnconsciousTarget(target)
	local chasePos = GetBotTargetBodyPos(target, body)
	local meleeOffset = chasePos - bot:GetPos()
	meleeOffset.z = 0

	if TryReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
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

-- Runs while the bot is fake-ragdolled. Returns true when it owns the command.
function ExecuteFakeControl(bot, cmd, ctx)
	if not zc.GetFakeState or not zc.FAKE_STATE then return false end

	local fakeState = zc.GetFakeState(bot)
	if fakeState == zc.FAKE_STATE.NONE then return false end

	local state = GetOrCreateState(bot)

	if fakeState == zc.FAKE_STATE.ACTIVE then
		UpdateTarget(bot, state, ctx.mode, true, ctx.now)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), GetBotFakeAimButtons()))
		if not AttackCurrentTarget(bot, cmd, {mode = ctx.mode, safeTime = ctx.safeTime, fakeCombat = true})
			and not FaceFakeCombatTarget(bot, cmd, ctx.safeTime)
			and not FaceRecentThreat(bot, cmd) then
			FakeHoldAndScan(bot, cmd)
		end
		TryBotFakeUp(bot)
		ClearBotMovementInput(cmd)
		if ctx.safeTime then ClearCombatButtons(cmd) end
		PublishBotFakeControl(bot, cmd)
		return true
	end

	-- Getting-up transition: suspend other intents until the fake state resolves.
	return true
end
