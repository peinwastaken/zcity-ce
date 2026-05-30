hg = hg or {}
hg.PlayerBots = hg.PlayerBots or {}
local _ENV = hg.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

function GetNearestBotNavArea(pos)
	if not navmesh or not navmesh.GetNearestNavArea then return nil end

	local area = navmesh.GetNearestNavArea(pos, false, 1200, false, false)
	if IsValid(area) then return area end

	area = navmesh.GetNearestNavArea(pos, true, 1200, false, false)
	if IsValid(area) then return area end
end

function PickRandomRoamArea(bot)
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

function ReconstructAreaPath(cameFrom, current)
	local path = {current}

	while cameFrom[current] do
		current = cameFrom[current]
		table.insert(path, 1, current)
	end

	return path
end

function BuildAreaPath(startArea, goalArea)
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

function GetAreaWaypoint(area)
	if not IsValid(area) then return vector_origin end
	return area:GetCenter()
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

function TraceBotDoorAhead(bot, moveDir, tr)
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

	BotDevPrint(string.format("%s opened door %s", bot:Name(), door:GetClass()))
	return true
end

function TraceBotMoveDir(bot, moveDir, distance, shrinkHull)
	local mins, maxs = bot:GetHull()
	hullTraceData.start = bot:GetPos() + Vector(0, 0, 18)
	hullTraceData.endpos = hullTraceData.start + moveDir * distance

	if shrinkHull then
		hullTraceData.mins = mins + Vector(3, 3, 4)
		hullTraceData.maxs = maxs - Vector(3, 3, 18)
	else
		hullTraceData.mins = mins
		hullTraceData.maxs = maxs
	end

	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	return util.TraceHull(hullTraceData)
end

function IsBotMoveDirClear(bot, moveDir, distance)
	local tr = TraceBotMoveDir(bot, moveDir, distance, true)
	return not tr.Hit or tr.Fraction > 0.82
end

function ApplyBotObstacleAvoidance(bot, cmd, aimAng)
	if (bot.ZCBotUnstuckUntil or 0) > CurTime() then return false end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math_abs(forwardMove) < 40 and math_abs(sideMove) < 40 then return false end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return false end

	moveDir:Normalize()
	local tr = TraceBotMoveDir(bot, moveDir, BOT_OBSTACLE_TRACE_DISTANCE, true)
	local door = TraceBotDoorAhead(bot, moveDir, tr)
	if TryBotOpenDoor(bot, cmd, door) then return true end

	if not tr.Hit then return false end

	local forward = moveAng:Forward()
	local right = moveAng:Right()
	local rightDot = tr.HitNormal:Dot(right)
	local preferredSide = rightDot > 0 and 1 or -1
	local leftClear = IsBotMoveDirClear(bot, -right, BOT_OBSTACLE_SIDE_PROBE_DISTANCE)
	local rightClear = IsBotMoveDirClear(bot, right, BOT_OBSTACLE_SIDE_PROBE_DISTANCE)
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
	bot.ZCBotLastObstacleAt = CurTime()

	if side == 0 or tr.HitNormal:Dot(forward) <= BOT_OBSTACLE_BACKOFF_DOT then
		cmd:SetForwardMove(-120)
		cmd:SetSideMove(preferredSide * 260)
	else
		cmd:SetForwardMove(math_min(forwardMove, 120))
		cmd:SetSideMove(side * 300)
	end

	return true
end

function HasClearMoveLine(bot, pos)
	local mins, maxs = bot:GetHull()
	hullTraceData.start = bot:GetPos() + Vector(0, 0, 8)
	hullTraceData.endpos = pos + Vector(0, 0, 8)
	hullTraceData.mins = mins
	hullTraceData.maxs = maxs
	hullTraceData.filter[1] = bot
	hullTraceData.filter[2] = bot.FakeRagdoll

	return not util.TraceHull(hullTraceData).Hit
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

	bot.ZCBotPath = nil
	bot.ZCBotPathIndex = nil
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

	if bot.ZCBotUnstuckShouldJump and (bot.ZCBotNextJump or 0) < CurTime() then
		bot.ZCBotNextJump = CurTime() + 1
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_JUMP))
	end
end

function FollowBotPath(bot, cmd, destPos, aimAng, runSpeed, faceWaypoint, allowSprint)
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
		local nextIndex = index + 1
		local nextWaypoint = nextIndex >= #path and destPos or GetAreaWaypoint(path[nextIndex])

		if HasClearMoveLine(bot, nextWaypoint) then
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

