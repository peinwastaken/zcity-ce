zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local math_abs, math_Rand, math_random, math_min, math_huge = math_abs, math_Rand, math_random, math_min, math_huge
local ipairs, Vector, Angle = ipairs, Vector, Angle
local navmesh, player, util = navmesh, player, util

local BOT_NAV_REPATH_INTERVAL = 0.7
local BOT_NAV_WAYPOINT_REACH = 85
local BOT_NAV_MAX_AREAS = 1200
local BOT_ROAM_INTERVAL = 4
local BOT_ROAM_AREA_SAMPLES = 48
local BOT_ROAM_MIN_DISTANCE = 1400
local BOT_SPRINT_DISTANCE = 1200
local BOT_STUCK_INTERVAL = 1.4
local BOT_STUCK_MIN_DISTANCE = 35
local BOT_STUCK_JUMP_ATTEMPTS = 3
local BOT_UNSTUCK_TIME = 1.1
local BOT_UNSTUCK_RETRY_TIME = 0.5
local BOT_OBSTACLE_TRACE_DISTANCE = 92
local BOT_OBSTACLE_SIDE_PROBE_DISTANCE = 72
local BOT_OBSTACLE_BACKOFF_DOT = -0.25
local BOT_DOOR_TRACE_DISTANCE = 130
local BOT_DOOR_USE_COOLDOWN = 0.75

-- Locomotion reliability tuning.
local BOT_STUCK_ABANDON_ATTEMPTS = 6
local BOT_FAILED_DEST_RETRY_TIME = 2.5
local NAV_TURN_SLOW_DOT = 0.45
local NAV_TRANSITION_JUMP_DISTANCE_SQR = 64 * 64
local NAV_SEPARATION_RANGE_SQR = 56 * 56
local NAV_CROUCH_ATTRIBUTE = NAV_MESH_CROUCH or 64
local NAV_JUMP_ATTRIBUTE = NAV_MESH_JUMP or 128

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

local hullTraceData = {
	mask = MASK_PLAYERSOLID,
	filter = {},
}

local doorTraceData = {
	mask = MASK_SOLID,
	filter = {},
}

local protectedTraceData = {
	mask = MASK_SHOT,
	filter = {},
}

local EMPTY_NAV_AREAS = {}
local cachedNavAreas
local cachedAreaCenters = {}
local nextNavCacheAttempt = 0

-- Navigation owns every path and obstacle cache field under state.navigation.
local function ClearNavPath(state)
	local nav = state.navigation
	nav.path = nil
	nav.pathIndex = nil
	nav.pathLookup = nil
	nav.pathGoal = nil
	nav.pathSafetyRefresh = nil
	nav.waypointProbePrimary = nil
	nav.waypointProbeSkip = nil
end

function ClearNavigationState(state)
	ClearNavPath(state)

	local nav = state.navigation
	nav.currentArea = nil
	nav.nextCurrentAreaUpdate = nil
	nav.goalArea = nil
	nav.goalNavPos = nil
	nav.nextGoalAreaUpdate = nil
	nav.roamArea = nil
	nav.nextRoamPick = 0
	nav.nextPathTime = 0
	nav.doorTarget = nil
	nav.doorUntil = nil
	nav.nextDoorProbe = 0
	nav.obstacleHit = false
	nav.obstacleNormal = nil
	nav.obstacleCacheUntil = nil
	nav.nextObstacleProbe = 0
	ClearDestinationMemory(state)
end

-- Failed-destination and give-up memory, cleared when the intent changes.
function ClearDestinationMemory(state)
	local nav = state.navigation
	nav.failedDestPos = nil
	nav.failedDestUntil = 0
	nav.giveUpDest = nil
	nav.giveUpUntil = 0
	nav.stuckStage = 0
end

local function SameDestination(a, b)
	return isvector(a) and isvector(b) and a:DistToSqr(b) < 200 * 200
end

local function RecordFailedDestination(nav, destPos)
	if not isvector(destPos) then return end
	if nav.giveUpDest and SameDestination(nav.giveUpDest, destPos) then return end

	nav.failedDestPos = Vector(destPos.x, destPos.y, destPos.z)
	nav.failedDestUntil = CurTime() + BOT_FAILED_DEST_RETRY_TIME
end

function InvalidateCaches()
	cachedNavAreas = nil
	cachedAreaCenters = {}
	nextNavCacheAttempt = 0

	if not player or not player.GetAll then return end
	for _, bot in ipairs(player.GetAll()) do
		if IsValid(bot) and bot.IsBot and bot:IsBot() and bot.ZCBotAI then
			ClearNavigationState(bot.ZCBotAI)
		end
	end
end

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

local function GetCachedAreaCenter(area)
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

function GetAreaWaypoint(area)
	if not IsValid(area) then return vector_origin end
	return GetCachedAreaCenter(area)
end

function PickRandomRoamArea(bot, areaFilter)
	local state = GetOrCreateState(bot)
	local nav = state.navigation
	local now = CurTime()

	if (nav.nextRoamPick or 0) > now then
		if IsValid(nav.roamArea) and (not areaFilter or areaFilter(nav.roamArea)) then return nav.roamArea end
		if nav.roamArea == nil then return nil end
	end

	local areas = GetCachedBotNavAreas()
	if not areas or #areas == 0 then return nil end

	local currentArea = GetNearestBotNavArea(bot:GetPos())
	if IsValid(currentArea) then
		nav.currentArea = currentArea
		nav.nextCurrentAreaUpdate = CurTime() + NAV_CURRENT_AREA_REFRESH
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

	nav.roamArea = bestArea
	nav.nextRoamPick = now + (IsValid(bestArea) and BOT_ROAM_INTERVAL + math_Rand(0, 2) or 0.75)
	if IsValid(bestArea) then
		BotDevPrint("%s roam", bot:Name())
	end

	return bestArea
end

local function ReconstructAreaPath(cameFrom, current)
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

local function BuildAreaPath(startArea, goalArea)
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

function TryBotTravelSprint(bot, cmd, destPos)
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

local function IsDoorSelectable(nav, ent)
	return IsBotUsableDoor(ent) and not (nav.blockedDoor == ent and (nav.blockedDoorUntil or 0) > CurTime())
end

local function TraceBotDoorAhead(bot, moveDir, tr, now)
	now = now or CurTime()
	local nav = bot.ZCBotAI.navigation

	if tr and IsDoorSelectable(nav, tr.Entity) then
		nav.doorTarget = tr.Entity
		nav.doorUntil = now + DOOR_CACHE_LIFETIME
		return tr.Entity
	end

	local lastDir = nav.doorProbeDir
	local directionChanged = not lastDir or lastDir:Dot(moveDir) < OBSTACLE_DIRECTION_DOT
	if not directionChanged and (nav.nextDoorProbe or 0) > now then
		local cachedDoor = nav.doorTarget
		if (nav.doorUntil or 0) > now and IsBotUsableDoor(cachedDoor) then return cachedDoor end
		return
	end

	nav.nextDoorProbe = now + DOOR_PROBE_INTERVAL + bot:EntIndex() % 4 * 0.01
	nav.doorProbeDir = Vector(moveDir.x, moveDir.y, moveDir.z)
	nav.doorTarget = nil
	nav.doorUntil = nil

	doorTraceData.filter[1] = bot
	doorTraceData.filter[2] = bot.FakeRagdoll
	local botPos = bot:GetPos()

	for _, offset in ipairs(DOOR_TRACE_OFFSETS) do
		doorTraceData.start = botPos + offset
		doorTraceData.endpos = doorTraceData.start + moveDir * BOT_DOOR_TRACE_DISTANCE

		local doorTr = util.TraceLine(doorTraceData)
		if IsDoorSelectable(nav, doorTr.Entity) then
			nav.doorTarget = doorTr.Entity
			nav.doorUntil = now + DOOR_CACHE_LIFETIME
			return doorTr.Entity
		end
	end
end

local function TryBotOpenDoor(bot, cmd, door)
	if not IsBotClosedDoor(door) then return false end

	local nav = bot.ZCBotAI.navigation
	if nav.blockedDoor == door and (nav.blockedDoorUntil or 0) > CurTime() then
		-- Repeated failed uses: treat the door as a wall for a while.
		return false
	end

	local toDoor = door:LocalToWorld(door:OBBCenter()) - bot:EyePos()
	if toDoor:Length() > BOT_DOOR_TRACE_DISTANCE * 1.2 then return false end

	-- Press use only when actually facing the door; turn toward it first.
	toDoor.z = 0
	if toDoor:LengthSqr() > 1 then
		toDoor:Normalize()
		local forward = Angle(0, cmd:GetViewAngles().y, 0):Forward()
		if forward:Dot(toDoor) < 0.55 then
			SetBotViewAngles(bot, cmd, toDoor:Angle(), 0.4)
			cmd:SetForwardMove(math_min(cmd:GetForwardMove(), 90))
			cmd:SetSideMove(0)
			return true
		end
	end

	if nav.doorUseTarget == door and (nav.nextDoorUse or 0) > CurTime() then
		-- Wait a short time for an opening door instead of declaring it blocked.
		cmd:SetForwardMove(math_min(math_max(cmd:GetForwardMove(), 80), 120))
		cmd:SetSideMove(0)
		return true
	end

	if nav.doorFailTarget ~= door then
		nav.doorFailTarget = door
		nav.doorFails = 0
	end

	nav.doorUseTarget = door
	nav.nextDoorUse = CurTime() + BOT_DOOR_USE_COOLDOWN
	nav.doorUsedAt = CurTime()

	local oldSpeed = door.GetInternalVariable and door:GetInternalVariable("Speed")
	if oldSpeed and door.SetSaveValue then door:SetSaveValue("Speed", 1000) end
	door:Use(bot)
	if oldSpeed and door.SetSaveValue then door:SetSaveValue("Speed", oldSpeed) end

	BotDevPrint("%s opened door %s", bot:Name(), door:GetClass())
	return true
end

-- A door that was used but stays closed after a grace window counts as a
-- failure; after several it is blacklisted briefly and the route rebuilds.
local function UpdateDoorBlockState(bot)
	local now = CurTime()
	local nav = bot.ZCBotAI.navigation
	local door = nav.doorUseTarget
	if not IsValid(door) or not nav.doorUsedAt then return end
	if nav.blockedDoor == door and (nav.blockedDoorUntil or 0) > now then return end

	if now - nav.doorUsedAt > 1.2 and IsBotUsableDoor(door) and IsBotClosedDoor(door) then
		nav.doorFails = (nav.doorFails or 0) + 1
		nav.doorUsedAt = nil

		if nav.doorFails >= 4 then
			nav.blockedDoor = door
			nav.blockedDoorUntil = now + 4
			nav.doorUseTarget = nil
			nav.doorFails = 0
			ClearNavPath(bot.ZCBotAI)
			nav.nextPathTime = 0
		end
	end
end

local function GetBotMovementHull(bot)
	local crouching = bot:Crouching()
	local mins, maxs
	if crouching and bot.GetHullDuck then
		mins, maxs = bot:GetHullDuck()
	end
	if not mins or not maxs then
		mins, maxs = bot:GetHull()
	end

	local model = bot.GetModel and bot:GetModel() or ""
	local nav = bot.ZCBotAI.navigation
	local changed = nav.hullCrouching ~= crouching or nav.hullModel ~= model
		or nav.hullMinX ~= mins.x or nav.hullMinY ~= mins.y or nav.hullMinZ ~= mins.z
		or nav.hullMaxX ~= maxs.x or nav.hullMaxY ~= maxs.y or nav.hullMaxZ ~= maxs.z

	if changed then
		nav.hullCrouching = crouching
		nav.hullModel = model
		nav.hullMinX = mins.x
		nav.hullMinY = mins.y
		nav.hullMinZ = mins.z
		nav.hullMaxX = maxs.x
		nav.hullMaxY = maxs.y
		nav.hullMaxZ = maxs.z
		nav.hullRevision = (nav.hullRevision or 0) + 1
	end

	return mins, maxs, nav.hullRevision or 0
end

local function GetShrunkBotMovementHull(mins, maxs)
	local shrunkMins = mins + TRACE_HULL_SHRINK_MINS
	local shrunkMaxs = maxs - TRACE_HULL_SHRINK_MAXS
	if shrunkMins.x >= shrunkMaxs.x or shrunkMins.y >= shrunkMaxs.y or shrunkMins.z >= shrunkMaxs.z then
		return mins, maxs
	end
	return shrunkMins, shrunkMaxs
end

local function TraceBotMoveDir(bot, moveDir, distance, shrinkHull, mins, maxs)
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

local function IsBotMoveDirClear(bot, moveDir, distance, mins, maxs)
	local tr = TraceBotMoveDir(bot, moveDir, distance, true, mins, maxs)
	return not tr.Hit or tr.Fraction > 0.82
end

local function ApplyCachedObstacleResponse(bot, cmd, moveAng, forwardMove)
	local nav = bot.ZCBotAI.navigation
	local normal = nav.obstacleNormal
	if not normal then return false end

	local preferredSide = nav.obstaclePreferredSide or 1
	local side = nav.obstacleSide or preferredSide
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
	local nav = bot.ZCBotAI.navigation
	if (nav.unstuckUntil or 0) > now then return false end

	UpdateDoorBlockState(bot)

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
	local lastDir = nav.obstacleProbeDir
	local lastPos = nav.obstacleProbePos
	local directionChanged = not lastDir or lastDir:Dot(moveDir) < OBSTACLE_DIRECTION_DOT
	local movedFar = not lastPos or lastPos:DistToSqr(botPos) >= OBSTACLE_PROBE_MOVE_SQR
	local shouldProbe = directionChanged or movedFar or nav.obstacleHullRevision ~= hullRevision
		or (nav.nextObstacleProbe or 0) <= now
	local tr

	if shouldProbe then
		nav.nextObstacleProbe = now + OBSTACLE_PROBE_INTERVAL
		nav.obstacleProbeDir = Vector(moveDir.x, moveDir.y, moveDir.z)
		nav.obstacleProbePos = Vector(botPos.x, botPos.y, botPos.z)
		nav.obstacleHullRevision = hullRevision
		tr = TraceBotMoveDir(bot, moveDir, BOT_OBSTACLE_TRACE_DISTANCE, true, mins, maxs)

		if not tr.Hit then
			nav.obstacleHit = false
			nav.obstacleNormal = nil
			nav.obstacleCacheUntil = now + OBSTACLE_CACHE_LIFETIME
			return false
		end
	end

	local door
	if shouldProbe then
		door = TraceBotDoorAhead(bot, moveDir, tr, now)
	elseif (nav.doorUntil or 0) > now and IsBotUsableDoor(nav.doorTarget) then
		door = nav.doorTarget
	end

	if TryBotOpenDoor(bot, cmd, door) then
		nav.obstacleHit = false
		nav.obstacleNormal = nil
		return true
	end

	if not shouldProbe then
		if nav.obstacleHit and (nav.obstacleCacheUntil or 0) > now
			and nav.obstacleHullRevision == hullRevision then
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

	nav.lastObstacleNormal = tr.HitNormal
	nav.lastObstacleSide = side ~= 0 and side or preferredSide
	nav.lastObstacleAt = now
	nav.obstacleHit = true
	nav.obstacleNormal = tr.HitNormal
	nav.obstaclePreferredSide = preferredSide
	nav.obstacleSide = side
	nav.obstacleCacheUntil = now + OBSTACLE_CACHE_LIFETIME

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
	local nav = bot.ZCBotAI.navigation
	local field = skipProbe and "waypointProbeSkip" or "waypointProbePrimary"
	local cached = nav[field]
	local botPos = bot:GetPos()
	if cached and cached.nextProbe > now and cached.hullRevision == hullRevision
		and cached.origin:DistToSqr(botPos) < WAYPOINT_PROBE_MOVE_SQR
		and cached.target:DistToSqr(pos) < WAYPOINT_PROBE_TARGET_SQR then
		return cached.clear
	end

	local clear = HasClearMoveLine(bot, pos, mins, maxs)
	if not cached then
		cached = {}
		nav[field] = cached
	end

	cached.nextProbe = now + WAYPOINT_PROBE_INTERVAL
	cached.hullRevision = hullRevision
	cached.origin = Vector(botPos.x, botPos.y, botPos.z)
	cached.target = Vector(pos.x, pos.y, pos.z)
	cached.clear = clear
	return clear
end

function ApplyBotUnstuckMove(bot, cmd)
	local nav = bot.ZCBotAI.navigation
	if (nav.unstuckUntil or 0) <= CurTime() then return false end

	cmd:SetForwardMove(nav.unstuckForward or -180)
	cmd:SetSideMove((nav.unstuckSide or 1) * 260)

	if nav.unstuckShouldJump and (nav.nextJump or 0) < CurTime() then
		nav.nextJump = CurTime() + 0.65
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_JUMP))
	end

	if nav.unstuckDuck then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_DUCK))
	end

	return true
end

function UpdateBotStuckState(bot, cmd, movePos)
	local nav = bot.ZCBotAI.navigation
	if (nav.nextStuckCheck or 0) > CurTime() then return end
	if math_abs(cmd:GetForwardMove()) < 80 and math_abs(cmd:GetSideMove()) < 80 then return end
	if not bot:IsOnGround() then return end

	local pos = bot:GetPos()
	local oldPos = nav.lastStuckPos
	nav.lastStuckPos = pos
	nav.nextStuckCheck = CurTime() + BOT_STUCK_INTERVAL

	if not oldPos then return end

	local moved = oldPos:Distance(pos)
	if moved >= BOT_STUCK_MIN_DISTANCE then
		nav.stuckAttempts = 0
		nav.stuckStage = 0
		return
	end

	nav.stuckAttempts = (nav.stuckAttempts or 0) + 1
	nav.stuckStage = math_min(nav.stuckAttempts, 4)

	ClearNavPath(bot.ZCBotAI)
	nav.nextPathTime = 0
	nav.roamArea = nil
	nav.nextRoamPick = 0
	nav.unstuckUntil = CurTime() + BOT_UNSTUCK_TIME
	nav.nextStuckCheck = CurTime() + BOT_UNSTUCK_RETRY_TIME
	local recentObstacle = (nav.lastObstacleAt or 0) + 2 > CurTime()
	nav.unstuckSide = recentObstacle and (nav.lastObstacleSide or 1) or (math_random(0, 1) == 1 and 1 or -1)
	nav.unstuckForward = recentObstacle and -220 or (math_random(0, 1) == 1 and -220 or 120)
	nav.unstuckDuck = math_random(0, 2) == 0
	nav.unstuckShouldJump = (nav.stuckAttempts or 0) >= BOT_STUCK_JUMP_ATTEMPTS

	-- Repeated failures abandon the destination for the current intent.
	if nav.stuckAttempts >= BOT_STUCK_ABANDON_ATTEMPTS and isvector(nav.lastMoveDest) then
		nav.giveUpDest = Vector(nav.lastMoveDest.x, nav.lastMoveDest.y, nav.lastMoveDest.z)
		nav.giveUpUntil = CurTime() + BOT_FAILED_DEST_RETRY_TIME * 1.5
	end

	ApplyBotUnstuckMove(bot, cmd)
end

hook.Remove("InitPostEntity", "ZC_PlayerBotCenterGoalNavCache")
hook.Remove("PostCleanupMap", "ZC_PlayerBotCenterGoalNavCache")
hook.Add("InitPostEntity", "ZC_PlayerBotInvalidateNavAreaCache", InvalidateCaches)
hook.Add("PostCleanupMap", "ZC_PlayerBotInvalidateNavAreaCache", InvalidateCaches)

local function AreaContainsPosition(area, pos)
	if not IsValid(area) or not area.Contains or not area:Contains(pos) then return false end
	local navZ = area.GetZ and area:GetZ(pos)
	if navZ and math_abs(navZ - pos.z) > NAV_AREA_VERTICAL_TOLERANCE then return false end
	return true
end

local function FindPathAreaAtPosition(path, index, pos)
	if not path or #path == 0 then return end

	local first = math_max(1, index - NAV_AREA_SEARCH_BEHIND)
	local last = math_min(#path, index + NAV_AREA_SEARCH_AHEAD)
	for i = first, last do
		local area = path[i]
		if AreaContainsPosition(area, pos) then return area end
	end
end

local function SetBotCurrentNavArea(state, area, now)
	state.navigation.currentArea = area
	state.navigation.nextCurrentAreaUpdate = now + NAV_CURRENT_AREA_REFRESH
end

local function GetBotCurrentNavArea(state, pos, path, index, now, forceQuery, allowNearestQuery)
	local nav = state.navigation
	local area = nav.currentArea
	if AreaContainsPosition(area, pos) then return area, true, false end

	local pathArea = FindPathAreaAtPosition(path, index or 1, pos)
	if IsValid(pathArea) then
		SetBotCurrentNavArea(state, pathArea, now)
		return pathArea, true, false
	end

	if not forceQuery and (nav.nextCurrentAreaUpdate or 0) > now then return area, false, false end
	if not IsValid(area) and (nav.nextCurrentAreaUpdate or 0) > now then return area, false, false end
	if not allowNearestQuery then return area, false, false end

	area = GetNearestBotNavArea(pos)
	SetBotCurrentNavArea(state, area, now)
	return area, IsValid(area), true
end

local function GetBotGoalNavArea(state, destPos, now)
	local nav = state.navigation
	local area = nav.goalArea
	if AreaContainsPosition(area, destPos) then
		nav.goalNavPos = Vector(destPos.x, destPos.y, destPos.z)
		return area, false
	end

	local oldPos = nav.goalNavPos
	local movedFar = not oldPos or oldPos:DistToSqr(destPos) >= NAV_GOAL_REQUERY_DISTANCE_SQR
	if not movedFar and (nav.nextGoalAreaUpdate or 0) > now then
		return IsValid(area) and area or nil, false
	end

	local nearest = GetNearestBotNavArea(destPos)
	nav.nextGoalAreaUpdate = now + NAV_GOAL_AREA_REFRESH
	nav.goalNavPos = Vector(destPos.x, destPos.y, destPos.z)
	if IsValid(nearest) then
		nav.goalArea = nearest
		return nearest, true
	end

	nav.goalArea = nil
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
	local state = GetOrCreateState(bot)
	local nav = state.navigation
	local now = CurTime()
	local botPos = bot:GetPos()
	if botPos:DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return true, true
	end

	local goalArea, usedNearestQuery = GetBotGoalNavArea(state, destPos, now)
	if not IsValid(goalArea) then
		-- No navmesh route to this destination; cache the failure so the same
		-- impossible route is not retried every command.
		nav.noRouteStreak = (nav.noRouteStreak or 0) + 1
		if nav.noRouteStreak >= 3 then
			RecordFailedDestination(nav, destPos)
			nav.noRouteStreak = 0
		end
		return false
	end
	nav.noRouteStreak = 0

	local path = nav.path
	local index = nav.pathIndex or 1
	local pathInvalid = path ~= nil and not IsAreaPathValid(path, index)
	local pathLookup = nav.pathLookup
	if path and not pathLookup then
		pathLookup = BuildAreaPathLookup(path)
		nav.pathLookup = pathLookup
	end

	local currentArea, currentAreaFresh, queriedCurrentArea = GetBotCurrentNavArea(
		state,
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
			nav.pathIndex = index
		end
	end

	local goalChanged = path and nav.pathGoal ~= goalArea
	local safetyRefresh = path and (nav.pathSafetyRefresh or 0) <= now
	local needsPath = not path or pathInvalid or goalChanged or deviation or safetyRefresh
	if needsPath then
		if not path and (nav.nextPathTime or 0) > now then return false end

		if not currentAreaFresh or not IsValid(currentArea) then
			currentArea, currentAreaFresh, queriedCurrentArea = GetBotCurrentNavArea(
				state,
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
			nav.path = path
			nav.pathIndex = index
			nav.pathLookup = BuildAreaPathLookup(path)
			nav.pathGoal = goalArea
			nav.nextPathTime = now + BOT_NAV_REPATH_INTERVAL
			nav.pathSafetyRefresh = now + NAV_SAFETY_REPATH_INTERVAL + bot:EntIndex() % 8 * 0.11
			nav.waypointProbePrimary = nil
			nav.waypointProbeSkip = nil
		elseif safetyRefresh and not pathInvalid and not goalChanged and not deviation then
			-- Keep a still-valid route if only its periodic safety rebuild failed.
			nav.pathSafetyRefresh = now + NAV_SAFETY_REPATH_INTERVAL
		else
			ClearNavPath(state)
			nav.nextPathTime = now + BOT_NAV_REPATH_INTERVAL
			RecordFailedDestination(nav, destPos)
			return false
		end
	end

	if not path or #path == 0 then return false end

	while index < #path and botPos:DistToSqr(GetAreaWaypoint(path[index])) <= BOT_NAV_WAYPOINT_REACH * BOT_NAV_WAYPOINT_REACH do
		index = index + 1
	end

	nav.pathIndex = index

	local waypoint = index >= #path and destPos or GetAreaWaypoint(path[index])
	local nextArea = index < #path and path[index + 1] or nil
	local nextWp = IsValid(nextArea) and GetAreaWaypoint(nextArea) or nil
	local mins, maxs, hullRevision = GetBotMovementHull(bot)
	if not HasCachedClearMoveLine(bot, waypoint, false, now, hullRevision, mins, maxs) and index < #path then
		local nextIndex = index + 1
		local nextWaypoint = nextIndex >= #path and destPos or GetAreaWaypoint(path[nextIndex])

		if HasCachedClearMoveLine(bot, nextWaypoint, true, now, hullRevision, mins, maxs) then
			index = nextIndex
			nav.pathIndex = index
			waypoint = nextWaypoint
		end
	end

	if faceWaypoint then
		aimAng = (waypoint - bot:EyePos()):Angle()
		-- Do not stare at the ground or ceiling on vertical route legs.
		aimAng.p = math_Clamp(aimAng.p, -35, 35)
		aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)
	end

	-- Slow down before sharp turns instead of overshooting and reversing.
	local moveSpeed = runSpeed
	if nextArea and nextWp then
		local legDir = waypoint - botPos
		legDir.z = 0
		local turnDir = nextWp - waypoint
		turnDir.z = 0
		if legDir:LengthSqr() > 1 and turnDir:LengthSqr() > 1
			and legDir:GetNormalized():Dot(turnDir:GetNormalized()) < NAV_TURN_SLOW_DOT then
			moveSpeed = math_min(moveSpeed, 180)
		end
	end

	SetBotMovementToward(bot, cmd, waypoint, aimAng, moveSpeed)

	-- Basic nav-area transitions: crouch through marked areas; jump only where
	-- the navmesh demands it (or unstuck recovery handles it instead).
	local currentAttrs = IsValid(currentArea) and currentArea.GetAttributes and currentArea:GetAttributes() or 0
	if bit.band(currentAttrs, NAV_CROUCH_ATTRIBUTE) ~= 0 then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_DUCK))
	end

	if bot:IsOnGround() then
		local wantJump = false
		if IsValid(nextArea) then
			local nextAttrs = nextArea.GetAttributes and nextArea:GetAttributes() or 0
			if bit.band(nextAttrs, NAV_JUMP_ATTRIBUTE) ~= 0
				and botPos:DistToSqr(GetAreaWaypoint(nextArea)) <= NAV_TRANSITION_JUMP_DISTANCE_SQR * 9 then
				wantJump = true
			elseif nextWp and botPos:DistToSqr(nextWp) <= NAV_TRANSITION_JUMP_DISTANCE_SQR then
				local rise = 0
				if IsValid(currentArea) and currentArea.ComputeAdjacentConnectionHeightChange then
					rise = currentArea:ComputeAdjacentConnectionHeightChange(nextArea) or 0
				end
				wantJump = rise > 48
			end
		end

		if wantJump and (nav.nextTransitionJump or 0) <= now then
			nav.nextTransitionJump = now + 0.6
			cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_JUMP))
		end
	end

	if allowSprint and moveSpeed == runSpeed then
		TryBotTravelSprint(bot, cmd, destPos)
	end

	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, waypoint)
	return true
end

-- Small local steering offset so several bots do not stand on the same
-- waypoint or mirror each other. Never changes the route destination.
local function ApplyLocalSeparation(bot, cmd, aimAng, destPos)
	local now = CurTime()
	local nav = GetOrCreateState(bot).navigation
	if (nav.nextSeparation or 0) > now then return end
	nav.nextSeparation = now + 0.12 + bot:EntIndex() % 5 * 0.01

	if (nav.unstuckUntil or 0) > now then return end
	if IsValid(nav.doorUseTarget) and bot:GetPos():DistToSqr(nav.doorUseTarget:GetPos()) < 130 * 130 then return end
	if isvector(destPos) and bot:GetPos():DistToSqr(destPos) < 220 * 220 then return end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return end

	local botPos = bot:GetPos()
	local nearest, nearestDistSqr
	for _, other in ipairs(GetBotPlayerCandidates()) do
		if other == bot or not IsValid(other) or not other:Alive() then continue end
		local distSqr = botPos:DistToSqr(other:GetPos())
		if distSqr <= NAV_SEPARATION_RANGE_SQR and (not nearestDistSqr or distSqr < nearestDistSqr) then
			nearest, nearestDistSqr = other, distSqr
		end
	end
	if not nearest then return end

	local away = botPos - nearest:GetPos()
	away.z = 0
	if away:LengthSqr() <= 1 then return end
	away:Normalize()

	local moveAng = Angle(0, aimAng.y, 0)
	local sideDot = away:Dot(moveAng:Right())
	cmd:SetSideMove(sideMove + (sideDot >= 0 and 1 or -1) * 140)
end

-- Navigation accepts one destination and reports a small result.
-- options: { aimAng = Angle, facePath = bool (default true), speed = number (default 400), allowSprint = bool }
function MoveTo(bot, cmd, destPos, options)
	options = options or {}

	local state = GetOrCreateState(bot)
	local nav = state.navigation
	local now = CurTime()

	nav.lastMoveDest = isvector(destPos) and Vector(destPos.x, destPos.y, destPos.z) or nil

	-- Give-up memory: stop pursuing a destination that repeatedly failed.
	if (nav.giveUpUntil or 0) > now and SameDestination(nav.giveUpDest, destPos) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return false, false
	end

	-- Failed-route cache: do not retry an impossible route every command.
	if (nav.failedDestUntil or 0) > now and SameDestination(nav.failedDestPos, destPos) then
		cmd:SetForwardMove(0)
		cmd:SetSideMove(0)
		return false, false
	end

	local aimAng = options.aimAng or (destPos - bot:EyePos()):Angle()
	local facePath = options.facePath ~= false
	local speed = options.speed or 400
	local allowSprint = options.allowSprint == true

	local moving, reached = FollowBotPath(bot, cmd, destPos, aimAng, speed, facePath, allowSprint)
	if reached then return true, true end
	if moving then
		ApplyLocalSeparation(bot, cmd, aimAng, destPos)
		return true, false
	end

	-- No navmesh route available: fall back to direct movement and obstacle handling.
	if facePath then
		aimAng = SetBotViewAngles(bot, cmd, aimAng, BOT_AIM_SMOOTH_TRAVEL)
	end

	SetBotMovementToward(bot, cmd, destPos, aimAng, math.min(speed, 360))
	if allowSprint then
		TryBotTravelSprint(bot, cmd, destPos)
	end
	ApplyBotUnstuckMove(bot, cmd)
	ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	UpdateBotStuckState(bot, cmd, destPos)
	ApplyLocalSeparation(bot, cmd, aimAng, destPos)

	return true, false
end

function HoldAndScan(bot, cmd)
	cmd:SetForwardMove(0)
	cmd:SetSideMove(0)

	local state = GetOrCreateState(bot)
	local combat = state.combat
	if (combat.scanTurnNext or 0) <= CurTime() then
		combat.scanTurnNext = CurTime() + math.Rand(1.1, 1.8)
		combat.scanYaw = bot:EyeAngles().y + math.Rand(75, 135) * (math.random(0, 1) == 1 and 1 or -1)
	end

	local scanAng = Angle(0, combat.scanYaw or bot:EyeAngles().y, 0)
	return SetBotViewAngles(bot, cmd, scanAng, BOT_AIM_SMOOTH_TRAVEL)
end

-- Bounded nearby search for a protected position: sample a fixed number of
-- nav-area centers near the bot and prefer one that breaks line of sight from
-- the threat. The result (including "none found") is cached briefly.
function FindProtectedPosition(bot, threatPos)
	if not isvector(threatPos) then return nil end

	local nav = GetOrCreateState(bot).navigation
	local now = CurTime()
	if isvector(nav.protectedPos) and (nav.protectedUntil or 0) > now then
		return nav.protectedPos
	end

	nav.protectedUntil = now + 1.5
	nav.protectedPos = nil

	local areas = GetCachedBotNavAreas()
	if not areas or #areas == 0 then return nil end

	local botPos = bot:GetPos()
	local bestScore
	local bestPos
	local samples = 0
	local stride = math_max(1, math.floor(#areas / 12))

	for index = 1, #areas, stride do
		samples = samples + 1
		if samples > 12 then break end

		local area = areas[index]
		if not IsValid(area) then continue end

		local pos = GetCachedAreaCenter(area)
		local distSqr = botPos:DistToSqr(pos)
		if distSqr > 900 * 900 or distSqr < 96 * 96 then continue end
		-- Mode-invalid positions (e.g. outside the Deathmatch zone) are rejected.
		if AdjustBotGoal(bot, pos):DistToSqr(pos) > 100 then continue end

		protectedTraceData.start = threatPos + Vector(0, 0, 20)
		protectedTraceData.endpos = pos + TRACE_LINE_OFFSET
		protectedTraceData.filter[1] = bot
		protectedTraceData.filter[2] = bot.FakeRagdoll

		local score = util.TraceLine(protectedTraceData).Hit and 0 or 500000
		score = score + distSqr
		if not bestScore or score < bestScore then
			bestScore = score
			bestPos = pos
		end
	end

	if bestPos then
		nav.protectedPos = Vector(bestPos.x, bestPos.y, bestPos.z)
	end

	return nav.protectedPos
end

function Roam(bot, cmd, adjustGoal)
	local state = GetOrCreateState(bot)
	local nav = state.navigation

	local function pickArea()
		return PickRandomRoamArea(bot, nil)
	end

	local area = pickArea()
	if not IsValid(area) then
		HoldAndScan(bot, cmd)
		return
	end

	local destPos = GetAreaWaypoint(area)
	if bot:GetPos():DistToSqr(destPos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		nav.roamArea = nil
		nav.nextRoamPick = 0
		ClearNavPath(state)

		area = pickArea()
		if not IsValid(area) then
			HoldAndScan(bot, cmd)
			return
		end
		destPos = GetAreaWaypoint(area)
	end

	if adjustGoal then
		destPos = adjustGoal(bot, destPos) or destPos
	end

	MoveTo(bot, cmd, destPos, {speed = 390, facePath = true, allowSprint = true})
end
