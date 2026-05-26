local bit_bor = bit.bor
local bit_band = bit.band
local bit_bnot = bit.bnot
local CurTime = CurTime
local IsValid = IsValid
local math_abs = math.abs
local math_Rand = math.Rand
local math_random = math.random
local math_min = math.min
local math_huge = math.huge
local math_Clamp = math.Clamp
local math_Lerp = Lerp

local zc_playerbot_ai = CreateConVar("zc_playerbot_ai", "1", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Enable basic enemy AI for player bots created with the bot command.", 0, 1)
local zc_playerbot_debug = CreateConVar("zc_playerbot_debug", "0", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Print player bot AI target/debug messages through DevPrint.", 0, 1)

local BOT_THINK_INTERVAL = 0.2
local BOT_ATTACK_RANGE = 1800
local BOT_MELEE_RANGE = 95
local BOT_CLOSE_RANGE = 170
local BOT_STRAFE_RANGE = 700
local BOT_RAGDOLL_DEPRIORITIZE_RANGE = 1400
local BOT_AIM_JITTER = 0.018
local BOT_AIM_SPREAD_MIN = 1.2
local BOT_AIM_SPREAD_MAX = 7.5
local BOT_AIM_LOCK_TIME = 3.5
local BOT_AIM_NOISE_INTERVAL = 0.16
local BOT_AIM_LOCKED_SPREAD = 0.45
local BOT_AIM_BURST_SETTLE_TIME = 1.2
local BOT_AIM_OPENING_BURST_SPREAD = 5.5
local BOT_FAKEUP_INTERVAL = 0.45
local BOT_HEAL_INTERVAL = 0.35
local BOT_NAV_REPATH_INTERVAL = 0.7
local BOT_NAV_WAYPOINT_REACH = 85
local BOT_NAV_DEST_REACH = 180
local BOT_NAV_MAX_AREAS = 1200
local BOT_ROAM_INTERVAL = 4
local BOT_ROAM_AREA_SAMPLES = 48
local BOT_ROAM_MIN_DISTANCE = 1400
local BOT_SPRINT_DISTANCE = 1200
local BOT_SPRINT_STAMINA_FRACTION = 0.5
local BOT_STUCK_INTERVAL = 1.4
local BOT_STUCK_MIN_DISTANCE = 35
local BOT_UNSTUCK_TIME = 1.1
local BOT_UNSTUCK_RETRY_TIME = 0.5
local BOT_STEP_HEIGHT = 20
local BOT_ZONE_AVOID_MARGIN = 200
local BOT_ZONE_ROAM_MARGIN = 600
local BOT_ZONE_CENTER_TIME = 10
local BOT_ZONE_CENTER_REACH = 500

local MEDICINE_CLASSES = {
	weapon_bandage_sh = true,
	weapon_bigbandage_sh = true,
	weapon_tourniquet = true,
}

local BANDAGE_CLASSES = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
}

local traceData = {
	mask = MASK_SHOT,
	filter = {},
}

local hullTraceData = {
	mask = MASK_PLAYERSOLID,
	filter = {},
}

local BotCanSee

local function BotDevPrint(msg)
	if not zc_playerbot_debug:GetBool() then return end
	if zb and zb.dev and zb.dev.DevPrint then
		zb.dev.DevPrint("[ZC bot] " .. msg)
	end
end

local function GetBotTargetBody(ply)
	if not IsValid(ply) then return NULL end

	local rag = IsValid(ply.FakeRagdoll) and ply.FakeRagdoll or ply:GetNWEntity("FakeRagdoll")
	if IsValid(rag) then return rag end

	if hg.GetFakeState and hg.FAKE_STATE and hg.GetFakeState(ply) == hg.FAKE_STATE.RESTORING then
		local oldrag = IsValid(ply.FakeRagdollOld) and ply.FakeRagdollOld or ply:GetNWEntity("FakeRagdollOld")
		if IsValid(oldrag) then return oldrag end
	end

	return ply
end

local function GetEntityBonePos(ent, boneName)
	if not IsValid(ent) or not ent.LookupBone then return end

	local bone = ent:LookupBone(boneName)
	local matrix = bone and ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end
end

local function GetTargetAimPos(ent, bot)
	if not IsValid(ent) then return vector_origin end

	if ent:IsPlayer() then
		local torsoPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or ent:WorldSpaceCenter()
		if not IsValid(bot) or BotCanSee(bot, ent, torsoPos) then return torsoPos end

		return ent:EyePos()
	end

	local bonePos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Head1") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	if bonePos then return bonePos end

	return ent:WorldSpaceCenter()
end

BotCanSee = function(bot, body, aimPos)
	traceData.start = bot:EyePos()
	traceData.endpos = aimPos
	traceData.filter[1] = bot
	traceData.filter[2] = bot.FakeRagdoll

	local tr = util.TraceLine(traceData)
	return (not tr.Hit) or tr.Entity == body or (IsValid(body) and tr.Entity == body:GetNWEntity("ply"))
end

local function IsUsableTarget(bot, ply)
	if ply == bot or not IsValid(ply) or not ply:Alive() then return false end
	if ply:Team() == TEAM_SPECTATOR then return false end

	return IsValid(GetBotTargetBody(ply))
end

local function IsRagdolledTarget(ply)
	if not IsValid(ply) then return false end
	if IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdoll")) then return true end

	return hg.GetFakeState and hg.FAKE_STATE and hg.GetFakeState(ply) ~= hg.FAKE_STATE.NONE
end

local function HasNearbyUprightEnemy(bot, ignoreTarget)
	local botPos = bot:GetPos()
	local rangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	for _, ply in ipairs(player.GetAll()) do
		if ply == ignoreTarget or not IsUsableTarget(bot, ply) or IsRagdolledTarget(ply) then continue end
		if botPos:DistToSqr(ply:GetPos()) <= rangeSqr then return true end
	end

	return false
end

local function PickBotTarget(bot)
	local bestPly
	local bestScore = math.huge

	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local aimPos = GetTargetAimPos(body, bot)
		local distSqr = bot:GetPos():DistToSqr(aimPos)
		local visible = BotCanSee(bot, body, aimPos)
		local score = visible and distSqr or distSqr * 4
		if IsRagdolledTarget(ply) and HasNearbyUprightEnemy(bot, ply) then
			score = score * 10
		end

		if score < bestScore then
			bestScore = score
			bestPly = ply
		end
	end

	return bestPly
end

local function HasVisibleEnemy(bot)
	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local aimPos = GetTargetAimPos(body, bot)
		if BotCanSee(bot, body, aimPos) then return true end
	end

	return false
end

local function GetNearestBotNavArea(pos)
	if not navmesh or not navmesh.GetNearestNavArea then return nil end

	local area = navmesh.GetNearestNavArea(pos, false, 1200, false, false)
	if IsValid(area) then return area end

	area = navmesh.GetNearestNavArea(pos, true, 1200, false, false)
	if IsValid(area) then return area end
end

local function PickRandomRoamArea(bot)
	if not navmesh or not navmesh.GetAllNavAreas then return nil end
	if (bot.ZCBotNextRoamPick or 0) > CurTime() and IsValid(bot.ZCBotRoamArea) then return bot.ZCBotRoamArea end

	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then return nil end

	local currentArea = GetNearestBotNavArea(bot:GetPos())
	local bestArea
	local bestScore = -math_huge
	local tries = math_min(#areas, BOT_ROAM_AREA_SAMPLES)

	for _ = 1, tries do
		local area = areas[math_random(1, #areas)]
		if not IsValid(area) then continue end

		local dist = IsValid(currentArea) and currentArea:GetCenter():DistToSqr(area:GetCenter()) or 0
		if dist < BOT_ROAM_MIN_DISTANCE * BOT_ROAM_MIN_DISTANCE then continue end

		local score = math_min(dist, 25000000) + math_Rand(0, 500000)
		if score > bestScore then
			bestScore = score
			bestArea = area
		end
	end

	if not IsValid(bestArea) then
		bestArea = areas[math_random(1, #areas)]
	end

	bot.ZCBotRoamArea = bestArea
	bot.ZCBotNextRoamPick = CurTime() + BOT_ROAM_INTERVAL + math_Rand(0, 2)
	if IsValid(bestArea) then
		BotDevPrint(string.format("%s roam", bot:Name()))
	end

	return bestArea
end

local function ReconstructAreaPath(cameFrom, current)
	local path = {current}

	while cameFrom[current] do
		current = cameFrom[current]
		table.insert(path, 1, current)
	end

	return path
end

local function BuildAreaPath(startArea, goalArea)
	if not IsValid(startArea) or not IsValid(goalArea) then return end
	if startArea == goalArea then return {startArea} end

	local open = {startArea}
	local openSet = {[startArea] = true}
	local cameFrom = {}
	local gScore = {[startArea] = 0}
	local fScore = {[startArea] = startArea:GetCenter():Distance(goalArea:GetCenter())}
	local goalPos = goalArea:GetCenter()
	local searched = 0

	while #open > 0 and searched < BOT_NAV_MAX_AREAS do
		searched = searched + 1

		local bestIndex = 1
		local current = open[1]
		local bestScore = fScore[current] or math_huge
		for i = 2, #open do
			local area = open[i]
			local score = fScore[area] or math_huge
			if score < bestScore then
				bestIndex = i
				current = area
				bestScore = score
			end
		end

		table.remove(open, bestIndex)
		openSet[current] = nil

		if current == goalArea then
			return ReconstructAreaPath(cameFrom, current)
		end

		for _, neighbor in ipairs(current:GetAdjacentAreas()) do
			if not IsValid(neighbor) then continue end

			local stepCost = current:GetCenter():Distance(neighbor:GetCenter())
			local heightCost = math_abs(current:ComputeAdjacentConnectionHeightChange(neighbor) or 0) * 4
			local tentative = (gScore[current] or math_huge) + stepCost + heightCost

			if tentative < (gScore[neighbor] or math_huge) then
				cameFrom[neighbor] = current
				gScore[neighbor] = tentative
				fScore[neighbor] = tentative + neighbor:GetCenter():Distance(goalPos)

				if not openSet[neighbor] then
					table.insert(open, neighbor)
					openSet[neighbor] = true
				end
			end
		end
	end
end

local function GetAreaWaypoint(area)
	if not IsValid(area) then return vector_origin end
	return area:GetCenter()
end

local function SetBotMovementToward(bot, cmd, movePos, aimAng, speed)
	local toMove = movePos - bot:GetPos()
	toMove.z = 0
	if toMove:LengthSqr() <= 1 then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return
	end

	toMove:Normalize()

	local moveAng = Angle(0, aimAng.y, 0)
	local forward = moveAng:Forward()
	local right = moveAng:Right()
	local forwardMove = toMove:Dot(forward) * speed
	local sideMove = toMove:Dot(right) * speed

	cmd:SetForwardMove(forwardMove)
	cmd:SetSideMove(sideMove)
end

local function GetBotStaminaFraction(bot)
	local org = bot.organism
	local stamina = org and org.stamina
	if not stamina then return 1 end

	local maxStamina = stamina.max or stamina.range or 180
	if maxStamina <= 0 then return 0 end

	return math_Clamp((stamina[1] or maxStamina) / maxStamina, 0, 1)
end

local function TryBotTravelSprint(bot, cmd, destPos)
	if bot:Crouching() then return end
	if cmd:GetForwardMove() <= 120 then return end
	if bot:GetPos():DistToSqr(destPos) < BOT_SPRINT_DISTANCE * BOT_SPRINT_DISTANCE then return end
	if GetBotStaminaFraction(bot) <= BOT_SPRINT_STAMINA_FRACTION then return end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_SPEED))
end

local function HasClearMoveLine(bot, pos)
	local mins, maxs = bot:GetHull()
	hullTraceData.start = bot:GetPos() + Vector(0, 0, 8)
	hullTraceData.endpos = pos + Vector(0, 0, 8)
	hullTraceData.mins = mins
	hullTraceData.maxs = maxs
	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	return not util.TraceHull(hullTraceData).Hit
end

local function ApplyBotUnstuckMove(bot, cmd)
	if (bot.ZCBotUnstuckUntil or 0) <= CurTime() then return false end

	cmd:SetForwardMove(bot.ZCBotUnstuckForward or -180)
	cmd:SetSideMove((bot.ZCBotUnstuckSide or 1) * 260)

	if (bot.ZCBotNextJump or 0) < CurTime() then
		bot.ZCBotNextJump = CurTime() + 0.65
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_JUMP))
	end

	if bot.ZCBotUnstuckDuck then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_DUCK))
	end

	return true
end

local function UpdateBotStuckState(bot, cmd, movePos)
	if (bot.ZCBotNextStuckCheck or 0) > CurTime() then return end

	local pos = bot:GetPos()
	local oldPos = bot.ZCBotLastStuckPos
	bot.ZCBotLastStuckPos = pos
	bot.ZCBotNextStuckCheck = CurTime() + BOT_STUCK_INTERVAL

	if not oldPos then return end

	local moved = oldPos:Distance(pos)
	if moved >= BOT_STUCK_MIN_DISTANCE then return end

	bot.ZCBotPath = nil
	bot.ZCBotPathIndex = nil
	bot.ZCBotNextPathTime = 0
	bot.ZCBotRoamArea = nil
	bot.ZCBotNextRoamPick = 0
	bot.ZCBotUnstuckUntil = CurTime() + BOT_UNSTUCK_TIME
	bot.ZCBotNextStuckCheck = CurTime() + BOT_UNSTUCK_RETRY_TIME
	bot.ZCBotUnstuckSide = math_random(0, 1) == 1 and 1 or -1
	bot.ZCBotUnstuckForward = math_random(0, 1) == 1 and -220 or 120
	bot.ZCBotUnstuckDuck = math_random(0, 2) == 0

	ApplyBotUnstuckMove(bot, cmd)

	if movePos.z - pos.z > BOT_STEP_HEIGHT and (bot.ZCBotNextJump or 0) < CurTime() then
		bot.ZCBotNextJump = CurTime() + 1
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_JUMP))
	end
end

local function FollowBotPath(bot, cmd, destPos, aimAng, runSpeed, faceWaypoint, allowSprint)
	local startArea = GetNearestBotNavArea(bot:GetPos())
	local goalArea = GetNearestBotNavArea(destPos)
	if not IsValid(startArea) or not IsValid(goalArea) then return false end

	local needsPath = not bot.ZCBotPath or bot.ZCBotPathGoal ~= goalArea or (bot.ZCBotNextPathTime or 0) <= CurTime()
	if needsPath then
		bot.ZCBotPath = BuildAreaPath(startArea, goalArea)
		bot.ZCBotPathIndex = bot.ZCBotPath and #bot.ZCBotPath > 1 and 2 or 1
		bot.ZCBotPathGoal = goalArea
		bot.ZCBotNextPathTime = CurTime() + BOT_NAV_REPATH_INTERVAL
	end

	local path = bot.ZCBotPath
	if not path or #path == 0 then return false end

	local index = bot.ZCBotPathIndex or 1
	while index < #path and bot:GetPos():DistToSqr(GetAreaWaypoint(path[index])) <= BOT_NAV_WAYPOINT_REACH * BOT_NAV_WAYPOINT_REACH do
		index = index + 1
	end

	bot.ZCBotPathIndex = index

	local waypoint = index >= #path and destPos or GetAreaWaypoint(path[index])
	if bot:GetPos():DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return true, true
	end

	if not HasClearMoveLine(bot, waypoint) and index < #path then
		index = index + 1
		bot.ZCBotPathIndex = index
		waypoint = index >= #path and destPos or GetAreaWaypoint(path[index])
	end

	if faceWaypoint then
		aimAng = (waypoint - bot:EyePos()):Angle()
		cmd:SetViewAngles(aimAng)
		bot:SetEyeAngles(aimAng)
	end

	SetBotMovementToward(bot, cmd, waypoint, aimAng, runSpeed)
	if allowSprint then
		TryBotTravelSprint(bot, cmd, destPos)
	end

	ApplyBotUnstuckMove(bot, cmd)
	UpdateBotStuckState(bot, cmd, waypoint)
	return true
end

local function GetStoredWeaponBase(class)
	local stored = weapons.GetStored and weapons.GetStored(class) or weapons.Get(class)
	return stored and stored.Base
end

local function WeaponInheritsBase(wep, baseName)
	if not IsValid(wep) then return false end
	if wep.Base == baseName then return true end
	if wep.ishgwep or wep.ishgweapon then return baseName == "homigrad_base" end

	local seen = {}
	local base = GetStoredWeaponBase(wep:GetClass()) or wep.Base
	while isstring(base) and base ~= "" and not seen[base] do
		if base == baseName then return true end

		seen[base] = true
		base = GetStoredWeaponBase(base)
	end

	return false
end

local function IsMedicineWeapon(wep)
	return IsValid(wep) and MEDICINE_CLASSES[wep:GetClass()]
end

local function HasAmmoForWeapon(bot, wep)
	if not IsValid(wep) then return false end
	if wep:Clip1() > 0 then return true end

	local primary = wep.Primary
	local ammoName = primary and primary.Ammo
	if ammoName and ammoName ~= "none" and bot:GetAmmoCount(ammoName) > 0 then return true end

	local ammoType = wep:GetPrimaryAmmoType()
	return ammoType and ammoType >= 0 and bot:GetAmmoCount(ammoType) > 0
end

local function HasReserveAmmoForWeapon(bot, wep)
	if not IsValid(wep) then return false end

	local primary = wep.Primary
	local ammoName = primary and primary.Ammo
	if ammoName and ammoName ~= "none" and bot:GetAmmoCount(ammoName) > 0 then return true end

	local ammoType = wep:GetPrimaryAmmoType()
	return ammoType and ammoType >= 0 and bot:GetAmmoCount(ammoType) > 0
end

local function ShouldReloadWeapon(bot, wep)
	if not IsValid(wep) or wep:Clip1() ~= 0 then return false end
	if wep:GetMaxClip1() == 0 then return false end

	return HasReserveAmmoForWeapon(bot, wep)
end

local function IsRangedWeapon(wep)
	if not IsValid(wep) or IsMedicineWeapon(wep) then return false end

	local primary = wep.Primary
	if not primary or primary.Ammo == "none" then return false end

	return WeaponInheritsBase(wep, "homigrad_base")
end

local function SelectBotWeapon(bot)
	local active = bot:GetActiveWeapon()
	if IsRangedWeapon(active) and HasAmmoForWeapon(bot, active) then return active end

	local fallback
	for _, wep in ipairs(bot:GetWeapons()) do
		if not IsValid(wep) or wep:GetClass() == "weapon_hands_sh" or IsMedicineWeapon(wep) then continue end

		if IsRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			bot:SelectWeapon(wep:GetClass())
			return wep
		end

		fallback = fallback or wep
	end

	for _, wep in ipairs(bot:GetWeapons()) do
		if not IsValid(wep) or wep:GetClass() == "weapon_hands_sh" or IsMedicineWeapon(wep) then continue end
		fallback = fallback or wep
	end

	if IsValid(fallback) then
		bot:SelectWeapon(fallback:GetClass())
		return fallback
	end

	return active
end

local function IsMeleeWeapon(wep)
	if not IsValid(wep) then return true end
	if IsRangedWeapon(wep) then return false end

	local class = wep:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_melee" or class:find("hands", 1, true) or class:find("melee", 1, true)
end

local function HasUsableMedicine(wep, bot, needsTourniquet)
	if not IsValid(wep) then return false end

	local values = wep.modeValues
	if istable(values) and (values[1] or 0) <= 0 then return false end
	if needsTourniquet then return wep:GetClass() == "weapon_tourniquet" and bot.organism and istable(bot.organism.arterialwounds) and #bot.organism.arterialwounds > 0 end
	if wep.CanHeal then return wep:CanHeal(bot) ~= false end

	return true
end

local function HasAmputatedLimb(org)
	return org and (org.llegamputated or org.rlegamputated or org.larmamputated or org.rarmamputated)
end

local function GetBotWoundState(bot)
	local org = bot.organism
	if not org then return false, false end

	local arterialWounds = org.arterialwounds
	local wounds = org.wounds
	local hasArterialWound = istable(arterialWounds) and #arterialWounds > 0
	local hasBleed = (org.bleed or 0) > 0.05 and istable(wounds) and #wounds > 0

	return HasAmputatedLimb(org) and hasArterialWound, hasBleed
end

local function FindBotMedicine(bot, classList, needsTourniquet)
	local active = bot:GetActiveWeapon()
	if IsValid(active) and table.HasValue(classList, active:GetClass()) and HasUsableMedicine(active, bot, needsTourniquet) then
		return active
	end

	for _, class in ipairs(classList) do
		local wep = bot:GetWeapon(class)
		if HasUsableMedicine(wep, bot, needsTourniquet) then return wep end
	end
end

local function TryBotSelfCare(bot, cmd)
	local needsTourniquet, needsBandage = GetBotWoundState(bot)
	if not needsTourniquet and not needsBandage then
		bot.ZCBotNextHealTry = 0
		return false
	end

	local active = bot:GetActiveWeapon()
	if HasUsableMedicine(active, bot, needsTourniquet) and (needsTourniquet or table.HasValue(BANDAGE_CLASSES, active:GetClass())) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	if (bot.ZCBotNextHealTry or 0) > CurTime() then return false end

	local wep
	if needsTourniquet then
		wep = FindBotMedicine(bot, {"weapon_tourniquet"}, true)
	end

	if not IsValid(wep) and needsBandage then
		wep = FindBotMedicine(bot, BANDAGE_CLASSES, false)
	end

	bot.ZCBotNextHealTry = CurTime() + BOT_HEAL_INTERVAL
	if not IsValid(wep) then return false end

	bot:SelectWeapon(wep:GetClass())
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))

	BotDevPrint(string.format("%s self-care=%s", bot:Name(), wep:GetClass()))
	return true
end

local function TryBotFakeUp(bot)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then return false end

	if fakeState == hg.FAKE_STATE.ACTIVE and (bot.ZCBotNextFakeUpTry or 0) <= CurTime() then
		bot.ZCBotNextFakeUpTry = CurTime() + BOT_FAKEUP_INTERVAL
		if hg.FakeUp and hg.FakeUp(bot) then
			BotDevPrint(string.format("%s fakeup", bot:Name()))
		end
	end

	return true
end

local function GetCurrentRound()
	return CurrentRound and CurrentRound() or nil
end

local function IsDeathmatchRoundActive(round)
	round = round or GetCurrentRound()
	return round and round.name == "dm" and zb and zb.ROUND_STATE == 1
end

local function IsDeathmatchSafeTime(round)
	if not IsDeathmatchRoundActive(round) then return false end
	if round.IsSpawnProtectionActive then return round:IsSpawnProtectionActive() end

	return (zb.ROUND_START or 0) + (round.SpawnProtectionTime or 7.5) > CurTime()
end

local function IsDeathmatchZoneDisabled()
	local convar = GetConVar("zc_deathmatch_nozone")
	return convar and convar:GetBool()
end

local function GetDeathmatchZoneInfo(round)
	if not IsDeathmatchRoundActive(round) or IsDeathmatchZoneDisabled() then return end
	if not isvector(zonepoint) then return end
	if not round.GetZoneRadius then return end

	local radius = round.GetZoneRadius()
	if not isnumber(radius) or radius <= 0 or radius >= 1000000 then return end

	return zonepoint, radius
end

local function IsPosInsideDeathmatchZone(pos, round, margin)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return true end

	return center:DistToSqr(pos) < math.max(radius - (margin or 0), 0) ^ 2
end

local function GetDeathmatchZoneEscapePos(bot, round)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return end

	local pos = bot:GetPos()
	local offset = pos - center
	local dist = offset:Length()
	if dist < radius - BOT_ZONE_AVOID_MARGIN then return end

	if dist <= 1 then return center end

	offset:Normalize()
	local safeRadius = math.max(radius - BOT_ZONE_AVOID_MARGIN * 1.75, radius * 0.45, 0)
	return center + offset * safeRadius
end

local function AvoidDeathmatchZone(bot, cmd, round)
	local escapePos = GetDeathmatchZoneEscapePos(bot, round)
	if not escapePos then return false end

	local aimAng = (escapePos - bot:EyePos()):Angle()
	cmd:SetViewAngles(aimAng)
	bot:SetEyeAngles(aimAng)

	local followedPath = FollowBotPath(bot, cmd, escapePos, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, escapePos, aimAng, 360)
		TryBotTravelSprint(bot, cmd, escapePos)
		ApplyBotUnstuckMove(bot, cmd)
		UpdateBotStuckState(bot, cmd, escapePos)
	end

	if (bot.ZCBotNextZoneDebug or 0) <= CurTime() then
		bot.ZCBotNextZoneDebug = CurTime() + 2
		BotDevPrint(string.format("%s avoid-dm-zone", bot:Name()))
	end

	return true
end

local function MoveToDeathmatchZoneCenter(bot, cmd, round)
	if not IsDeathmatchRoundActive(round) then return false end
	if CurTime() > (zb.ROUND_START or 0) + BOT_ZONE_CENTER_TIME then return false end

	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	if bot:GetPos():DistToSqr(center) <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return false end

	local aimAng = (center - bot:EyePos()):Angle()
	cmd:SetViewAngles(aimAng)
	bot:SetEyeAngles(aimAng)

	local followedPath = FollowBotPath(bot, cmd, center, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, center, aimAng, 360)
		TryBotTravelSprint(bot, cmd, center)
		ApplyBotUnstuckMove(bot, cmd)
		UpdateBotStuckState(bot, cmd, center)
	end

	return true
end

local function ClearCombatButtons(cmd)
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(bit_bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD))))
end

local function UpdateBotTarget(bot)
	if (bot.ZCBotNextTargetScan or 0) > CurTime() and IsUsableTarget(bot, bot.ZCBotTarget) then return end

	local oldTarget = bot.ZCBotTarget
	bot.ZCBotTarget = PickBotTarget(bot)
	bot.ZCBotNextTargetScan = CurTime() + BOT_THINK_INTERVAL

	if bot.ZCBotTarget ~= oldTarget then
		bot.ZCBotSeenTarget = nil
		bot.ZCBotSeenTargetStart = nil
		bot.ZCBotAimNoiseNext = 0
	end

	if bot.ZCBotTarget ~= oldTarget and IsValid(bot.ZCBotTarget) then
		BotDevPrint(string.format("%s target=%s", bot:Name(), bot.ZCBotTarget:Name()))
	end
end

local function GetBotAimSkill(bot)
	if not bot.ZCBotAimSkill then
		bot.ZCBotAimSkill = math_Rand(0.25, 0.85)
	end

	return bot.ZCBotAimSkill
end

local function UpdateBotTargetSight(bot, target, canSee)
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

local function GetBotAimSpread(bot, target, canSee)
	local aimSkill = GetBotAimSkill(bot)
	local sightProgress = UpdateBotTargetSight(bot, target, canSee)
	local curvedProgress = sightProgress * sightProgress
	local baseSpread = math_Lerp(aimSkill, BOT_AIM_SPREAD_MAX, BOT_AIM_SPREAD_MIN)

	if not canSee then return baseSpread * 1.25 end

	return math_Lerp(curvedProgress, baseSpread, BOT_AIM_LOCKED_SPREAD)
end

local function GetBotBurstSpread(bot, target, shouldFire)
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

local function ApplyBotAimSpread(bot, aimAng, spread)
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

local function AimBotAt(bot, cmd, aimPos, spread)
	local eyePos = bot:EyePos()
	local toAim = aimPos - eyePos
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local aimAng = toAim:Angle()
	aimAng.p = aimAng.p + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng.y = aimAng.y + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng = ApplyBotAimSpread(bot, aimAng, spread or 0)
	cmd:SetViewAngles(aimAng)
	bot:SetEyeAngles(aimAng)

	return aimAng, toAim:Length()
end

local function RoamBot(bot, cmd)
	local round = GetCurrentRound()
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
	cmd:SetViewAngles(aimAng)
	bot:SetEyeAngles(aimAng)

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
		UpdateBotStuckState(bot, cmd, destPos)
	end
end

local function TryBotAttackCurrentTarget(bot, cmd, safeTime)
	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then return false end

	local body = GetBotTargetBody(target)
	local aimPos = GetTargetAimPos(body, bot)
	local canSee = BotCanSee(bot, body, aimPos)
	if not canSee then return false end

	local rawDist = aimPos:Distance(bot:EyePos())
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local attackRange = IsMeleeWeapon(wep) and BOT_MELEE_RANGE or BOT_ATTACK_RANGE
	local shouldFire = not safeTime and rawDist <= attackRange
	local aimSpread = GetBotAimSpread(bot, target, true) + GetBotBurstSpread(bot, target, shouldFire)
	AimBotAt(bot, cmd, aimPos, aimSpread)

	if not safeTime and IsRangedWeapon(wep) and ShouldReloadWeapon(bot, wep) then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
		return true
	end

	if shouldFire then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	end

	return true
end

local function HandleBotFakeState(bot, cmd, safeTime)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then return false end

	if fakeState == hg.FAKE_STATE.ACTIVE then
		UpdateBotTarget(bot)
		TryBotAttackCurrentTarget(bot, cmd, safeTime)
		TryBotFakeUp(bot)
		if safeTime then ClearCombatButtons(cmd) end
		return true
	end

	return true
end

hook.Add("StartCommand", "ZC_PlayerBotEnemyAI", function(bot, cmd)
	if not zc_playerbot_ai:GetBool() or not bot:IsBot() then return end

	if not bot:Alive() then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return
	end

	local round = GetCurrentRound()
	local safeTime = IsDeathmatchSafeTime(round)
	if safeTime then ClearCombatButtons(cmd) end

	if HandleBotFakeState(bot, cmd, safeTime) then return end
	if not HasVisibleEnemy(bot) and TryBotSelfCare(bot, cmd) then return end

	UpdateBotTarget(bot)

	if AvoidDeathmatchZone(bot, cmd, round) then
		TryBotAttackCurrentTarget(bot, cmd, safeTime)
		if safeTime then ClearCombatButtons(cmd) end
		return
	end
	if MoveToDeathmatchZoneCenter(bot, cmd, round) then
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then
		RoamBot(bot, cmd)
		return
	end

	local body = GetBotTargetBody(target)
	local aimPos = GetTargetAimPos(body, bot)
	local canSee = BotCanSee(bot, body, aimPos)
	local rawDist = aimPos:Distance(bot:EyePos())
	if rawDist <= 1 then return end

	local wep = SelectBotWeapon(bot)
	local attackRange = IsMeleeWeapon(wep) and BOT_MELEE_RANGE or BOT_ATTACK_RANGE
	local shouldFire = not safeTime and canSee and rawDist <= attackRange
	local aimSpread = GetBotAimSpread(bot, target, canSee) + GetBotBurstSpread(bot, target, shouldFire)
	local aimAng, dist = AimBotAt(bot, cmd, aimPos, aimSpread)
	if dist <= 1 then return end

	local flat = aimPos - bot:GetPos()
	flat.z = 0
	local flatDist = flat:Length()
	if flatDist > 1 then flat:Normalize() end

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
	elseif flatDist > BOT_CLOSE_RANGE then
		local followedPath = FollowBotPath(bot, cmd, aimPos, aimAng, 400, not canSee, not canSee)
		if not followedPath then
			SetBotMovementToward(bot, cmd, aimPos, aimAng, 320)
			if not canSee then
				TryBotTravelSprint(bot, cmd, aimPos)
			end

			ApplyBotUnstuckMove(bot, cmd)
			UpdateBotStuckState(bot, cmd, aimPos)
		end
	else
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
	end

	if not safeTime and IsRangedWeapon(wep) and ShouldReloadWeapon(bot, wep) then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
		return
	end

	if shouldFire then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	end
end)
