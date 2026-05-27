local bit_bor = bit.bor
local bit_band = bit.band
local bit_bnot = bit.bnot
local CurTime = CurTime
local IsValid = IsValid
local math_abs = math.abs
local math_Rand = math.Rand
local math_random = math.random
local math_min = math.min
local math_cos = math.cos
local math_rad = math.rad
local math_huge = math.huge
local math_Clamp = math.Clamp
local math_Lerp = Lerp

local zc_playerbot_ai = CreateConVar("zc_playerbot_ai", "1", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Enable basic enemy AI for player bots created with the bot command.", 0, 1)
local zc_playerbot_debug = CreateConVar("zc_playerbot_debug", "0", FCVAR_ARCHIVE + FCVAR_SERVER_CAN_EXECUTE, "Print player bot AI target/debug messages through DevPrint.", 0, 1)

local BOT_THINK_INTERVAL = 0.2
local BOT_DEBUG_UPDATE_INTERVAL = 0.15
local BOT_ATTACK_RANGE = 1800
local BOT_MELEE_RANGE = 95
local BOT_MELEE_ATTACK_RANGE = 130
local BOT_CLOSE_RANGE = 170
local BOT_STRAFE_RANGE = 700
local BOT_RAGDOLL_DEPRIORITIZE_RANGE = 1400
local BOT_RAGDOLL_HEAD_AIM_RANGE = 450
local BOT_AIM_JITTER = 0.018
local BOT_AIM_SPREAD_MIN = 1.2
local BOT_AIM_SPREAD_MAX = 7.5
local BOT_AIM_LOCK_TIME = 3.5
local BOT_AIM_NOISE_INTERVAL = 0.16
local BOT_AIM_LOCKED_SPREAD = 0.45
local BOT_AIM_BURST_SETTLE_TIME = 1.2
local BOT_AIM_OPENING_BURST_SPREAD = 5.5
local BOT_AIM_SMOOTH_COMBAT = 0.24
local BOT_AIM_SMOOTH_TRAVEL = 0.16
local BOT_CQB_MAGDUMP_RANGE = 650
local BOT_LONG_RANGE_CONFIDENCE_RANGE = 1100
local BOT_LONG_RANGE_MAX_SPREAD = 3.4
local BOT_LONG_RANGE_MIN_SIGHT_TIME = 0.55
local BOT_AUTO_BURST_TIME = 0.35
local BOT_AUTO_BURST_PAUSE = 0.45
local BOT_FOV_DEGREES = 180
local BOT_FOV_DOT = math_cos(math_rad(BOT_FOV_DEGREES * 0.5))
local BOT_REACTION_MIN = 0.18
local BOT_REACTION_MAX = 0.85
local BOT_REACTION_DISTANCE = 2400
local BOT_ATTACK_PULSE_RELEASE = 0.11
local BOT_UNCONSCIOUS_TAP_INTERVAL = 0.65
local BOT_COMBAT_RELOAD_SHELLS = 2
local BOT_COMBAT_RELOAD_ENEMY_RANGE = 950
local BOT_RELOAD_EVADE_DISTANCE = 700
local BOT_COVER_SCORE_PENALTY = 3.5
local BOT_VISIBLE_SCORE_MULT = 0.35
local BOT_FAKEUP_INITIAL_DELAY = 5
local BOT_FAKEUP_INTERVAL = 5
local BOT_FAKEUP_COOLDOWN = 5
local BOT_HEAL_INTERVAL = 0.35
local BOT_THREAT_MEMORY_TIME = 4
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
local BOT_STUCK_JUMP_ATTEMPTS = 3
local BOT_UNSTUCK_TIME = 1.1
local BOT_UNSTUCK_RETRY_TIME = 0.5
local BOT_OBSTACLE_TRACE_DISTANCE = 92
local BOT_DOOR_TRACE_DISTANCE = 130
local BOT_DOOR_USE_COOLDOWN = 0.75
local BOT_ZONE_ROAM_MARGIN = 600
local BOT_ZONE_CENTER_TIME = 10
local BOT_ZONE_CENTER_REACH = 500
local BOT_ZONE_CENTER_BIAS_STEP = 32
local BOT_ZONE_CENTER_PATROL_RADIUS = 950
local BOT_ZONE_CENTER_PATROL_INTERVAL = 3
local BOT_SAFE_ENEMY_AVOID_RANGE = 1800
local BOT_SAFE_ENEMY_AVOID_DEST = 1200

local MEDICINE_CLASSES = {
	weapon_bandage_sh = true,
	weapon_bigbandage_sh = true,
	weapon_tourniquet = true,
}

local BANDAGE_CLASSES = {
	"weapon_bandage_sh",
	"weapon_bigbandage_sh",
}

local SECONDARY_WEAPON_CLASSES = {
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

local traceData = {
	mask = MASK_SHOT,
	filter = {},
}

local hullTraceData = {
	mask = MASK_PLAYERSOLID,
	filter = {},
}

local doorTraceData = {
	mask = MASK_SOLID,
	filter = {},
}

local BotCanSee

local function BotDevPrint(msg)
	if not zc_playerbot_debug:GetBool() then return end
	if zb and zb.dev and zb.dev.DevPrint then
		zb.dev.DevPrint("[ZC bot] " .. msg)
	end
end

local function SetBotDebugState(bot, state, target, detail)
	if not IsValid(bot) then return end

	target = IsValid(target) and target or NULL
	detail = detail or ""

	if (bot.ZCBotNextDebugStateUpdate or 0) > CurTime() and bot.ZCBotDebugState == state and bot.ZCBotDebugTarget == target and bot.ZCBotDebugDetail == detail then return end

	local wep = bot:GetActiveWeapon()
	local targetDist = IsValid(target) and bot:GetPos():Distance(target:GetPos()) or 0

	bot.ZCBotDebugState = state
	bot.ZCBotDebugTarget = target
	bot.ZCBotDebugDetail = detail
	bot.ZCBotNextDebugStateUpdate = CurTime() + BOT_DEBUG_UPDATE_INTERVAL

	bot:SetNWString("ZCBotAIState", state or "")
	bot:SetNWEntity("ZCBotAITarget", target)
	bot:SetNWString("ZCBotAIDetail", detail)
	bot:SetNWString("ZCBotAIWeapon", IsValid(wep) and wep:GetClass() or "")
	bot:SetNWFloat("ZCBotAITargetDist", targetDist)
end

local function GetBotAimOrigin(bot)
	if not IsValid(bot) then return vector_origin end

	local wep = bot.GetActiveWeapon and bot:GetActiveWeapon()
	if IsValid(wep) and wep.GetMuzzleAtt then
		local ok, att = pcall(function()
			return wep:GetMuzzleAtt(nil, true)
		end)

		if ok and istable(att) and isvector(att.Pos) then return att.Pos end
	end

	return bot:EyePos()
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
	if bone and ent.IsRagdoll and ent:IsRagdoll() then
		local physBone = ent:TranslateBoneToPhysBone(bone)
		local phys = physBone and ent:GetPhysicsObjectNum(physBone)
		if phys and phys:IsValid() then return phys:GetPos() end
	end

	local matrix = bone and ent:GetBoneMatrix(bone)
	if matrix then return matrix:GetTranslation() end
end

local function AddAimCandidate(candidates, pos)
	if not isvector(pos) then return end

	for _, oldPos in ipairs(candidates) do
		if oldPos:DistToSqr(pos) <= 16 then return end
	end

	candidates[#candidates + 1] = pos
end

local function GetTargetAimCandidates(ent, bot)
	local candidates = {}
	if not IsValid(ent) then return candidates end

	if ent:IsPlayer() then
		local torsoPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or ent:WorldSpaceCenter()
		AddAimCandidate(candidates, torsoPos)
		AddAimCandidate(candidates, ent:EyePos())

		return candidates
	end

	local headPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Head1")
	local bodyPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local pelvisPos = GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis")
	local closeToRagdoll = headPos and IsValid(bot) and GetBotAimOrigin(bot):DistToSqr(headPos) <= BOT_RAGDOLL_HEAD_AIM_RANGE * BOT_RAGDOLL_HEAD_AIM_RANGE

	if closeToRagdoll then
		AddAimCandidate(candidates, headPos)
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
	else
		AddAimCandidate(candidates, bodyPos)
		AddAimCandidate(candidates, pelvisPos)
		AddAimCandidate(candidates, headPos)
	end

	AddAimCandidate(candidates, ent:WorldSpaceCenter())
	return candidates
end

local function GetTargetAimPos(ent, bot)
	local candidates = GetTargetAimCandidates(ent, bot)
	if candidates[1] then return candidates[1] end

	return IsValid(ent) and ent:WorldSpaceCenter() or vector_origin
end

BotCanSee = function(bot, body, aimPos)
	traceData.start = bot:EyePos()
	traceData.endpos = aimPos
	traceData.filter[1] = bot
	traceData.filter[2] = bot.FakeRagdoll

	local tr = util.TraceLine(traceData)
	return (not tr.Hit) or tr.Entity == body or (IsValid(body) and tr.Entity == body:GetNWEntity("ply"))
end

local function IsAimPosInBotFOV(bot, aimPos)
	local toAim = aimPos - bot:EyePos()
	if toAim:LengthSqr() <= 1 then return true end

	toAim:Normalize()
	return bot:EyeAngles():Forward():Dot(toAim) >= BOT_FOV_DOT
end

local function BotCanPerceive(bot, body, aimPos)
	return IsAimPosInBotFOV(bot, aimPos) and BotCanSee(bot, body, aimPos)
end

local function GetVisibleTargetAimPos(bot, body)
	local candidates = GetTargetAimCandidates(body, bot)
	local fallback = candidates[1] or GetTargetAimPos(body, bot)

	for _, aimPos in ipairs(candidates) do
		if BotCanPerceive(bot, body, aimPos) then return aimPos, true end
	end

	return fallback, false
end

local function SetBotViewAngles(bot, cmd, aimAng, smooth)
	smooth = smooth or BOT_AIM_SMOOTH_TRAVEL
	local current = bot:EyeAngles()
	local viewAng = LerpAngle(math_Clamp(smooth, 0, 1), current, aimAng)

	cmd:SetViewAngles(viewAng)
	bot:SetEyeAngles(viewAng)
	return viewAng
end

local function GetTargetTorsoPos(ent)
	if not IsValid(ent) then return end

	if ent:IsPlayer() then
		return GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or ent:WorldSpaceCenter()
	end

	return GetEntityBonePos(ent, "ValveBiped.Bip01_Spine2") or GetEntityBonePos(ent, "ValveBiped.Bip01_Pelvis") or ent:WorldSpaceCenter()
end

local function IsTargetInCover(bot, body)
	if not IsValid(body) then return false end

	local torsoPos = GetTargetTorsoPos(body)
	if not torsoPos or BotCanSee(bot, body, torsoPos) then return false end

	local headPos = GetEntityBonePos(body, "ValveBiped.Bip01_Head1") or (body:IsPlayer() and body:EyePos())
	return headPos and BotCanSee(bot, body, headPos)
end

local function IsUsableTarget(bot, ply)
	if ply == bot or not IsValid(ply) or not ply:Alive() then return false end
	if ply:Team() == TEAM_SPECTATOR and (not ply.IsBot or not ply:IsBot()) then return false end

	return IsValid(GetBotTargetBody(ply))
end

local function IsUnconsciousTarget(ply)
	return IsValid(ply) and ply:Alive() and ply.organism and ply.organism.unconscious
end

local function IsRagdolledTarget(ply)
	if not IsValid(ply) then return false end
	if IsValid(ply.FakeRagdoll) or IsValid(ply:GetNWEntity("FakeRagdoll")) then return true end

	return hg.GetFakeState and hg.FAKE_STATE and hg.GetFakeState(ply) ~= hg.FAKE_STATE.NONE
end

local function IsUprightThreat(ply)
	return IsUsableTarget(nil, ply) and not IsUnconsciousTarget(ply) and not IsRagdolledTarget(ply)
end

local function HasNearbyUprightEnemy(bot, ignoreTarget)
	local botPos = bot:GetPos()
	local rangeSqr = BOT_RAGDOLL_DEPRIORITIZE_RANGE * BOT_RAGDOLL_DEPRIORITIZE_RANGE

	for _, ply in ipairs(player.GetAll()) do
		if ply == ignoreTarget or not IsUprightThreat(ply) then continue end
		if botPos:DistToSqr(ply:GetPos()) <= rangeSqr then return true end
	end

	return false
end

local function PickBotTarget(bot)
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

local function HasVisibleEnemy(bot)
	for _, ply in ipairs(player.GetAll()) do
		if not IsUsableTarget(bot, ply) then continue end

		local body = GetBotTargetBody(ply)
		local _, visible = GetVisibleTargetAimPos(bot, body)
		if visible then return true end
	end

	return false
end

local function CanCurrentlyTarget(bot, ply)
	if not IsUsableTarget(bot, ply) then return false end

	local body = GetBotTargetBody(ply)
	local _, visible = GetVisibleTargetAimPos(bot, body)
	return visible
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

local function IsBotUsableDoor(ent)
	return IsValid(ent) and hgIsDoor and hgIsDoor(ent) and not ent:GetNoDraw()
end

local function IsBotClosedDoor(ent)
	if not IsBotUsableDoor(ent) then return false end
	if not DoorIsOpen2 then return true end

	return not DoorIsOpen2(ent)
end

local function TraceBotDoorAhead(bot, moveDir, tr)
	if tr and IsBotUsableDoor(tr.Entity) then return tr.Entity end

	doorTraceData.filter[1] = bot
	doorTraceData.filter[2] = bot.FakeRagdoll

	local offsets = {
		Vector(0, 0, 26),
		Vector(0, 0, 54),
	}

	for _, offset in ipairs(offsets) do
		doorTraceData.start = bot:GetPos() + offset
		doorTraceData.endpos = doorTraceData.start + moveDir * BOT_DOOR_TRACE_DISTANCE

		local doorTr = util.TraceLine(doorTraceData)
		if IsBotUsableDoor(doorTr.Entity) then return doorTr.Entity end
	end
end

local function TryBotOpenDoor(bot, cmd, door)
	if not IsBotClosedDoor(door) then return false end

	local doorCenter = door:LocalToWorld(door:OBBCenter())
	local aimAng = (doorCenter - bot:EyePos()):Angle()
	SetBotViewAngles(bot, cmd, aimAng, 0.4)

	cmd:SetForwardMove(math_min(cmd:GetForwardMove(), 120))
	cmd:SetSideMove(0)

	if bot.ZCBotDoorUseTarget == door and (bot.ZCBotNextDoorUse or 0) > CurTime() then return true end

	bot.ZCBotDoorUseTarget = door
	bot.ZCBotNextDoorUse = CurTime() + BOT_DOOR_USE_COOLDOWN

	local oldSpeed = door.GetInternalVariable and door:GetInternalVariable("Speed")
	if oldSpeed and door.SetSaveValue then door:SetSaveValue("Speed", 1000) end
	door:Use(bot)
	if oldSpeed and door.SetSaveValue then door:SetSaveValue("Speed", oldSpeed) end

	BotDevPrint(string.format("%s opened door %s", bot:Name(), door:GetClass()))
	return true
end

local function ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	if (bot.ZCBotUnstuckUntil or 0) > CurTime() then return false end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return false end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return false end

	moveDir:Normalize()
	local mins, maxs = bot:GetHull()
	hullTraceData.start = bot:GetPos() + Vector(0, 0, 18)
	hullTraceData.endpos = hullTraceData.start + moveDir * BOT_OBSTACLE_TRACE_DISTANCE
	hullTraceData.mins = mins + Vector(3, 3, 4)
	hullTraceData.maxs = maxs - Vector(3, 3, 18)
	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	local tr = util.TraceHull(hullTraceData)
	local door = TraceBotDoorAhead(bot, moveDir, tr)
	if TryBotOpenDoor(bot, cmd, door) then return true end

	if not tr.Hit then return false end

	local rightDot = tr.HitNormal:Dot(moveAng:Right())
	cmd:SetForwardMove(math_min(forwardMove, 140))
	cmd:SetSideMove(rightDot > 0 and 300 or -300)

	return true
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

	if bot.ZCBotUnstuckShouldJump and (bot.ZCBotNextJump or 0) < CurTime() then
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
	if math_abs(cmd:GetForwardMove()) < 80 and math_abs(cmd:GetSideMove()) < 80 then return end
	if not bot:IsOnGround() then return end

	local pos = bot:GetPos()
	local oldPos = bot.ZCBotLastStuckPos
	bot.ZCBotLastStuckPos = pos
	bot.ZCBotNextStuckCheck = CurTime() + BOT_STUCK_INTERVAL

	if not oldPos then return end

	local moved = oldPos:Distance(pos)
	if moved >= BOT_STUCK_MIN_DISTANCE then
		bot.ZCBotStuckAttempts = 0
		return
	end

	bot.ZCBotStuckAttempts = (bot.ZCBotStuckAttempts or 0) + 1

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
	bot.ZCBotUnstuckShouldJump = (bot.ZCBotStuckAttempts or 0) >= BOT_STUCK_JUMP_ATTEMPTS

	ApplyBotUnstuckMove(bot, cmd)

	if bot.ZCBotUnstuckShouldJump and (bot.ZCBotNextJump or 0) < CurTime() then
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
		aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)
	end

	SetBotMovementToward(bot, cmd, waypoint, aimAng, runSpeed)
	if allowSprint then
		TryBotTravelSprint(bot, cmd, destPos)
	end

	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
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
	if not IsValid(wep) or wep:Clip1() >= wep:GetMaxClip1() then return false end
	if wep:GetMaxClip1() == 0 then return false end

	return HasReserveAmmoForWeapon(bot, wep)
end

local function ShouldCycleManualAction(wep)
	if not IsValid(wep) or wep.drawBullet ~= false then return false end
	if wep:Clip1() <= 0 then return false end

	local nextCycle = wep.GetNetVar and wep:GetNetVar("shootgunReload", 0) or 0
	return nextCycle <= CurTime()
end

local function IsAutomaticWeapon(wep)
	if not IsValid(wep) then return false end

	local primary = wep.Primary
	if primary and (primary.Automatic or primary.RealAutomatic) then return true end

	local stored = weapons.GetStored and weapons.GetStored(wep:GetClass()) or weapons.Get(wep:GetClass())
	return stored and stored.Primary and stored.Primary.Automatic or false
end

local function IsWeaponReadyToFire(wep)
	if not IsValid(wep) then return true end

	local primary = wep.Primary
	if primary then
		if (primary.Next or 0) > CurTime() then return false end
		if (primary.NextFire or 0) > CurTime() then return false end
	end

	if wep.reload or wep.deploy then return false end
	if wep.CanPrimaryAttack and wep:CanPrimaryAttack() == false then return false end

	return true
end

local function IsSingleRoundReloadWeapon(wep)
	return WeaponInheritsBase(wep, "weapon_m4super")
end

local function IsWeaponDry(wep)
	if not IsValid(wep) then return false end
	if ShouldCycleManualAction(wep) then return true end
	if wep:Clip1() <= 0 then return true end

	return wep.drawBullet == false
end

local function GetReloadGoalClip(bot, wep, enemyNearby)
	local maxClip = wep:GetMaxClip1()
	if not IsSingleRoundReloadWeapon(wep) or not enemyNearby then return maxClip end

	local reserve = 0
	local primary = wep.Primary
	local ammoName = primary and primary.Ammo
	if ammoName and ammoName ~= "none" then
		reserve = bot:GetAmmoCount(ammoName)
	else
		local ammoType = wep:GetPrimaryAmmoType()
		reserve = ammoType and ammoType >= 0 and bot:GetAmmoCount(ammoType) or 0
	end

	local targetClip = (bot.ZCBotReloadStartClip or wep:Clip1()) + BOT_COMBAT_RELOAD_SHELLS
	return math_min(maxClip, targetClip, wep:Clip1() + reserve)
end

local function BotPressReload(bot, cmd, wep)
	if IsSingleRoundReloadWeapon(wep) then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
		return true
	end

	if (bot.ZCBotReloadPulseUntil or 0) > CurTime() then return false end
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_RELOAD))
	bot.ZCBotReloadPulseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

local function BotPressAttack(bot, cmd, wep, dist)
	if IsAutomaticWeapon(wep) then
		if dist and dist > BOT_CQB_MAGDUMP_RANGE and (bot.ZCBotAutoBurstUntil or 0) <= CurTime() then
			if (bot.ZCBotAutoBurstPauseUntil or 0) > CurTime() then return false end

			bot.ZCBotAutoBurstUntil = CurTime() + BOT_AUTO_BURST_TIME
			bot.ZCBotAutoBurstPauseUntil = bot.ZCBotAutoBurstUntil + BOT_AUTO_BURST_PAUSE
		end

		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return true
	end

	if (bot.ZCBotAttackReleaseUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	bot.ZCBotAttackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

local function BotTapAttack(bot, cmd, wep)
	if (bot.ZCBotTapAttackUntil or 0) > CurTime() then return false end
	if not IsWeaponReadyToFire(wep) then return false end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
	bot.ZCBotTapAttackUntil = CurTime() + BOT_UNCONSCIOUS_TAP_INTERVAL
	bot.ZCBotAttackReleaseUntil = CurTime() + BOT_ATTACK_PULSE_RELEASE
	return true
end

local function IsRangedWeapon(wep)
	if not IsValid(wep) or IsMedicineWeapon(wep) then return false end

	local primary = wep.Primary
	if not primary or primary.Ammo == "none" then return false end

	return WeaponInheritsBase(wep, "homigrad_base")
end

local function IsHandsWeapon(wep)
	return IsValid(wep) and wep:GetClass() == "weapon_hands_sh"
end

local function IsSecondaryRangedWeapon(wep)
	if not IsRangedWeapon(wep) then return false end
	if wep.SecondaryWeapon or wep.IsSecondaryWeapon or wep.IsPistol then return true end

	local class = wep:GetClass()
	if SECONDARY_WEAPON_CLASSES[class] then return true end

	return class:find("pistol", 1, true) or class:find("revolver", 1, true)
end

local function IsPrimaryRangedWeapon(wep)
	return IsRangedWeapon(wep) and not IsSecondaryRangedWeapon(wep)
end

local function SelectWeaponIfNeeded(bot, active, wep)
	if not IsValid(wep) then return active end
	if active ~= wep then bot:SelectWeapon(wep:GetClass()) end

	return wep
end

local function IsMeleeWeapon(wep)
	if not IsValid(wep) then return true end
	if IsRangedWeapon(wep) then return false end

	local class = wep:GetClass()
	return class == "weapon_hands_sh" or class == "weapon_melee" or class:find("hands", 1, true) or class:find("melee", 1, true) or WeaponInheritsBase(wep, "weapon_melee")
end

local function SelectBotWeapon(bot)
	local active = bot:GetActiveWeapon()
	if IsPrimaryRangedWeapon(active) and HasAmmoForWeapon(bot, active) then return active end

	local primary
	local secondary
	local melee
	local hands = IsHandsWeapon(active) and active or nil

	for _, wep in ipairs(bot:GetWeapons()) do
		if not IsValid(wep) or IsMedicineWeapon(wep) then continue end

		if IsHandsWeapon(wep) then
			hands = hands or wep
		elseif IsPrimaryRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			primary = primary or wep
		elseif IsSecondaryRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			secondary = secondary or wep
		elseif IsMeleeWeapon(wep) then
			melee = melee or wep
		end
	end

	return SelectWeaponIfNeeded(bot, active, primary or secondary or melee or hands or active)
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
		SetBotDebugState(bot, "healing", NULL, needsTourniquet and "tourniquet" or "bandage")
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
	SetBotDebugState(bot, "healing", NULL, wep:GetClass())
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)
	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))

	BotDevPrint(string.format("%s self-care=%s", bot:Name(), wep:GetClass()))
	return true
end

local function TryBotFakeUp(bot)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end
	if (bot.ZCBotFakeUpCooldownUntil or 0) > CurTime() then return true end
	if (bot.LastFakeUp or 0) + BOT_FAKEUP_COOLDOWN > CurTime() then return true end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then
		bot.ZCBotFakeUpAllowedAt = nil
		return false
	end

	if fakeState == hg.FAKE_STATE.ACTIVE then
		if not bot.ZCBotFakeUpAllowedAt then
			bot.ZCBotFakeUpAllowedAt = CurTime() + BOT_FAKEUP_INITIAL_DELAY
		end

		if bot.ZCBotFakeUpAllowedAt > CurTime() then
			SetBotDebugState(bot, "fake", bot.ZCBotTarget, string.format("getup in %.1fs", bot.ZCBotFakeUpAllowedAt - CurTime()))
			return true
		end
	end

	if fakeState == hg.FAKE_STATE.ACTIVE and (bot.ZCBotNextFakeUpTry or 0) <= CurTime() then
		bot.ZCBotNextFakeUpTry = CurTime() + BOT_FAKEUP_INTERVAL
		SetBotDebugState(bot, "fake", bot.ZCBotTarget, "trying getup")
		if hg.FakeUp and hg.FakeUp(bot) then
			bot.ZCBotFakeUpCooldownUntil = CurTime() + BOT_FAKEUP_COOLDOWN
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

local function BiasPosTowardDeathmatchCenter(bot, pos, round)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return pos end

	local botPos = bot:GetPos()
	local currentDist = botPos:Distance(center)
	if currentDist <= BOT_ZONE_CENTER_REACH then return pos end
	if pos:Distance(center) < currentDist - BOT_ZONE_CENTER_BIAS_STEP then return pos end

	return center
end

local function ApplyDeathmatchCenterMovementBias(bot, cmd, aimAng, round)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end

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
	SetBotMovementToward(bot, cmd, center, aimAng, speed)
	return true
end

local function GetDeathmatchZoneEscapePos(bot, round)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return end

	local pos = bot:GetPos()
	local offset = pos - center
	local dist = offset:Length()
	if dist < radius - BOT_ZONE_ROAM_MARGIN then return end

	if dist <= 1 then return center end

	return center
end

local function IsDeathmatchZoneClose(bot, round)
	local center, radius = GetDeathmatchZoneInfo(round)
	if not center then return false end

	return bot:GetPos():Distance(center) >= radius - BOT_ZONE_ROAM_MARGIN
end

local function AvoidDeathmatchZone(bot, cmd, round)
	local escapePos = GetDeathmatchZoneEscapePos(bot, round)
	if not escapePos then return false end
	SetBotDebugState(bot, "zone", bot.ZCBotTarget, "move to center")

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

local function MoveToDeathmatchZoneCenter(bot, cmd, round, ignoreTimeLimit, reachDistance)
	if not IsDeathmatchRoundActive(round) then return false end
	if not ignoreTimeLimit and CurTime() > (zb.ROUND_START or 0) + BOT_ZONE_CENTER_TIME then return false end

	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	reachDistance = reachDistance or BOT_ZONE_CENTER_REACH
	if bot:GetPos():DistToSqr(center) <= reachDistance * reachDistance then return false end
	SetBotDebugState(bot, "center", bot.ZCBotTarget, ignoreTimeLimit and "regroup" or "opening move")

	local aimAng = (center - bot:EyePos()):Angle()
	aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)

	local followedPath = FollowBotPath(bot, cmd, center, aimAng, 420, true, true)
	if not followedPath then
		SetBotMovementToward(bot, cmd, center, aimAng, 360)
		TryBotTravelSprint(bot, cmd, center)
		ApplyBotUnstuckMove(bot, cmd)
		ApplyBotObstacleAvoidance(bot, cmd, aimAng)
		UpdateBotStuckState(bot, cmd, center)
	end

	return true
end

local function MoveToDeathmatchZoneCenterWhileAiming(bot, cmd, round, aimAng, runSpeed)
	local center = GetDeathmatchZoneInfo(round)
	if not center then return false end
	if bot:GetPos():DistToSqr(center) <= BOT_ZONE_CENTER_REACH * BOT_ZONE_CENTER_REACH then return false end
	SetBotDebugState(bot, "zone+combat", bot.ZCBotTarget, "fighting to center")

	SetBotMovementToward(bot, cmd, center, aimAng, runSpeed or 360)
	TryBotTravelSprint(bot, cmd, center)
	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, center)
	return true
end

local function GetNearestEnemy(bot, maxRange)
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

local function AvoidEnemiesDuringSafeTime(bot, cmd, round)
	local enemy = GetNearestEnemy(bot, BOT_SAFE_ENEMY_AVOID_RANGE)
	if not IsValid(enemy) then return false end
	SetBotDebugState(bot, "safe-time", enemy, "avoid enemy")

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

local function ClearCombatButtons(cmd)
	cmd:SetButtons(bit_band(cmd:GetButtons(), bit_bnot(bit_bor(IN_ATTACK, IN_ATTACK2, IN_RELOAD))))
end

local function ClearBotTarget(bot)
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

local function UpdateBotTarget(bot)
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

local function GetBotReactionDelay(dist)
	local distanceFrac = math_Clamp(dist / BOT_REACTION_DISTANCE, 0, 1)
	return math_Lerp(distanceFrac, BOT_REACTION_MIN, BOT_REACTION_MAX)
end

local function IsBotReactionReady(bot, target, canPerceive, dist)
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

local function GetBotSightTime(bot, target)
	if bot.ZCBotSeenTarget ~= target or not bot.ZCBotSeenTargetStart then return 0 end
	return CurTime() - bot.ZCBotSeenTargetStart
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

local function AimBotAt(bot, cmd, aimPos, spread, smooth)
	local aimOrigin = GetBotAimOrigin(bot)
	local toAim = aimPos - aimOrigin
	if toAim:LengthSqr() <= 1 then return bot:EyeAngles(), 0 end

	local aimAng = toAim:Angle()
	aimAng.p = aimAng.p + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng.y = aimAng.y + math_Rand(-BOT_AIM_JITTER, BOT_AIM_JITTER)
	aimAng = ApplyBotAimSpread(bot, aimAng, spread or 0)
	aimAng = SetBotViewAngles(bot, cmd, aimAng, smooth or BOT_AIM_SMOOTH_COMBAT)

	return aimAng, toAim:Length()
end

local function FaceRecentThreat(bot, cmd)
	if (bot.ZCBotThreatUntil or 0) <= CurTime() or not isvector(bot.ZCBotThreatPos) then return false end

	local toThreat = bot.ZCBotThreatPos - bot:EyePos()
	if toThreat:LengthSqr() <= 1 then return false end

	SetBotViewAngles(bot, cmd, toThreat:Angle(), BOT_AIM_SMOOTH_COMBAT)
	return true
end

local function EvadeTarget(bot, cmd, target, aimAng)
	if not IsValid(target) then return end

	local away = bot:GetPos() - target:GetPos()
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

local function ResetBotReloadState(bot)
	bot.ZCBotReloadWeapon = nil
	bot.ZCBotReloadStartClip = nil
	bot.ZCBotReloadGoalClip = nil
	bot.ZCBotReloadPulseUntil = nil
end

local function IsWeaponReloadBusy(wep)
	if not IsValid(wep) then return false end
	if wep.reload then return true end

	local nextCycle = wep.GetNetVar and wep:GetNetVar("shootgunReload", 0) or 0
	return nextCycle > CurTime()
end

local function TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime)
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

local function HoldAndScan(bot, cmd)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)

	if (bot.ZCBotNextScanTurn or 0) <= CurTime() then
		bot.ZCBotNextScanTurn = CurTime() + math_Rand(1.1, 1.8)
		bot.ZCBotScanYaw = bot:EyeAngles().y + math_Rand(75, 135) * (math_random(0, 1) == 1 and 1 or -1)
	end

	local scanAng = Angle(0, bot.ZCBotScanYaw or bot:EyeAngles().y, 0)
	SetBotViewAngles(bot, cmd, scanAng, BOT_AIM_SMOOTH_TRAVEL)
end

local function PickDeathmatchCenterPatrolArea(bot, center, round)
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

local function RoamBot(bot, cmd)
	local round = GetCurrentRound()
	local center = GetDeathmatchZoneInfo(round)
	if center then
		if MoveToDeathmatchZoneCenter(bot, cmd, round, true, BOT_ZONE_CENTER_REACH) then return end

		local area = PickDeathmatchCenterPatrolArea(bot, center, round)
		if not IsValid(area) then
			HoldAndScan(bot, cmd)
			SetBotDebugState(bot, "center", NULL, "scan")
			return
		end

		local destPos = GetAreaWaypoint(area)
		if bot:GetPos():DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
			bot.ZCBotCenterPatrolArea = nil
			bot.ZCBotNextCenterPatrolPick = 0
			HoldAndScan(bot, cmd)
			SetBotDebugState(bot, "center", NULL, "scan")
			return
		end
		SetBotDebugState(bot, "center", NULL, "patrol")

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
	SetBotDebugState(bot, "patrol", NULL, "roam")

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

local function TryBotAttackCurrentTarget(bot, cmd, safeTime)
	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then return false end

	local body = GetBotTargetBody(target)
	local aimPos, canSee = GetVisibleTargetAimPos(bot, body)
	if not canSee then return false end

	local rawDist = aimPos:Distance(bot:EyePos())
	if rawDist <= 1 then return false end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	local attackRange = meleeWeapon and BOT_MELEE_ATTACK_RANGE or BOT_ATTACK_RANGE
	local reactionReady = IsBotReactionReady(bot, target, canSee, rawDist)
	local baseAimSpread = GetBotAimSpread(bot, target, true)
	local tapTarget = IsUnconsciousTarget(target)
	local meleeOffset = target:GetPos() - bot:GetPos()
	meleeOffset.z = 0
	local attackDist = meleeWeapon and meleeOffset:Length() or rawDist
	local shouldFire = not safeTime and reactionReady and attackDist <= attackRange and (meleeWeapon or IsBotConfidentToFire(bot, target, rawDist, baseAimSpread))
	local aimSpread = baseAimSpread + (tapTarget and 0 or GetBotBurstSpread(bot, target, shouldFire))
	local aimAng = AimBotAt(bot, cmd, aimPos, aimSpread)
	if TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
		SetBotDebugState(bot, "reload", target, "evade")
		return true
	end

	SetBotDebugState(bot, meleeWeapon and "fake melee" or "fake combat", target, shouldFire and "attacking" or "aiming")

	if shouldFire then
		if tapTarget then
			BotTapAttack(bot, cmd, wep)
		else
			BotPressAttack(bot, cmd, wep, rawDist)
		end
	end

	return true
end

local function HandleBotFakeState(bot, cmd, safeTime)
	if not hg.GetFakeState or not hg.FAKE_STATE then return false end

	local fakeState = hg.GetFakeState(bot)
	if fakeState == hg.FAKE_STATE.NONE then return false end

	if fakeState == hg.FAKE_STATE.ACTIVE then
		UpdateBotTarget(bot)
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_USE))
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
		SetBotDebugState(bot, "dead", NULL, "")
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return
	end

	local round = GetCurrentRound()
	local safeTime = IsDeathmatchSafeTime(round)
	if safeTime then ClearCombatButtons(cmd) end

	if HandleBotFakeState(bot, cmd, safeTime) then return end
	if safeTime and AvoidEnemiesDuringSafeTime(bot, cmd, round) then
		ClearCombatButtons(cmd)
		return
	end

	if not HasVisibleEnemy(bot) and TryBotSelfCare(bot, cmd) then return end

	UpdateBotTarget(bot)

	if AvoidDeathmatchZone(bot, cmd, round) then
		TryBotAttackCurrentTarget(bot, cmd, safeTime)
		if safeTime then ClearCombatButtons(cmd) end
		return
	end
	if not IsUprightThreat(bot.ZCBotTarget) and MoveToDeathmatchZoneCenter(bot, cmd, round) then
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	local target = bot.ZCBotTarget
	if not IsUsableTarget(bot, target) then
		SetBotDebugState(bot, "patrol", NULL, "no target")
		RoamBot(bot, cmd)
		FaceRecentThreat(bot, cmd)
		return
	end

	local body = GetBotTargetBody(target)
	local aimPos, canSee = GetVisibleTargetAimPos(bot, body)
	if not canSee then
		SetBotDebugState(bot, "search", target, "lost sight")
		ClearBotTarget(bot)
		RoamBot(bot, cmd)
		FaceRecentThreat(bot, cmd)
		return
	end

	local rawDist = aimPos:Distance(bot:EyePos())
	if rawDist <= 1 then return end

	local wep = SelectBotWeapon(bot)
	local meleeWeapon = IsMeleeWeapon(wep)
	local chasePos = (meleeWeapon and IsRagdolledTarget(target) and IsValid(body)) and body:GetPos() or target:GetPos()
	local flat = (meleeWeapon and chasePos or aimPos) - bot:GetPos()
	flat.z = 0
	local flatDist = flat:Length()
	if flatDist > 1 then flat:Normalize() end
	local attackRange = meleeWeapon and BOT_MELEE_ATTACK_RANGE or BOT_ATTACK_RANGE
	local reactionReady = IsBotReactionReady(bot, target, canSee, rawDist)
	local baseAimSpread = GetBotAimSpread(bot, target, canSee)
	local tapTarget = IsUnconsciousTarget(target)
	local attackDist = meleeWeapon and flatDist or rawDist
	local shouldFire = not safeTime and canSee and reactionReady and attackDist <= attackRange and (meleeWeapon or IsBotConfidentToFire(bot, target, rawDist, baseAimSpread))
	local aimSpread = baseAimSpread + (tapTarget and 0 or GetBotBurstSpread(bot, target, shouldFire))
	local meleeLookPos = (meleeWeapon and not IsRagdolledTarget(target)) and target:EyePos() or aimPos
	local aimAng, dist = AimBotAt(bot, cmd, meleeLookPos, meleeWeapon and 0 or aimSpread)
	if dist <= 1 then return end
	if TryBotReloadAndEvade(bot, cmd, wep, target, aimAng, rawDist, safeTime) then
		SetBotDebugState(bot, "reload", target, "evade")
		return
	end

	if meleeWeapon then
		SetBotDebugState(bot, "melee", target, shouldFire and "swing" or "charge")
		if flatDist > BOT_MELEE_RANGE * 0.85 then
			local followedPath = FollowBotPath(bot, cmd, chasePos, aimAng, 460, false, false)
			if not followedPath then
				SetBotMovementToward(bot, cmd, chasePos, aimAng, 430)
				ApplyBotUnstuckMove(bot, cmd)
				ApplyBotObstacleAvoidance(bot, cmd, aimAng)
				UpdateBotStuckState(bot, cmd, chasePos)
			end

			if flatDist > BOT_CLOSE_RANGE and GetBotStaminaFraction(bot) > BOT_SPRINT_STAMINA_FRACTION then
				cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_SPEED))
			end
		else
			cmd:SetForwardMove(120)
			cmd:SetSideMove(0)
			ApplyBotObstacleAvoidance(bot, cmd, aimAng)
			UpdateBotStuckState(bot, cmd, chasePos)
		end

		if shouldFire then
			BotPressAttack(bot, cmd, wep, rawDist)
		end

		return
	end

	if IsDeathmatchZoneClose(bot, round) and MoveToDeathmatchZoneCenterWhileAiming(bot, cmd, round, aimAng, 420) then
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
		SetBotDebugState(bot, "combat", target, shouldFire and "fire/strafe" or "strafe")
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
		SetBotDebugState(bot, "combat", target, shouldFire and "fire/advance" or "advance")
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
		SetBotDebugState(bot, "combat", target, shouldFire and "fire/hold" or "hold")
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

	if not isvector(threatPos) or threatPos:IsZero() then return end

	ent.ZCBotThreatPos = threatPos
	ent.ZCBotThreatUntil = CurTime() + BOT_THREAT_MEMORY_TIME
	ent.ZCBotNextTargetScan = 0
end)
