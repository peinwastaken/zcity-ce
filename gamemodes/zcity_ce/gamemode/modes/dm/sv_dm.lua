local MODE = MODE

local zc_deathmatch_nozone = ConVarExists("zc_deathmatch_nozone") and GetConVar("zc_deathmatch_nozone") or CreateConVar("zc_deathmatch_nozone", 0, FCVAR_REPLICATED, "Allows to disable deathmatch mode zone.", 0, 1)

-- MODE.MapSize = mapsize

util.AddNetworkString("ZC_DeathmatchStart")
util.AddNetworkString("ZC_DeathmatchEnd")

function MODE:CanLaunch()
    return true//(zc.GetWorldSize() >= ZBATTLE_BIGMAP)
end

function MODE:Prepare(round)
	game.CleanUpMap()

	local poses = {}
	for _, ply in player.Iterator() do
		if ply:Team() == TEAM_SPECTATOR then
			continue
		end

		ApplyAppearance(ply)
		ply:SetupTeam(0)
		table.insert(poses, ply:GetPos())
	end

	local centerpoint = Vector(0, 0, 0)
	for _, pos in ipairs(poses) do
		centerpoint:Add(pos)
	end
	centerpoint:Div(#poses)

	local dist = 0
	for _, pos in ipairs(poses) do
		local dist2 = pos:Distance(centerpoint)
		if dist < dist2 then
			dist = dist2
		end
	end

	zonepoint = centerpoint
	zonedistance = dist

	net.Start("ZC_DeathmatchStart")
		net.WriteVector(zonepoint)
		net.WriteFloat(zonedistance)
	net.Broadcast()

	self:GiveEquipment(round)
end

function MODE:CheckAlivePlayers()
	local AlivePlyTbl = {
	}
	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		if ply.organism and ply.organism.incapacitated then continue end
		AlivePlyTbl[#AlivePlyTbl + 1] = ply
	end
	return AlivePlyTbl
end

function MODE:CheckEnd(round)
	local alive = self:CheckAlivePlayers()

	if #alive <= 1 then
		return {
			reason = "last_alive",
			winner = alive[1]
		}
	end
end

local loadouts = {
	{primary = "weapon_glock17", attachments = {{"supressor4"},{"holo16","laser3"},{"holo15","laser1"},""}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_cz75", attachments = {{"supressor4"},{"supressor4"},""}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_deagle", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_ar15", attachments = {{"holo1","grip1","supressor2"},{"holo5","grip3","supressor2"},{"laser4","grip2"},{"laser4","supressor2"}}, armor = {"vest4","helmet1"}, ammo = 3},
	{primary = "weapon_sr25", attachments = {{"holo1","laser2"},{"optic2"},{"holo8","supressor7"},{"holo5","supressor7"}}, armor = {"vest1","helmet1","nightvision1"}, ammo = 3},
	{primary = "weapon_ptrd", attachments = "", armor = {}, ammo = 12},
	{primary = "weapon_mp7", attachments = {{"holo1","supressor2"},{"holo5","supressor2"},{"laser4","supressor2"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_p90", attachments = {{"holo15","supressor4"},{"laser1","supressor4"},{"holo14","supressor4"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_doublebarrel_short", attachments = "", armor = {"vest3","helmet1","mask1"}, ammo = 6},
	{primary = "weapon_akm", attachments = {{"holo6","supressor1"},{"holo4","laser1"},{"supressor1"}}, armor = {"vest1","helmet1","nightvision1"}, ammo = 3},
	{primary = "weapon_remington870", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_m4a1", attachments = {{"holo1","grip1","supressor2"},{"holo5","grip3","supressor2"},{"laser4","grip2"},{"laser4","supressor2"}}, armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_mac11", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_mp5", attachments = {{"supressor4"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_m590a1", attachments = "", armor = {"vest4","helmet1","mask1"}, ammo = 3},
	{primary = "weapon_draco", attachments = "", armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_uzi", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_tmp", attachments = {{"optic8"},{"holo3"},{"holo4"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_xm1014", attachments = "", armor = {"vest3","helmet1","mask1"}, ammo = 3},
	{primary = "weapon_saiga12", attachments = "", armor = {"vest3","helmet1","mask1"}, ammo = 4},
	{primary = "weapon_svd", attachments = {{"holo13"},{"holo6"},{"holo2"}}, armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_spas12", attachments = {{"supressor5"}}, armor = {"vest3","helmet1","mask1"}, ammo = 3},
	{primary = "weapon_hk416", attachments = {{"holo1","grip1","supressor2"},{"holo5","grip3","supressor2"},{"laser4","grip2"},{"laser4","supressor2"}}, armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_akmwreked", attachments = "", armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_hk_usp", attachments = {{"supressor3"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_glock18c", attachments = {{"mag1","holo16"}}, armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_skorpion", attachments = "", armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_tec9", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_sg552", attachments = {{"optic8"},{"holo3"},{"holo4"}}, armor = {"vest4","helmet1"}, ammo = 3},
	{primary = "weapon_vector", attachments = {{"supressor4","holo3"},{"holo4"},{"holo7"}}, armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_revolver2", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_revolver357", attachments = "", armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_pkm", attachments = "", armor = {"vest1","helmet1"}, ammo = 0},
	{primary = "weapon_ak74", attachments = {{"holo6"},{"holo4"},{"optic8"}}, armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_ak74u", attachments = {{"holo6"},{"holo4"}}, armor = {"vest1","helmet1"}, ammo = 3},
	{primary = "weapon_winchester", attachments = "", armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_sks", attachments = {{"optic8"},{"holo6"}}, armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_ruger", attachments = "", armor = {"vest3","helmet1"}, ammo = 5},
	{primary = "weapon_mini14", attachments = {{"optic8"},{"holo6"}}, armor = {"vest3","helmet1"}, ammo = 4},
	{primary = "weapon_ac556", attachments = {{"holo6"},{"holo4"}}, armor = {"vest3","helmet1"}, ammo = 3},
	{primary = "weapon_ar15", secondary = "weapon_cz75", attachments = {{"holo1","grip1"},{"holo5","grip3"}}, armor = {"vest3","helmet1"}, ammo = 3, ammo2 = 2},
	{primary = "weapon_akm", secondary = "weapon_px4beretta", attachments = {{"holo6"},{"holo4"}}, armor = {"vest3","helmet1"}, ammo = 3, ammo2 = 2},
	{primary = "weapon_m4a1", secondary = "weapon_p22", attachments = {{"holo1","grip1"},{"holo5","grip3"}}, armor = {"vest3","helmet1"}, ammo = 3, ammo2 = 2},
	{primary = "weapon_mp5", secondary = "weapon_revolver2", attachments = {{"supressor4"}}, armor = {"vest3","helmet1"}, ammo = 3, ammo2 = 2},
	{primary = "weapon_sks", secondary = "weapon_flintlock", attachments = "", armor = {"vest3","helmet1"}, ammo = 4, ammo2 = 3},
	{primary = "weapon_winchester", secondary = "weapon_cz75", attachments = "", armor = {"vest3","helmet1"}, ammo = 4, ammo2 = 2},
	{primary = "weapon_mini14", secondary = "weapon_px4beretta", attachments = {{"holo6"}}, armor = {"vest3","helmet1"}, ammo = 3, ammo2 = 2},
	{primary = "weapon_hg_bow", attachments = "", armor = {"helmet1"}, ammo = 25, melee = "weapon_pocketknife", noGrenade = true, medicine = {"weapon_bandage_sh"}, medicineCount = 1},
	{primary = "weapon_hg_bow", attachments = "", armor = {"helmet7"}, ammo = 25, melee = "weapon_pocketknife", noGrenade = true, medicine = {"weapon_bigbandage_sh"}, medicineCount = 1},
	{primary = "weapon_musket", secondary = "weapon_flintlock", attachments = "", armor = {"vest2","helmet1"}, ammo = 10, ammo2 = 6, melee = "weapon_pocketknife", randomMedicine = true},
	{primary = "weapon_musket", secondary = "weapon_flintlock", attachments = "", armor = {"vest3"}, ammo = 12, ammo2 = 8, melee = "weapon_pocketknife", randomMedicine = true},
}

local randomGrenades = {"weapon_hg_rgd_tpik", "weapon_hg_pipebomb_tpik", "weapon_hg_smokenade_tpik", "weapon_hg_flashbang_tpik"}
local randomMedicine = {"weapon_bandage_sh", "weapon_bigbandage_sh", "weapon_medkit_sh", "weapon_fentanyl", "weapon_morphine", "weapon_adrenaline", "weapon_tourniquet"}
local randomMelees = {"weapon_melee", "weapon_pocketknife"}

local function MakeDissolver(ent, position, dissolveType)
    local Dissolver = ents.Create("env_entity_dissolver")
    timer.Simple(5, function()
        if IsValid(Dissolver) then Dissolver:Remove() end
    end)
	if !IsValid(Dissolver) then return end
    Dissolver.Target = "dissolve"..ent:EntIndex()
    Dissolver:SetKeyValue("dissolvetype", dissolveType)
    Dissolver:SetKeyValue("magnitude", 0)
    Dissolver:SetPos(position)
    Dissolver:SetPhysicsAttacker(ent)
    Dissolver:Spawn()
    ent:SetName(Dissolver.Target)
	ent:Fire("Open")
    Dissolver:Fire("Dissolve", Dissolver.Target, 0)
    Dissolver:Fire("Kill", "", 0.1)
    return Dissolver
end

function MODE:GiveEquipment(round)
	local loadout = loadouts[math.random(#loadouts)]
	local selectedAttachments = istable(loadout.attachments) and table.Random(loadout.attachments) or loadout.attachments

	for _, ply in player.Iterator() do
		if not ply:Alive() then continue end
		ply:SetSuppressPickupNotices(true)
		ply.noSound = true
		ply:Give("weapon_hands_sh")

		local inv = ply:GetNetVar("Inventory")
		inv["Weapons"]["hg_sling"] = true
		ply:SetNetVar("Inventory", inv)

		local gun = ply:Give(loadout.primary)
		if IsValid(gun) then
			ply:GiveAmmo(gun:GetMaxClip1() * loadout.ammo, gun:GetPrimaryAmmoType(), true)
			zc.AddAttachmentForce(ply, gun, selectedAttachments)
		end

		if loadout.secondary then
			local pistol = ply:Give(loadout.secondary)
			if IsValid(pistol) then
				ply:GiveAmmo(pistol:GetMaxClip1() * (loadout.ammo2 or 2), pistol:GetPrimaryAmmoType(), true)
			end
		end

		zc.AddArmor(ply, loadout.armor)
		ply:Give(loadout.melee or randomMelees[math.random(#randomMelees)])

		if not loadout.noGrenade then
			local grenadeCount = math.random(1, 2)
			local usedGrenades = {}
			for i = 1, grenadeCount do
				local grenade = randomGrenades[math.random(#randomGrenades)]
				while usedGrenades[grenade] and i > 1 do
					grenade = randomGrenades[math.random(#randomGrenades)]
				end
				usedGrenades[grenade] = true
				ply:Give(grenade)
			end
		end

		if loadout.medicine then
			for _ = 1, (loadout.medicineCount or 1) do
				ply:Give(loadout.medicine[math.random(#loadout.medicine)])
			end
		elseif loadout.randomMedicine then
			for _ = 1, math.random(1, 2) do
				ply:Give(randomMedicine[math.random(#randomMedicine)])
			end
		else
			ply:Give("weapon_bandage_sh")
			ply:Give("weapon_tourniquet")
		end

		ply:Give("weapon_walkie_talkie")
		ply:SelectWeapon("weapon_hands_sh")

		if ply.organism then ply.organism.recoilmul = 0.5 end

		timer.Simple(0.1, function()
			if IsValid(ply) then ply.noSound = false end
		end)
		ply:SetSuppressPickupNotices(false)
		zc.GiveRole(ply, "Fighter", Color(190,15,15))
	end
end

function MODE:Start(round)
end

MODE.Hooks = MODE.Hooks or {}

MODE.Hooks.PlayerDeath = function(self, round, ply)
	if round.state == ROUND_ACTIVE then
		ply:GiveSkill(-0.1)
	end
end

function MODE:Finish(round, result)
	local playersharm = {}
	for _, tbl in pairs(zc.HarmDone) do
		for attacker, harm in pairs(tbl) do
			playersharm[attacker] = (playersharm[attacker] or 0) + harm
		end
	end

	local most_violent_player
	local curharm = 0
	for ply, harm in pairs(playersharm) do
		if harm > curharm then
			most_violent_player = ply
			curharm = harm
		end
	end

	timer.Simple(2,function()
		net.Start("ZC_DeathmatchEnd")
		local ent = zc:CheckAlive(true)[1]

		if IsValid(ent) then
			ent:GiveExp(math.random(150,200))
			ent:GiveSkill(math.Rand(0.2,0.3))
		end

		if IsValid(most_violent_player) then
			most_violent_player:GiveExp(math.random(150,200))
			most_violent_player:GiveSkill(math.Rand(0.2,0.3))
		end

		net.WriteEntity(IsValid(ent) and ent:Alive() and ent or NULL)
		net.WriteEntity(IsValid(most_violent_player) and most_violent_player or NULL)
		net.Broadcast()
	end)
end

local cooldown = CurTime()
hook.Add("Think","ZC_DmModeThink",function(ply)
	local rnd = CurrentRound()
	if not rnd or (rnd.name != "dm" and rnd.base != "dm") then return end
	if (zc.ROUND_START or CurTime()) + 20 > CurTime() then return end
	if cooldown > CurTime() then return end
	if zc_deathmatch_nozone:GetBool() then return end
	cooldown = CurTime() + 0.5

	local pos = zonepoint
	local radius = MODE.GetZoneRadius()
	local radiussqr = radius * radius

	for _, ent in ents.Iterator() do
		if pos:DistToSqr(ent:GetPos()) > radiussqr then
			if ent:IsPlayer() then
				zc.LightStunPlayer(ent)

				continue
			end

			if hgIsDoor(ent) then
				if !ent:GetNoDraw() then
					hgBlastThatDoor(ent)
				end

				continue
			end

			if string.find(ent:GetClass(), "prop_") and !zc.expItems[ent:GetModel()] then
				MakeDissolver(ent, ent:GetPos(), 0)
			end
		end
	end
end)

-- Player bot integration ----------------------------------------------------
-- Deathmatch owns its zone behavior: different players are never teammates,
-- bots seek the zone center while it shrinks, and movement goals stay inside
-- the safe boundary. General AI only calls these optional methods.

local ZONE_ROAM_MARGIN = 600
local ZONE_CENTER_REACH = 500
local ZONE_CENTER_SETTLE_RADIUS = 650
local ZONE_CENTER_RESUME_RADIUS = 950
local ZONE_CENTER_BIAS_STEP = 32
local ZONE_CENTER_PATROL_RADIUS = 950
local ZONE_CENTER_PATROL_INTERVAL = 3
local ZONE_CENTER_SHRINK_FRACTION = 0.5
local ZONE_CENTER_GOAL_RADIUS = 700
local ZONE_CENTER_GOAL_INTERVAL = 4

-- Different players are opponents, even teams with the same Team() id.
function MODE:IsBotTeammate(bot, other)
	return false
end

function MODE:IsBotSafeTime()
	return self:IsSpawnProtectionActive()
end

local cachedZoneContext
local cachedZoneContextTick = -1
local cachedZoneContextRoundStart

local function GetZoneContext(mode)
	local tick = engine.TickCount()
	local roundStart = zc and zc.ROUND_START
	if cachedZoneContext and cachedZoneContextTick == tick and cachedZoneContextRoundStart == roundStart then
		return cachedZoneContext
	end

	local active = zc and zc.ROUND_STATE == 1
	local center
	local radius

	if active and not zc_deathmatch_nozone:GetBool() and isvector(zonepoint) then
		local currentRadius = mode.GetZoneRadius and mode.GetZoneRadius()
		if isnumber(currentRadius) and currentRadius > 0 and currentRadius < 1000000 then
			center = zonepoint
			radius = currentRadius
		end
	end

	local shrinkProgress = 0
	if active then
		local shrinkTime = mode.ZoneTimeToShrink
		if not isnumber(shrinkTime) or shrinkTime <= 0 then
			shrinkProgress = 1
		else
			shrinkProgress = math.Clamp((CurTime() - (roundStart or CurTime())) / shrinkTime, 0, 1)
		end
	end

	cachedZoneContext = {
		active = active,
		center = center,
		radius = radius,
		roundStart = roundStart,
		seekCenter = shrinkProgress >= ZONE_CENTER_SHRINK_FRACTION,
		shrinkProgress = shrinkProgress,
	}
	cachedZoneContextTick = tick
	cachedZoneContextRoundStart = roundStart

	return cachedZoneContext
end

local function IsPosInsideZone(ctx, pos, margin)
	if not ctx.center then return true end

	local insideRadius = math.max((ctx.radius or 0) - (margin or 0), 0)
	return ctx.center:DistToSqr(pos) < insideRadius * insideRadius
end

local centerGoalCandidates
local centerGoalCandidatesRefreshAt = 0
local centerGoalCandidatesMap = game.GetMap()

hook.Add("InitPostEntity", "ZC_DMCenterGoalCacheInit", function()
	centerGoalCandidates = nil
	centerGoalCandidatesRefreshAt = 0
	centerGoalCandidatesMap = game.GetMap()
end)

hook.Add("PostCleanupMap", "ZC_DMCenterGoalCacheCleanup", function()
	centerGoalCandidates = nil
	centerGoalCandidatesRefreshAt = 0
	centerGoalCandidatesMap = game.GetMap()
end)

local function GetCenterGoalCandidates(ctx)
	local center = ctx.center
	if not center or not navmesh or not navmesh.GetAllNavAreas then return {} end

	local mapName = game.GetMap()
	local now = CurTime()
	local cacheMatches = centerGoalCandidates and centerGoalCandidatesMap == mapName
		and centerGoalCandidates.roundStart == ctx.roundStart
		and centerGoalCandidates.centerX == center.x
		and centerGoalCandidates.centerY == center.y
		and centerGoalCandidates.centerZ == center.z

	if cacheMatches and centerGoalCandidatesRefreshAt > now then
		return centerGoalCandidates.candidates
	end

	local candidates = {}
	local goalRadiusSqr = ZONE_CENTER_GOAL_RADIUS * ZONE_CENTER_GOAL_RADIUS
	local areas = navmesh.GetAllNavAreas()
	for _, area in ipairs(areas or {}) do
		if not IsValid(area) then continue end

		local pos = area:GetCenter()
		local centerDistSqr = pos:DistToSqr(center)
		if centerDistSqr > goalRadiusSqr then continue end

		candidates[#candidates + 1] = {
			area = area,
			centerDistSqr = centerDistSqr,
			pos = pos
		}
	end

	centerGoalCandidates = {
		candidates = candidates,
		centerX = center.x,
		centerY = center.y,
		centerZ = center.z,
		roundStart = ctx.roundStart
	}
	centerGoalCandidatesMap = mapName
	-- Empty results are cached too, but retried sooner in case nav areas were not ready yet.
	centerGoalCandidatesRefreshAt = now + (#candidates > 0 and 30 or 1)

	return candidates
end

local function IsSameCenterContext(bot, ctx)
	local data = bot.ZCBotAI and bot.ZCBotAI.modes
	if not data then return false end

	local center = ctx.center
	return data.centerGoalRoundStart == ctx.roundStart
		and data.centerGoalX == center.x and data.centerGoalY == center.y and data.centerGoalZ == center.z
end

local function PickCenterGoal(bot, ctx, reachDistance)
	local center = ctx.center
	if not center then return end

	reachDistance = reachDistance or ZONE_CENTER_REACH
	local now = CurTime()
	local data = bot.ZCBotAI and bot.ZCBotAI.modes
	if isvector(data and data.centerGoalPos) and (data.nextCenterGoalPick or 0) > now
		and IsSameCenterContext(bot, ctx)
		and (not data.centerGoalFallback or IsPosInsideZone(ctx, data.centerGoalPos, ZONE_ROAM_MARGIN)) then
		return data.centerGoalPos
	end

	local bestArea
	local bestScore = math.huge
	local botPos = bot:GetPos()
	local reachDistanceSqr = reachDistance * reachDistance
	local zoneReach = math.max((ctx.radius or 0) - ZONE_ROAM_MARGIN, 0)
	local zoneReachSqr = zoneReach * zoneReach

	for _, candidate in ipairs(GetCenterGoalCandidates(ctx)) do
		local area = candidate.area
		if not IsValid(area) or candidate.centerDistSqr >= zoneReachSqr then continue end
		if botPos:DistToSqr(candidate.pos) <= reachDistanceSqr then continue end

		local centerDist = math.sqrt(candidate.centerDistSqr)
		local score = math.abs(centerDist - ZONE_CENTER_GOAL_RADIUS * 0.45) + math.Rand(0, 250)
		if score < bestScore then
			bestScore = score
			bestArea = area
		end
	end

	data = bot.ZCBotAI and bot.ZCBotAI.modes
	if not data then return IsValid(bestArea) and bestArea:GetCenter() or center end

	local goalPos = IsValid(bestArea) and bestArea:GetCenter() or center
	data.centerGoalPos = goalPos
	data.centerGoalFallback = not IsValid(bestArea)
	data.centerGoalRoundStart = ctx.roundStart
	data.centerGoalX = center.x
	data.centerGoalY = center.y
	data.centerGoalZ = center.z
	data.nextCenterGoalPick = now + ZONE_CENTER_GOAL_INTERVAL + math.Rand(0, 2)

	return goalPos
end

local function PickCenterPatrolArea(bot, ctx)
	if not navmesh or not navmesh.GetAllNavAreas then return nil end

	local data = bot.ZCBotAI and bot.ZCBotAI.modes
	if (data and data.nextCenterPatrolPick or 0) > CurTime() then
		return IsValid(data and data.centerPatrolArea) and data.centerPatrolArea or nil
	end

	local areas = navmesh.GetAllNavAreas()
	if not areas or #areas == 0 then return nil end

	local center = ctx.center
	local botPos = bot:GetPos()
	local bestArea
	local bestScore = -math.huge
	local tries = math.min(#areas, 48)
	local patrolRadiusSqr = ZONE_CENTER_PATROL_RADIUS * ZONE_CENTER_PATROL_RADIUS
	local sampledIndices = {}

	for sample = 1, tries do
		local remaining = #areas - sample + 1
		local pickedSlot = math.random(1, remaining)
		local areaIndex = sampledIndices[pickedSlot] or pickedSlot
		sampledIndices[pickedSlot] = sampledIndices[remaining] or remaining
		local area = areas[areaIndex]
		if not IsValid(area) then continue end

		local pos = area:GetCenter()
		local centerDistSqr = pos:DistToSqr(center)
		if centerDistSqr > patrolRadiusSqr then continue end
		if botPos:DistToSqr(pos) < 180 * 180 then continue end
		if not IsPosInsideZone(ctx, pos, ZONE_ROAM_MARGIN) then continue end

		local score = math.sqrt(centerDistSqr) + math.Rand(0, 350)
		if score > bestScore then
			bestScore = score
			bestArea = area
		end
	end

	if data then
		data.centerPatrolArea = bestArea
		data.nextCenterPatrolPick = CurTime() + ZONE_CENTER_PATROL_INTERVAL + math.Rand(0, 1.5)
	end

	return bestArea
end

local function ShouldMoveTowardZoneCenter(bot, ctx)
	local center = ctx.center
	if not center or not ctx.seekCenter then return false end

	local data = zc.PlayerBots and zc.PlayerBots.GetOrCreateState and zc.PlayerBots.GetOrCreateState(bot).modes
	local distSqr = bot:GetPos():DistToSqr(center)
	if distSqr <= ZONE_CENTER_SETTLE_RADIUS * ZONE_CENTER_SETTLE_RADIUS then
		data.settledNearCenter = true
	elseif distSqr >= ZONE_CENTER_RESUME_RADIUS * ZONE_CENTER_RESUME_RADIUS then
		data.settledNearCenter = false
	end

	return not data.settledNearCenter
end

function MODE:GetBotGoal(bot)
	local ctx = GetZoneContext(self)
	if not ctx.active or not ctx.center or not ctx.seekCenter then return nil end

	if not ShouldMoveTowardZoneCenter(bot, ctx) then
		-- Settled near the shrinking center: patrol around it instead of roaming far.
		local area = PickCenterPatrolArea(bot, ctx)
		if not IsValid(area) then return nil end
		return area:GetCenter()
	end

	return PickCenterGoal(bot, ctx) or Vector(ctx.center.x, ctx.center.y, ctx.center.z)
end

function MODE:AdjustBotGoal(bot, pos)
	local ctx = GetZoneContext(self)
	if not ctx.active or not ctx.center then return pos end

	local safeRadius = math.max((ctx.radius or 0) - ZONE_ROAM_MARGIN, 0)
	local botDistSqr = bot:GetPos():DistToSqr(ctx.center)
	if safeRadius <= 0 or botDistSqr >= safeRadius * safeRadius then
		return Vector(ctx.center.x, ctx.center.y, ctx.center.z)
	end

	local goalOffset = pos - ctx.center
	if goalOffset:LengthSqr() >= safeRadius * safeRadius then
		goalOffset:Normalize()
		return ctx.center + goalOffset * math.max(safeRadius - ZONE_CENTER_BIAS_STEP, 0)
	end

	-- Pull goals back toward the center while it is closing.
	if not ctx.seekCenter then return pos end
	if botDistSqr <= ZONE_CENTER_REACH * ZONE_CENTER_REACH then return pos end

	local improvedDist = math.max(math.sqrt(botDistSqr) - ZONE_CENTER_BIAS_STEP, 0)
	if pos:DistToSqr(ctx.center) < improvedDist * improvedDist then return pos end

	return PickCenterGoal(bot, ctx) or Vector(ctx.center.x, ctx.center.y, ctx.center.z)
end

function MODE:AdjustBotStrafe(bot, cmd, aimAng)
	local ctx = GetZoneContext(self)
	local center = ctx.center
	if not center or not ctx.seekCenter then return end
	if not ShouldMoveTowardZoneCenter(bot, ctx) then return end

	local botPos = bot:GetPos()
	local currentDistSqr = botPos:DistToSqr(center)
	if currentDistSqr <= ZONE_CENTER_REACH * ZONE_CENTER_REACH then return end

	local forwardMove = cmd:GetForwardMove()
	local sideMove = cmd:GetSideMove()
	if math.abs(forwardMove) < 40 and math.abs(sideMove) < 40 then return end

	local moveAng = Angle(0, aimAng.y, 0)
	local moveDir = moveAng:Forward() * forwardMove + moveAng:Right() * sideMove
	moveDir.z = 0
	if moveDir:LengthSqr() <= 1 then return end

	moveDir:Normalize()
	if (botPos + moveDir * ZONE_CENTER_BIAS_STEP):DistToSqr(center) < currentDistSqr then return end

	local speed = math.max(math.abs(forwardMove), math.abs(sideMove), 300)
	local goalPos = PickCenterGoal(bot, ctx) or center

	local toGoal = goalPos - botPos
	toGoal.z = 0
	if toGoal:LengthSqr() <= 1 then return end

	toGoal:Normalize()
	cmd:SetForwardMove(toGoal:Dot(moveAng:Forward()) * speed)
	cmd:SetSideMove(toGoal:Dot(moveAng:Right()) * speed)
end
