zc = zc or {}
zc.PlayerBots = zc.PlayerBots or {}
local _ENV = zc.PlayerBots
setmetatable(_ENV, {__index = _G})
setfenv(1, _ENV)

local CurTime, IsValid = CurTime, IsValid
local math_max, math_huge = math_max, math_huge
local ipairs, pairs, next, isvector = ipairs, pairs, next, isvector
local concommand, player, util = concommand, player, util
local setmetatable = setmetatable

-- Intents are implementation details of this file, not a public namespace.
local INTENT_IDLE = 0
local INTENT_FAKE = 1
local INTENT_HEAL = 2
local INTENT_FLEE = 3
local INTENT_ATTACK = 4
local INTENT_SEARCH = 5
local INTENT_PICKUP = 6
local INTENT_OBJECTIVE = 7
local INTENT_ROAM = 8

local INTENT_NAMES = {
	[INTENT_IDLE] = "idle",
	[INTENT_FAKE] = "fake",
	[INTENT_HEAL] = "heal",
	[INTENT_FLEE] = "flee",
	[INTENT_ATTACK] = "attack",
	[INTENT_SEARCH] = "search",
	[INTENT_PICKUP] = "pickup",
	[INTENT_OBJECTIVE] = "objective",
	[INTENT_ROAM] = "roam",
}

local BOT_SAFE_ENEMY_AVOID_RANGE = 1800
local BOT_SAFE_ENEMY_AVOID_DEST = 1200
local BOT_THREAT_ESCAPE_RANGE = 650
local BOT_UNARMED_FLEE_RANGE = 1400
local BOT_SUPPRESSION_AWARENESS_DISTANCE = 160
local BOT_SUPPRESSION_RECHECK_INTERVAL = 0.075

local suppressionTraceData = {
	mask = MASK_SHOT,
	filter = {},
}

-- Intent selection -----------------------------------------------------------
--
-- Fixed priority order (documented in docs/playerbot-ai-overhaul.md):
--   1. Dead, disabled, or waiting for the round
--   2. Fake-ragdoll handling
--   3. Immediate danger or safe-time separation
--   4. Urgent self-care when no visible threat is present
--   5. Attack a visible enemy
--   6. Search the last known position of a recently lost enemy
--   7. Find a weapon when inadequately armed
--   8. Follow the mode objective
--   9. Roam

local function IsTargetVisibleNow(bot, state, mode, now)
	local target = state.target
	if not IsValid(target) then return false end

	local perception = state.perception
	if perception.storedTarget == target and (perception.storedUntil or 0) > now then
		if perception.storedNoFOV then return true end
		return perception.storedVisible == true
	end

	return CanCurrentlyTarget(bot, target, mode)
end

local function GetCachedSafeTimeEnemy(bot, mode, now)
	local combat = GetOrCreateState(bot).combat
	local maxRangeSqr = BOT_SAFE_ENEMY_AVOID_RANGE * BOT_SAFE_ENEMY_AVOID_RANGE

	if (combat.safeEnemyScanAt or 0) > now then
		local enemy = combat.safeEnemy
		if IsValid(enemy) and IsUsableTarget(bot, enemy, mode)
			and bot:GetPos():DistToSqr(enemy:GetPos()) <= maxRangeSqr then
			return enemy
		end
		return nil
	end

	local enemy = GetNearestEnemy(bot, BOT_SAFE_ENEMY_AVOID_RANGE)
	combat.safeEnemy = enemy
	combat.safeEnemyScanAt = now + BOT_THINK_INTERVAL + (bot:EntIndex() % 5) * BOT_THINK_INTERVAL * 0.05
	return IsValid(enemy) and enemy or nil
end

local function SelectIntent(bot, state, mode, now, wounded)
	-- 1. Waiting for an active round.
	if not IsRoundActive() then
		return INTENT_IDLE, "waiting for round"
	end

	-- 2. Fake-ragdoll handling owns the body while it lasts.
	if zc.GetFakeState and zc.FAKE_STATE and zc.GetFakeState(bot) ~= zc.FAKE_STATE.NONE then
		return INTENT_FAKE, "fake ragdoll"
	end

	-- 3. Immediate danger: safe-time separation and recent threats.
	local safeTime = IsSafeTime(mode)
	local safeEnemy = safeTime and GetCachedSafeTimeEnemy(bot, mode, now)
	if IsValid(safeEnemy) then
		return INTENT_FLEE, "safe time", safeEnemy
	end

	local threat = state.threat
	if IsValid(threat) and (state.threatUntil or 0) > now and IsUsableTarget(bot, threat, mode) then
		state.target = IsValid(state.target) and state.target or threat
		if state.target == threat and not isvector(state.lastSeenPos) then
			state.lastSeenPos = isvector(state.threatPos) and Vector(state.threatPos.x, state.threatPos.y, state.threatPos.z) or nil
			state.lastSeenAt = now
		end

		local wep = SelectBotWeapon(bot)
		if IsRangedWeapon(wep) and HasAmmoForWeapon(bot, wep) then
			return INTENT_ATTACK, "under fire", threat
		end

		local dist = isvector(state.threatPos) and bot:GetPos():Distance(state.threatPos) or math_huge
		if dist > BOT_THREAT_ESCAPE_RANGE then
			return INTENT_FLEE, "threat", threat, state.threatPos
		end
	end

	-- An unarmed bot flees a visibly armed enemy instead of brawling.
	local target = state.target
	if IsValid(target) and IsTargetVisibleNow(bot, state, mode, now) then
		local wep = SelectBotWeapon(bot)
		if IsUnarmedWeapon(wep) then
			local theirWep = target.GetActiveWeapon and target:GetActiveWeapon()
			if IsMeaningfullyArmedWeapon(theirWep) then
				return INTENT_FLEE, "unarmed", target
			end
		end
	end

	-- 4. Urgent self-care while no visible enemy or recent threat has priority.
	-- Suppression interrupts exposed healing even without a visible shooter.
	if wounded and not HasVisibleEnemy(bot) and (state.threatUntil or 0) <= now then
		return INTENT_HEAL, "wounded"
	end

	-- 5. Attack a visible enemy.
	if IsValid(target) and IsUsableTarget(bot, target, mode) and IsTargetVisibleNow(bot, state, mode, now) then
		return INTENT_ATTACK, target:Name(), target
	end

	-- 6. Search the last known position of a recently lost enemy.
	if IsValid(target) and IsUsableTarget(bot, target, mode) then
		if IsTargetMemoryFresh(state, now) then
			return INTENT_SEARCH, "lost sight", target, state.lastSeenPos
		end

		ClearTargetMemory(state)
	else
		ClearTargetMemory(state)
	end

	-- 7. Find a weapon when inadequately armed.
	local pickup = ShouldSeekPickup(bot) and FindNearbyPickupWeapon(bot)
	if IsValid(pickup) then
		return INTENT_PICKUP, "needs weapon", pickup
	end

	-- 8. Follow the mode objective.
	local goal = GetBotGoal(bot)
	if isvector(goal) then
		return INTENT_OBJECTIVE, "objective", nil, goal
	end

	-- 9. Roam.
	return INTENT_ROAM, "nothing better to do"
end

-- Slow decision update: refresh perception, pick one intent.
function UpdateDecision(bot, state, mode, now)
	local perception = state.perception
	local wounded, needsTourniquet, needsBandage = NeedsSelfCare(bot)

	if wounded and (perception.hasVisibleEnemy == nil or (perception.visibleEnemyUntil or 0) <= now) then
		-- Keep the visible-enemy answer fresh while healing decisions are pending.
		perception.nextFullScan = 0
	end

	UpdateTarget(bot, state, mode, false, now)

	local intent, reason, intentTarget, intentPos = SelectIntent(bot, state, mode, now, wounded)

	state.woundTourniquet = needsTourniquet
	state.woundBandage = needsBandage

	if intent ~= state.intent then
		LogBotIntentChange(bot, INTENT_NAMES[state.intent], INTENT_NAMES[intent], reason)
		state.intent = intent
		state.intentStarted = now
		state.intentPos = nil
		-- A new intent owns a new destination: drop failed-route memory.
		ClearDestinationMemory(state)
	end
	state.intentReason = reason
	state.intentTarget = intentTarget
	state.intentPos = intentPos
end

-- Per-command execution ------------------------------------------------------

local function ExecuteFlee(bot, cmd, mode, now)
	local state = GetOrCreateState(bot)

	local enemy
	if state.intentReason == "safe time" then
		enemy = IsValid(state.intentTarget) and state.intentTarget or GetCachedSafeTimeEnemy(bot, mode, now)
		if not IsValid(enemy) then
			HoldAndScan(bot, cmd)
			return
		end

		local away = bot:GetPos() - enemy:GetPos()
		away.z = 0
		if away:LengthSqr() <= 1 then
			away = bot:EyeAngles():Forward() * -1
		end

		away:Normalize()
		local destPos = bot:GetPos() + away * BOT_SAFE_ENEMY_AVOID_DEST
		destPos = AdjustBotGoal(bot, destPos)
		MoveTo(bot, cmd, destPos, {speed = 420, allowSprint = true})
		return
	end

	enemy = IsValid(state.intentTarget) and state.intentTarget
		or IsValid(state.threat) and (state.threatUntil or 0) > now and state.threat
		or state.target
	if not IsValid(enemy) then
		HoldAndScan(bot, cmd)
		return
	end

	FleeFromEnemy(bot, cmd, enemy, BOT_UNARMED_FLEE_RANGE)
end

local function ExecuteSearch(bot, cmd, now)
	local state = GetOrCreateState(bot)

	if not IsTargetMemoryFresh(state, now) then
		ClearTargetMemory(state)
		HoldAndScan(bot, cmd)
		return
	end

	local pos = state.intentPos
	if not isvector(pos) then
		HoldAndScan(bot, cmd)
		return
	end

	if bot:GetPos():DistToSqr(pos) <= BOT_NAV_DEST_REACH * BOT_NAV_DEST_REACH then
		-- At the last known position: scan briefly, then the memory expires normally.
		HoldAndScan(bot, cmd)
		return
	end

	MoveTo(bot, cmd, pos, {speed = 420, allowSprint = true})
	FaceRecentThreat(bot, cmd)
end

function ExecuteIntent(bot, state, mode, cmd, now)
	local intent = state.intent
	local safeTime = IsSafeTime(mode)

	if intent == INTENT_FAKE then
		if not ExecuteFakeControl(bot, cmd, {mode = mode, safeTime = safeTime, now = now}) then
			-- Getting up keeps recent threat memory but forces a fresh target
			-- and movement decision.
			ClearTargetMemory(state)
			state.perception.nextFullScan = 0
			ClearDestinationMemory(state)
			HoldAndScan(bot, cmd)
		end
		return
	end

	if intent == INTENT_ATTACK then
		if not AttackCurrentTarget(bot, cmd, {mode = mode, safeTime = safeTime}) and not FaceRecentThreat(bot, cmd) then
			HoldAndScan(bot, cmd)
		end
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	if intent == INTENT_FLEE then
		ExecuteFlee(bot, cmd, mode, now)
		if safeTime then ClearCombatButtons(cmd) end
		return
	end

	if intent == INTENT_HEAL then
		local needsCare, needsTourniquet, needsBandage = NeedsSelfCare(bot)
		if not needsCare then return end

		-- Severe arterial wounds justify reaching a protected spot before
		-- standing still to heal.
		if needsTourniquet and isvector(state.lastSeenPos) then
			local cover = FindProtectedPosition(bot, state.lastSeenPos)
			if cover and bot:GetPos():DistToSqr(cover) > (BOT_NAV_DEST_REACH * 0.5) * (BOT_NAV_DEST_REACH * 0.5) then
				state.intentPos = cover
				MoveTo(bot, cmd, cover, {speed = 340})
				return
			end
		end

		if not ApplySelfCare(bot, cmd, needsTourniquet, needsBandage) then
			HoldAndScan(bot, cmd)
		end
		return
	end

	if intent == INTENT_SEARCH then
		ExecuteSearch(bot, cmd, now)
		return
	end

	if intent == INTENT_PICKUP then
		if not ExecuteWeaponPickup(bot, cmd) then
			HoldAndScan(bot, cmd)
		end
		return
	end

	if intent == INTENT_OBJECTIVE then
		local goal = state.intentPos
		if not goal then
			HoldAndScan(bot, cmd)
			return
		end

		MoveTo(bot, cmd, goal, {speed = 420, allowSprint = true})
		return
	end

	if intent == INTENT_ROAM then
		Roam(bot, cmd, AdjustBotGoal)
		FaceRecentThreat(bot, cmd)
		return
	end

	-- INTENT_IDLE: waiting for the round; produce no movement or buttons.
end

-- Command ownership ----------------------------------------------------------
--
-- Only this function clears and writes bot movement and buttons.

function ShouldThink(bot, state, now)
	if not state.nextThink or state.nextThink <= 0 then
		-- Stagger decision updates across bots using the entity index.
		local steps = math_max(BOT_TARGET_SCAN_STAGGER_STEPS or 1, 1)
		state.nextThink = now + (bot:EntIndex() % steps) * BOT_THINK_INTERVAL / steps
	end

	if now < state.nextThink then return false end

	state.nextThink = now + BOT_THINK_INTERVAL
	return true
end

-- Public API: single owner of bot command output.
function RunCommand(bot, cmd)
	if not bot:IsBot() then return end

	cmd:ClearMovement()
	cmd:ClearButtons()

	if not zc_playerbot_ai:GetBool() then
		-- Disabling the AI must also stop stale fake-ragdoll input immediately.
		ClearFakeControlOutput(bot)
		return
	end

	Register(bot)

	if not bot:Alive() then
		cmd:SetButtons(bit_bor(cmd:GetButtons(), IN_ATTACK))
		return
	end

	-- An unconscious bot must not produce normal movement or firing input.
	local organism = bot.organism
	if organism and organism.unconscious then
		return
	end

	local state = GetOrCreateState(bot)
	local mode = GetCurrentMode()
	local now = CurTime()

	BeginBotCommandContext(bot, state, mode, now)

	if ShouldThink(bot, state, now) then
		UpdateDecision(bot, state, mode, now)
	end

	ExecuteIntent(bot, state, mode, cmd, now)
end

hook.Add("StartCommand", "ZC_PlayerBotEnemyAI", function(bot, cmd)
	RunCommand(bot, cmd)
end)

-- Entry points ---------------------------------------------------------------

hook.Remove("PlayerSpawn", "ZCPlayerBotWeaponCacheSpawn")
hook.Remove("ZC_StartRound", "ZC_PlayerBotResetRoundState")

hook.Add("PlayerInitialSpawn", "ZC_PlayerBotRegister", function(ply)
	if ply:IsBot() then Register(ply) end
end)

hook.Add("PlayerSpawn", "ZC_PlayerBotResetState", function(ply)
	if ply:IsBot() then Reset(ply) end
end)

hook.Add("PlayerDisconnected", "ZC_PlayerBotUnregister", function(ply)
	Unregister(ply)
end)

hook.Add("ZC_PreRoundStart", "ZC_PlayerBotRoundReset", function()
	for _, ply in ipairs(player.GetAll()) do
		if ply:IsBot() then Reset(ply) end
	end
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

	RememberThreat(ent, attacker, threatPos)
end)

hook.Add("ZC_PostEntityFireBullets", "ZC_PlayerBotNoticeSuppression", function(ent, bullet)
	if not zc_playerbot_ai:GetBool() or not bullet or not bullet.Trace then return end
	if not next(PlayerBotRegistry) then return end

	local tr = bullet.Trace
	if not isvector(tr.StartPos) or not isvector(tr.HitPos) then return end

	local attacker = bullet.Attacker
	if not IsValid(attacker) and IsValid(ent) then
		attacker = ent.GetOwner and ent:GetOwner() or ent
	end
	if not IsValid(attacker) then return end

	local now = CurTime()
	for bot in pairs(PlayerBotRegistry) do
		if not IsValid(bot) then
			PlayerBotRegistry[bot] = nil
			continue
		end
		if not bot:Alive() or bot == attacker then continue end

		local state = bot.ZCBotAI
		local checks = state and state.combat.suppressionChecks
		if checks and (checks[attacker] or 0) > now then continue end

		local dist, nearestPos = util.DistanceToLine(tr.StartPos, tr.HitPos, bot:EyePos())
		if dist > BOT_SUPPRESSION_AWARENESS_DISTANCE then continue end

		if not state then state = GetOrCreateState(bot) end
		if not state.combat.suppressionChecks then
			state.combat.suppressionChecks = setmetatable({}, {__mode = "k"})
		end

		suppressionTraceData.start = nearestPos
		suppressionTraceData.endpos = bot:EyePos()
		suppressionTraceData.filter[1] = bot
		suppressionTraceData.filter[2] = GetBotFakeRagdollEntity(bot)
		suppressionTraceData.filter[3] = attacker
		if util.TraceLine(suppressionTraceData).Hit then continue end
		state.combat.suppressionChecks[attacker] = now + BOT_SUPPRESSION_RECHECK_INTERVAL

		RememberThreat(bot, attacker, tr.StartPos)
	end
end)

hook.Add("ZC_OnFakeRagdollCreated", "ZC_PlayerBotFakeUpInitialDelay", function(ply)
	if not zc_playerbot_ai:GetBool() or not IsValid(ply) or not ply:IsPlayer() or not ply:IsBot() then return end

	local state = GetOrCreateState(ply)
	local allowedAt = CurTime() + BOT_FAKEUP_INITIAL_DELAY
	state.combat.fakeUpAllowedAt = allowedAt
	state.combat.nextFakeUpTry = allowedAt
end)

-- Inventory cache maintenance owned by the weapons module.
hook.Add("WeaponEquip", "ZCPlayerBotWeaponCacheEquip", OnWeaponInventoryChanged)
hook.Add("PlayerDroppedWeapon", "ZCPlayerBotWeaponCacheDrop", OnWeaponDropped)
hook.Add("OnReloaded", "ZC_PlayerBotWeaponClassCacheReload", OnWeaponClassesReloaded)

-- Debugging ------------------------------------------------------------------

concommand.Add("zc_playerbot_dump", function(admin)
	if IsValid(admin) and not admin:IsAdmin() then return end

	for bot in pairs(PlayerBotRegistry) do
		if not IsValid(bot) then
			PlayerBotRegistry[bot] = nil
			continue
		end

		local state = bot.ZCBotAI
		if not state then continue end

		local nav = state.navigation
		local combat = state.combat
		local perception = state.perception
		local now = CurTime()
		local targetValid = IsValid(state.target)
		local visible = perception.storedVisible == true and (perception.storedUntil or 0) > now
		local lockLeft = math_max((combat.targetLockUntil or 0) - now, 0)
		print(string.format(
			"[Bot %s] intent=%s (%s) target=%s lock=%.1fs vis=%s seenAge=%.1fs move=%s dest=%s %s stuckStage=%s goal=%s hostile=%s weapon=%s reloading=%s next=%.2f",
			bot:Name(),
			INTENT_NAMES[state.intent] or "?",
			state.intentReason or "-",
			targetValid and state.target:Name() or "none",
			lockLeft,
			tostring(visible),
			state.lastSeenAt > 0 and now - state.lastSeenAt or -1,
			combat.moveKind or "-",
			isvector(state.intentPos) and tostring(state.intentPos) or "none",
			nav.path and ("path x" .. #nav.path) or "no path",
			tostring(nav.stuckStage or 0),
			tostring(GetBotGoal(bot) ~= nil),
			tostring(CanBotTarget(bot, targetValid and state.target or NULL)),
			tostring(SelectBotWeapon(bot)),
			tostring(IsValid(combat.reloadWeapon)),
			math_max(state.nextThink - now, 0)
		))
	end
end, nil, "Print player bot AI state summaries.")
