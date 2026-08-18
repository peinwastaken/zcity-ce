zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local math_abs, math_Rand, math_random, math_min, math_huge = math_abs, math_Rand, math_random, math_min, math_huge
local ipairs, Vector, Angle = ipairs, Vector, Angle
local navmesh, player, util = navmesh, player, util

local NAV_CURRENT_AREA_REFRESH = 0.35
local NAV_GOAL_AREA_REFRESH = 0.25
local NAV_GOAL_REQUERY_DISTANCE_SQR = 256 * 256
local NAV_SAFETY_REPATH_INTERVAL = math.max(BOT_NAV_REPATH_INTERVAL * 8, 5)
local NAV_DEVIATION_BACKTRACK_AREAS = 2
local NAV_AREA_SEARCH_AHEAD = 3
local NAV_AREA_SEARCH_BEHIND = 2
local NAV_AREA_VERTICAL_TOLERANCE = 64

local WAYPOINT_PROBE_INTERVAL = 0.12
local WAYPOINT_PROBE_MOVE_SQR = 42 * 42
local WAYPOINT_PROBE_TARGET_SQR = 24 * 24
local OBSTACLE_PROBE_INTERVAL = 0.1
local OBSTACLE_CACHE_LIFETIME = 0.18
local OBSTACLE_PROBE_MOVE_SQR = 30 * 30
local OBSTACLE_DIRECTION_DOT = 0.94
local DOOR_PROBE_INTERVAL = 0.25
local DOOR_CACHE_LIFETIME = 0.35

local TRACE_MOVE_OFFSET = Vector(0, 0, 18)
local TRACE_LINE_OFFSET = Vector(0, 0, 8)
local TRACE_HULL_SHRINK_MINS = Vector(3, 3, 4)
local TRACE_HULL_SHRINK_MAXS = Vector(3, 3, 18)
local DOOR_TRACE_OFFSETS = {
	Vector(0, 0, 26),
	Vector(0, 0, 54),
}

local EMPTY_NAV_AREAS = {}
local cachedNavAreas
local cachedAreaCenters = {}
local nextNavCacheAttempt = 0

local function ClearBotPathState(bot)
	bot.ZCBotPath = nil
	bot.ZCBotPathIndex = nil
	bot.ZCBotPathLookup = nil
	bot.ZCBotPathGoal = nil
	bot.ZCBotPathSafetyRefresh = nil
	bot.ZCBotWaypointProbePrimary = nil
	bot.ZCBotWaypointProbeSkip = nil
end

local function ClearBotNavAreaState(bot)
	ClearBotPathState(bot)
	bot.ZCBotCurrentNavArea = nil
	bot.ZCBotNextCurrentAreaUpdate = nil
	bot.ZCBotGoalNavArea = nil
	bot.ZCBotGoalNavPos = nil
	bot.ZCBotNextGoalAreaUpdate = nil
	bot.ZCBotRoamArea = nil
	bot.ZCBotNextRoamPick = 0
	bot.ZCBotNextPathTime = 0
	bot.ZCBotCachedDoor = nil
	bot.ZCBotCachedDoorUntil = nil
	bot.ZCBotNextDoorProbe = 0
	bot.ZCBotObstacleHit = false
	bot.ZCBotObstacleNormal = nil
	bot.ZCBotObstacleCacheUntil = nil
	bot.ZCBotNextObstacleProbe = 0
end

function InvalidateBotNavAreaCache()
	cachedNavAreas = nil
	cachedAreaCenters = {}
	nextNavCacheAttempt = 0

	if not player or not player.GetAll then return end
	for _, bot in ipairs(player.GetAll()) do
		if IsValid(bot) and bot.IsBot and bot:IsBot() then
			ClearBotNavAreaState(bot)
		end
	end
end

hook.Add("InitPostEntity", "ZC_PlayerBotInvalidateNavAreaCache", InvalidateBotNavAreaCache)
hook.Add("PostCleanupMap", "ZC_PlayerBotInvalidateNavAreaCache", InvalidateBotNavAreaCache)

function GetCachedBotNavAreas()
	if cachedNavAreas then return cachedNavAreas end
	if not navmesh or not navmesh.GetAllNavAreas then return EMPTY_NAV_AREAS end
	if nextNavCacheAttempt > CurTime() then return EMPTY_NAV_AREAS end

	local sourceAreas = navmesh.GetAllNavAreas()
	if not sourceAreas or #sourceAreas == 0 then
		nextNavCacheAttempt = CurTime() + 1
		return EMPTY_NAV_AREAS
	end

	local areas = {}
	local centers = {}
	for _, area in ipairs(sourceAreas) do
		if not IsValid(area) then continue end
		areas[#areas + 1] = area
		centers[area] = area:GetCenter()
	end

	if #areas == 0 then
		nextNavCacheAttempt = CurTime() + 1
		return EMPTY_NAV_AREAS
	end

	cachedNavAreas = areas
	cachedAreaCenters = centers
	return areas
end

function GetCachedAreaCenter(area)
	if not IsValid(area) then return vector_origin end

	local center = cachedAreaCenters[area]
	if center then return center end

	center = area:GetCenter()
	cachedAreaCenters[area] = center
	return center
end

function GetNearestBotNavArea(pos)
	if not navmesh or not navmesh.GetNearestNavArea then return nil end

	local area = navmesh.GetNearestNavArea(pos, false, 1200, false, false)
	if IsValid(area) then return area end

	area = navmesh.GetNearestNavArea(pos, true, 1200, false, false)
	if IsValid(area) then return area end
end

function PickRandomRoamArea(bot, areaFilter)
	local now = CurTime()
	if (bot.ZCBotNextRoamPick or 0) > now then
		if IsValid(bot.ZCBotRoamArea) and (not areaFilter or areaFilter(bot.ZCBotRoamArea)) then return bot.ZCBotRoamArea end
		if bot.ZCBotRoamArea == nil then return nil end
	end

	local areas = GetCachedBotNavAreas()
	if not areas or #areas == 0 then return nil end

	local currentArea = GetNearestBotNavArea(bot:GetPos())
	if IsValid(currentArea) then
		bot.ZCBotCurrentNavArea = currentArea
		bot.ZCBotNextCurrentAreaUpdate = CurTime() + NAV_CURRENT_AREA_REFRESH
	end

	local bestArea
	local bestScore = -math_huge
	local tries = math_min(#areas, BOT_ROAM_AREA_SAMPLES)
	local sampledIndices = {}
	local currentCenter = IsValid(currentArea) and GetCachedAreaCenter(currentArea)

	-- Partial Fisher-Yates sampling avoids scoring the same random area repeatedly.
	for sample = 1, tries do
		local remaining = #areas - sample + 1
		local pickedSlot = math_random(1, remaining)
		local areaIndex = sampledIndices[pickedSlot] or pickedSlot
		sampledIndices[pickedSlot] = sampledIndices[remaining] or remaining

		local area = areas[areaIndex]
		if not IsValid(area) then continue end
		if areaFilter and not areaFilter(area) then continue end

		local dist = currentCenter and currentCenter:DistToSqr(GetCachedAreaCenter(area)) or 0
		if dist < BOT_ROAM_MIN_DISTANCE * BOT_ROAM_MIN_DISTANCE then continue end

		local score = math_min(dist, 25000000) + math_Rand(0, 500000)
		if score > bestScore then
			bestScore = score
			bestArea = area
		end
	end

	if not IsValid(bestArea) and not areaFilter then
		bestArea = areas[math_random(1, #areas)]
	end

	bot.ZCBotRoamArea = bestArea
	bot.ZCBotNextRoamPick = now + (IsValid(bestArea) and BOT_ROAM_INTERVAL + math_Rand(0, 2) or 0.75)
	if IsValid(bestArea) then
		BotDevPrint("%s roam", bot:Name())
	end

	return bestArea
end

function ReconstructAreaPath(cameFrom, current)
	local reversedPath = {}
	while current do
		reversedPath[#reversedPath + 1] = current
		current = cameFrom[current]
	end

	local path = {}
	local count = #reversedPath
	for i = 1, count do
		path[i] = reversedPath[count - i + 1]
	end
	return path
end

local function PushAreaHeap(heap, area, score)
	local index = #heap + 1
	local entry = {area = area, score = score}

	while index > 1 do
		local parentIndex = math.floor(index * 0.5)
		local parent = heap[parentIndex]
		if parent.score <= score then break end

		heap[index] = parent
		index = parentIndex
	end

	heap[index] = entry
end

local function PopAreaHeap(heap)
	local count = #heap
	if count == 0 then return end

	local root = heap[1]
	local last = heap[count]
	heap[count] = nil
	count = count - 1
	if count == 0 then return root end

	local index = 1
	while true do
		local leftIndex = index * 2
		if leftIndex > count then break end

		local rightIndex = leftIndex + 1
		local childIndex = leftIndex
		if rightIndex <= count and heap[rightIndex].score < heap[leftIndex].score then
			childIndex = rightIndex
		end

		local child = heap[childIndex]
		if child.score >= last.score then break end

		heap[index] = child
		index = childIndex
	end

	heap[index] = last
	return root
end

function BuildAreaPath(startArea, goalArea)
	if not IsValid(startArea) or not IsValid(goalArea) then return end
	if startArea == goalArea then return {startArea} end

	local open = {}
	local cameFrom = {}
	local gScore = {[startArea] = 0}
	local fScore = {}
	local closed = {}
	local goalPos = GetCachedAreaCenter(goalArea)
	local startScore = GetCachedAreaCenter(startArea):Distance(goalPos)
	fScore[startArea] = startScore
	PushAreaHeap(open, startArea, startScore)
	local searched = 0

	while #open > 0 and searched < BOT_NAV_MAX_AREAS do
		local entry = PopAreaHeap(open)
		local current = entry.area
		if closed[current] or entry.score > (fScore[current] or math_huge) then continue end

		closed[current] = true
		searched = searched + 1

		if current == goalArea then
			return ReconstructAreaPath(cameFrom, current)
		end

		local currentCenter = GetCachedAreaCenter(current)
		for _, neighbor in ipairs(current:GetAdjacentAreas()) do
			if not IsValid(neighbor) then continue end

			if closed[neighbor] then continue end

			local neighborCenter = GetCachedAreaCenter(neighbor)
			local stepCost = currentCenter:Distance(neighborCenter)
			local heightCost = math_abs(current:ComputeAdjacentConnectionHeightChange(neighbor) or 0) * 4
			local tentative = (gScore[current] or math_huge) + stepCost + heightCost

			if tentative < (gScore[neighbor] or math_huge) then
				cameFrom[neighbor] = current
				gScore[neighbor] = tentative
				local score = tentative + neighborCenter:Distance(goalPos)
				fScore[neighbor] = score
				PushAreaHeap(open, neighbor, score)
			end
		end
	end
end

function GetAreaWaypoint(area)
	if not IsValid(area) then return vector_origin end
	return GetCachedAreaCenter(area)
end

function SetBotMovementToward(bot, cmd, movePos, aimAng, speed)
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

function GetBotStaminaFraction(bot)
	local org = bot.organism
	local stamina = org and org.stamina
	if not stamina then return 1 end

	local maxStamina = stamina.max or stamina.range or 180
	if maxStamina <= 0 then return 0 end

	return math_Clamp((stamina[1] or maxStamina) / maxStamina, 0, 1)
end

function TryBotTravelSprint(bot, cmd, destPos)
	if bot:Crouching() then return end
	if cmd:GetForwardMove() <= 120 then return end
	if bot:GetPos():DistToSqr(destPos) < BOT_SPRINT_DISTANCE * BOT_SPRINT_DISTANCE then return end
	if GetBotStaminaFraction(bot) <= BOT_SPRINT_STAMINA_FRACTION then return end

	cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_SPEED))
end

function IsBotUsableDoor(ent)
	return IsValid(ent) and hgIsDoor and hgIsDoor(ent) and not ent:GetNoDraw()
end

function IsBotClosedDoor(ent)
	if not IsBotUsableDoor(ent) then return false end
	if not DoorIsOpen2 then return true end

	return not DoorIsOpen2(ent)
end

function TraceBotDoorAhead(bot, moveDir, tr, now)
	now = now or CurTime()
	if tr and IsBotUsableDoor(tr.Entity) then
		bot.ZCBotCachedDoor = tr.Entity
		bot.ZCBotCachedDoorUntil = now + DOOR_CACHE_LIFETIME
		return tr.Entity
	end

	local lastDir = bot.ZCBotDoorProbeDir
	local directionChanged = not lastDir or lastDir:Dot(moveDir) < OBSTACLE_DIRECTION_DOT
	if not directionChanged and (bot.ZCBotNextDoorProbe or 0) > now then
		local cachedDoor = bot.ZCBotCachedDoor
		if (bot.ZCBotCachedDoorUntil or 0) > now and IsBotUsableDoor(cachedDoor) then return cachedDoor end
		return
	end

	bot.ZCBotNextDoorProbe = now + DOOR_PROBE_INTERVAL + bot:EntIndex() % 4 * 0.01
	bot.ZCBotDoorProbeDir = Vector(moveDir.x, moveDir.y, moveDir.z)
	bot.ZCBotCachedDoor = nil
	bot.ZCBotCachedDoorUntil = nil

	doorTraceData.filter[1] = bot
	doorTraceData.filter[2] = bot.FakeRagdoll
	local botPos = bot:GetPos()

	for _, offset in ipairs(DOOR_TRACE_OFFSETS) do
		doorTraceData.start = botPos + offset
		doorTraceData.endpos = doorTraceData.start + moveDir * BOT_DOOR_TRACE_DISTANCE

		local doorTr = util.TraceLine(doorTraceData)
		if IsBotUsableDoor(doorTr.Entity) then
			bot.ZCBotCachedDoor = doorTr.Entity
			bot.ZCBotCachedDoorUntil = now + DOOR_CACHE_LIFETIME
			return doorTr.Entity
		end
	end
end

function TryBotOpenDoor(bot, cmd, door)
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

	BotDevPrint("%s opened door %s", bot:Name(), door:GetClass())
	return true
end

function GetBotMovementHull(bot)
	local crouching = bot:Crouching()
	local mins, maxs
	if crouching and bot.GetHullDuck then
		mins, maxs = bot:GetHullDuck()
	end
	if not mins or not maxs then
		mins, maxs = bot:GetHull()
	end

	local model = bot.GetModel and bot:GetModel() or ""
	local changed = bot.ZCBotHullCrouching ~= crouching or bot.ZCBotHullModel ~= model
		or bot.ZCBotHullMinX ~= mins.x or bot.ZCBotHullMinY ~= mins.y or bot.ZCBotHullMinZ ~= mins.z
		or bot.ZCBotHullMaxX ~= maxs.x or bot.ZCBotHullMaxY ~= maxs.y or bot.ZCBotHullMaxZ ~= maxs.z

	if changed then
		bot.ZCBotHullCrouching = crouching
		bot.ZCBotHullModel = model
		bot.ZCBotHullMinX = mins.x
		bot.ZCBotHullMinY = mins.y
		bot.ZCBotHullMinZ = mins.z
		bot.ZCBotHullMaxX = maxs.x
		bot.ZCBotHullMaxY = maxs.y
		bot.ZCBotHullMaxZ = maxs.z
		bot.ZCBotHullRevision = (bot.ZCBotHullRevision or 0) + 1
	end

	return mins, maxs, bot.ZCBotHullRevision or 0
end

local function GetShrunkBotMovementHull(mins, maxs)
	local shrunkMins = mins + TRACE_HULL_SHRINK_MINS
	local shrunkMaxs = maxs - TRACE_HULL_SHRINK_MAXS
	if shrunkMins.x >= shrunkMaxs.x or shrunkMins.y >= shrunkMaxs.y or shrunkMins.z >= shrunkMaxs.z then
		return mins, maxs
	end
	return shrunkMins, shrunkMaxs
end

function TraceBotMoveDir(bot, moveDir, distance, shrinkHull, mins, maxs)
	if not mins or not maxs then mins, maxs = GetBotMovementHull(bot) end
	hullTraceData.start = bot:GetPos() + TRACE_MOVE_OFFSET
	hullTraceData.endpos = hullTraceData.start + moveDir * distance

	if shrinkHull then
		hullTraceData.mins, hullTraceData.maxs = GetShrunkBotMovementHull(mins, maxs)
	else
		hullTraceData.mins = mins
		hullTraceData.maxs = maxs
	end

	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	return util.TraceHull(hullTraceData)
end

function IsBotMoveDirClear(bot, moveDir, distance, mins, maxs)
	local tr = TraceBotMoveDir(bot, moveDir, distance, true, mins, maxs)
	return not tr.Hit or tr.Fraction > 0.82
end

local function ApplyCachedObstacleResponse(bot, cmd, moveAng, forwardMove)
	local normal = bot.ZCBotObstacleNormal
	if not normal then return false end

	local preferredSide = bot.ZCBotObstaclePreferredSide or 1
	local side = bot.ZCBotObstacleSide or preferredSide
	local forward = moveAng:Forward()

	if side == 0 or normal:Dot(forward) <= BOT_OBSTACLE_BACKOFF_DOT then
		cmd:SetForwardMove(-120)
		cmd:SetSideMove(preferredSide * 260)
	else
		cmd:SetForwardMove(math_min(forwardMove, 120))
		cmd:SetSideMove(side * 300)
	end

	return true
end

function ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	local now = CurTime()
	if (bot.ZCBotUnstuckUntil or 0) > now then return false end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return false end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return false end

	moveDir:Normalize()
	local botPos = bot:GetPos()
	local mins, maxs, hullRevision = GetBotMovementHull(bot)
	local lastDir = bot.ZCBotObstacleProbeDir
	local lastPos = bot.ZCBotObstacleProbePos
	local directionChanged = not lastDir or lastDir:Dot(moveDir) < OBSTACLE_DIRECTION_DOT
	local movedFar = not lastPos or lastPos:DistToSqr(botPos) >= OBSTACLE_PROBE_MOVE_SQR
	local shouldProbe = directionChanged or movedFar or bot.ZCBotObstacleHullRevision ~= hullRevision
		or (bot.ZCBotNextObstacleProbe or 0) <= now
	local tr

	if shouldProbe then
		bot.ZCBotNextObstacleProbe = now + OBSTACLE_PROBE_INTERVAL
		bot.ZCBotObstacleProbeDir = Vector(moveDir.x, moveDir.y, moveDir.z)
		bot.ZCBotObstacleProbePos = Vector(botPos.x, botPos.y, botPos.z)
		bot.ZCBotObstacleHullRevision = hullRevision
		tr = TraceBotMoveDir(bot, moveDir, BOT_OBSTACLE_TRACE_DISTANCE, true, mins, maxs)

		if not tr.Hit then
			bot.ZCBotObstacleHit = false
			bot.ZCBotObstacleNormal = nil
			bot.ZCBotObstacleCacheUntil = now + OBSTACLE_CACHE_LIFETIME
			return false
		end
	end

	local door
	if shouldProbe then
		door = TraceBotDoorAhead(bot, moveDir, tr, now)
	elseif (bot.ZCBotCachedDoorUntil or 0) > now and IsBotUsableDoor(bot.ZCBotCachedDoor) then
		door = bot.ZCBotCachedDoor
	end

	if TryBotOpenDoor(bot, cmd, door) then
		bot.ZCBotObstacleHit = false
		bot.ZCBotObstacleNormal = nil
		return true
	end

	if not shouldProbe then
		if bot.ZCBotObstacleHit and (bot.ZCBotObstacleCacheUntil or 0) > now
			and bot.ZCBotObstacleHullRevision == hullRevision then
			return ApplyCachedObstacleResponse(bot, cmd, moveAng, forwardMove)
		end
		return false
	end

	local right = moveAng:Right()
	local rightDot = tr.HitNormal:Dot(right)
	local preferredSide = rightDot > 0 and 1 or -1
	local leftClear = IsBotMoveDirClear(bot, -right, BOT_OBSTACLE_SIDE_PROBE_DISTANCE, mins, maxs)
	local rightClear = IsBotMoveDirClear(bot, right, BOT_OBSTACLE_SIDE_PROBE_DISTANCE, mins, maxs)
	local side = preferredSide

	if preferredSide > 0 and not rightClear and leftClear then
		side = -1
	elseif preferredSide < 0 and not leftClear and rightClear then
		side = 1
	elseif not leftClear and not rightClear then
		side = 0
	end

	bot.ZCBotLastObstacleNormal = tr.HitNormal
	bot.ZCBotLastObstacleSide = side ~= 0 and side or preferredSide
	bot.ZCBotLastObstacleAt = now
	bot.ZCBotObstacleHit = true
	bot.ZCBotObstacleNormal = tr.HitNormal
	bot.ZCBotObstaclePreferredSide = preferredSide
	bot.ZCBotObstacleSide = side
	bot.ZCBotObstacleCacheUntil = now + OBSTACLE_CACHE_LIFETIME

	return ApplyCachedObstacleResponse(bot, cmd, moveAng, forwardMove)
end

function HasClearMoveLine(bot, pos, mins, maxs)
	if not mins or not maxs then mins, maxs = GetBotMovementHull(bot) end
	hullTraceData.start = bot:GetPos() + TRACE_LINE_OFFSET
	hullTraceData.endpos = pos + TRACE_LINE_OFFSET
	hullTraceData.mins = mins
	hullTraceData.maxs = maxs
	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	return not util.TraceHull(hullTraceData).Hit
end

local function HasCachedClearMoveLine(bot, pos, skipProbe, now, hullRevision, mins, maxs)
	local field = skipProbe and "ZCBotWaypointProbeSkip" or "ZCBotWaypointProbePrimary"
	local cached = bot[field]
	local botPos = bot:GetPos()
	if cached and cached.nextProbe > now and cached.hullRevision == hullRevision
		and cached.origin:DistToSqr(botPos) < WAYPOINT_PROBE_MOVE_SQR
		and cached.target:DistToSqr(pos) < WAYPOINT_PROBE_TARGET_SQR then
		return cached.clear
	end

	local clear = HasClearMoveLine(bot, pos, mins, maxs)
	if not cached then
		cached = {}
		bot[field] = cached
	end

	cached.nextProbe = now + WAYPOINT_PROBE_INTERVAL
	cached.hullRevision = hullRevision
	cached.origin = Vector(botPos.x, botPos.y, botPos.z)
	cached.target = Vector(pos.x, pos.y, pos.z)
	cached.clear = clear
	return clear
end

function ApplyBotUnstuckMove(bot, cmd)
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

function UpdateBotStuckState(bot, cmd, movePos)
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

	ClearBotPathState(bot)
	bot.ZCBotNextPathTime = 0
	bot.ZCBotRoamArea = nil
	bot.ZCBotNextRoamPick = 0
	bot.ZCBotUnstuckUntil = CurTime() + BOT_UNSTUCK_TIME
	bot.ZCBotNextStuckCheck = CurTime() + BOT_UNSTUCK_RETRY_TIME
	local recentObstacle = (bot.ZCBotLastObstacleAt or 0) + 2 > CurTime()
	bot.ZCBotUnstuckSide = recentObstacle and (bot.ZCBotLastObstacleSide or 1) or (math_random(0, 1) == 1 and 1 or -1)
	bot.ZCBotUnstuckForward = recentObstacle and -220 or (math_random(0, 1) == 1 and -220 or 120)
	bot.ZCBotUnstuckDuck = math_random(0, 2) == 0
	bot.ZCBotUnstuckShouldJump = (bot.ZCBotStuckAttempts or 0) >= BOT_STUCK_JUMP_ATTEMPTS

	ApplyBotUnstuckMove(bot, cmd)
end

local function AreaContainsPosition(area, pos)
	if not IsValid(area) or not area.Contains or not area:Contains(pos) then return false end
	local navZ = area.GetZ and area:GetZ(pos)
	if navZ and math_abs(navZ - pos.z) > NAV_AREA_VERTICAL_TOLERANCE then return false end
	return true
end

local function FindPathAreaAtPosition(path, index, pos)
	if not path or #path == 0 then return end

	local first = math.max(1, index - NAV_AREA_SEARCH_BEHIND)
	local last = math.min(#path, index + NAV_AREA_SEARCH_AHEAD)
	for i = first, last do
		local area = path[i]
		if AreaContainsPosition(area, pos) then return area end
	end
end

local function SetBotCurrentNavArea(bot, area, now)
	bot.ZCBotCurrentNavArea = area
	bot.ZCBotNextCurrentAreaUpdate = now + NAV_CURRENT_AREA_REFRESH
end

local function GetBotCurrentNavArea(bot, pos, path, index, now, forceQuery, allowNearestQuery)
	local area = bot.ZCBotCurrentNavArea
	if AreaContainsPosition(area, pos) then return area, true, false end

	local pathArea = FindPathAreaAtPosition(path, index or 1, pos)
	if IsValid(pathArea) then
		SetBotCurrentNavArea(bot, pathArea, now)
		return pathArea, true, false
	end

	if not forceQuery and (bot.ZCBotNextCurrentAreaUpdate or 0) > now then return area, false, false end
	if not IsValid(area) and (bot.ZCBotNextCurrentAreaUpdate or 0) > now then return area, false, false end
	if not allowNearestQuery then return area, false, false end

	area = GetNearestBotNavArea(pos)
	SetBotCurrentNavArea(bot, area, now)
	return area, IsValid(area), true
end

local function GetBotGoalNavArea(bot, destPos, now)
	local area = bot.ZCBotGoalNavArea
	if AreaContainsPosition(area, destPos) then
		bot.ZCBotGoalNavPos = Vector(destPos.x, destPos.y, destPos.z)
		return area, false
	end

	local oldPos = bot.ZCBotGoalNavPos
	local movedFar = not oldPos or oldPos:DistToSqr(destPos) >= NAV_GOAL_REQUERY_DISTANCE_SQR
	if not movedFar and (bot.ZCBotNextGoalAreaUpdate or 0) > now then
		return IsValid(area) and area or nil, false
	end

	local nearest = GetNearestBotNavArea(destPos)
	bot.ZCBotNextGoalAreaUpdate = now + NAV_GOAL_AREA_REFRESH
	bot.ZCBotGoalNavPos = Vector(destPos.x, destPos.y, destPos.z)
	if IsValid(nearest) then
		bot.ZCBotGoalNavArea = nearest
		return nearest, true
	end

	bot.ZCBotGoalNavArea = nil
	return nil, true
end

local function BuildAreaPathLookup(path)
	local lookup = {}
	for i, area in ipairs(path) do
		lookup[area] = i
	end
	return lookup
end

local function IsAreaPathValid(path, index)
	return path and #path > 0 and IsValid(path[index or 1]) and IsValid(path[#path])
end

function FollowBotPath(bot, cmd, destPos, aimAng, runSpeed, faceWaypoint, allowSprint)
	local now = CurTime()
	local botPos = bot:GetPos()
	if botPos:DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return true, true
	end

	local goalArea, usedNearestQuery = GetBotGoalNavArea(bot, destPos, now)
	if not IsValid(goalArea) then return false end

	local path = bot.ZCBotPath
	local index = bot.ZCBotPathIndex or 1
	local pathInvalid = path ~= nil and not IsAreaPathValid(path, index)
	local pathLookup = bot.ZCBotPathLookup
	if path and not pathLookup then
		pathLookup = BuildAreaPathLookup(path)
		bot.ZCBotPathLookup = pathLookup
	end

	local currentArea, currentAreaFresh, queriedCurrentArea = GetBotCurrentNavArea(
		bot,
		botPos,
		path,
		index,
		now,
		not path,
		not usedNearestQuery
	)
	usedNearestQuery = usedNearestQuery or queriedCurrentArea
	local deviation = false
	if path and currentAreaFresh and IsValid(currentArea) and pathLookup then
		local routeIndex = pathLookup[currentArea]
		if not routeIndex or routeIndex + NAV_DEVIATION_BACKTRACK_AREAS < index then
			deviation = true
		elseif routeIndex > index then
			index = routeIndex
			bot.ZCBotPathIndex = index
		end
	end

	local goalChanged = path and bot.ZCBotPathGoal ~= goalArea
	local safetyRefresh = path and (bot.ZCBotPathSafetyRefresh or 0) <= now
	local needsPath = not path or pathInvalid or goalChanged or deviation or safetyRefresh
	if needsPath then
		if not path and (bot.ZCBotNextPathTime or 0) > now then return false end

		if not currentAreaFresh or not IsValid(currentArea) then
			currentArea, currentAreaFresh, queriedCurrentArea = GetBotCurrentNavArea(
				bot,
				botPos,
				path,
				index,
				now,
				true,
				not usedNearestQuery
			)
			usedNearestQuery = usedNearestQuery or queriedCurrentArea
		end
		if not currentAreaFresh or not IsValid(currentArea) then return false end

		local newPath = BuildAreaPath(currentArea, goalArea)
		if newPath and #newPath > 0 then
			path = newPath
			index = #path > 1 and 2 or 1
			bot.ZCBotPath = path
			bot.ZCBotPathIndex = index
			bot.ZCBotPathLookup = BuildAreaPathLookup(path)
			bot.ZCBotPathGoal = goalArea
			bot.ZCBotNextPathTime = now + BOT_NAV_REPATH_INTERVAL
			bot.ZCBotPathSafetyRefresh = now + NAV_SAFETY_REPATH_INTERVAL + bot:EntIndex() % 8 * 0.11
			bot.ZCBotWaypointProbePrimary = nil
			bot.ZCBotWaypointProbeSkip = nil
		elseif safetyRefresh and not pathInvalid and not goalChanged and not deviation then
			-- Keep a still-valid route if only its periodic safety rebuild failed.
			bot.ZCBotPathSafetyRefresh = now + NAV_SAFETY_REPATH_INTERVAL
		else
			ClearBotPathState(bot)
			bot.ZCBotNextPathTime = now + BOT_NAV_REPATH_INTERVAL
			return false
		end
	end

	if not path or #path == 0 then return false end

	while index < #path and botPos:DistToSqr(GetAreaWaypoint(path[index])) <= BOT_NAV_WAYPOINT_REACH * BOT_NAV_WAYPOINT_REACH do
		index = index + 1
	end

	bot.ZCBotPathIndex = index

	local waypoint = index >= #path and destPos or GetAreaWaypoint(path[index])
	local mins, maxs, hullRevision = GetBotMovementHull(bot)
	if not HasCachedClearMoveLine(bot, waypoint, false, now, hullRevision, mins, maxs) and index < #path then
		local nextIndex = index + 1
		local nextWaypoint = nextIndex >= #path and destPos or GetAreaWaypoint(path[nextIndex])

		if HasCachedClearMoveLine(bot, nextWaypoint, true, now, hullRevision, mins, maxs) then
			index = nextIndex
			bot.ZCBotPathIndex = index
			waypoint = nextWaypoint
		end
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

